-- Semilla 009 · datos de prueba para el motor de avisos y los reportes (rol 4)
-- Completa los casos que pide el plan para 11_motor.sh y 12_reportes.sh:
--   1. Vacuna próxima (en 3 días): evento 951 sobre Simba (mascota 904, cliente 103).
--   2. Vacuna vencida: ya están los eventos 101 y 106 (semilla 005).
--   3. Productos por vencer con stock: el 107 ya vence en 20 días (15% dto, semilla 002);
--      acá le ponemos vencimiento en 7 días al 101 (Alimento cachorro 3 kg, 30% dto).
--   4. Turnos de las últimas 4 semanas (ids 951 a 962) para el reporte "Franjas con pocos turnos".

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);

-- 1. Vacuna próxima: le toca en 3 días a Simba (904, del cliente 103).
INSERT INTO evento_sanitario
  (id, mascota_id, plan_sanitario_id, tipo, nombre, fecha_programada, fecha_aplicada, consulta_id)
VALUES
  (951, 904, 10, 'VACUNA', 'Antirrábica', @hoy + INTERVAL 3 DAY, NULL, NULL)
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id),
  plan_sanitario_id = VALUES(plan_sanitario_id),
  tipo = VALUES(tipo),
  nombre = VALUES(nombre),
  fecha_programada = VALUES(fecha_programada),
  fecha_aplicada = VALUES(fecha_aplicada),
  consulta_id = VALUES(consulta_id);

-- 2. Producto por vencer en menos de 10 días (30% de descuento sugerido).
-- El 107 (semilla 002) vence en 20 días (15% de descuento sugerido).
UPDATE producto
SET fecha_vencimiento = @hoy + INTERVAL 7 DAY
WHERE id = 101;

-- 3. Turnos de las últimas 4 semanas para "Franjas con pocos turnos".
-- Calculamos el lunes de la semana actual (WEEKDAY: 0 = lunes .. 6 = domingo) y retrocedemos
-- semanas completas para caer siempre en días fijos (lunes, martes, miércoles) sin importar
-- qué día de la semana se corra el sembrador.
SET @lunes_actual = @hoy - INTERVAL WEEKDAY(@hoy) DAY;
SET @lunes_sem1   = @lunes_actual - INTERVAL 1 WEEK;
SET @lunes_sem2   = @lunes_actual - INTERVAL 2 WEEK;
SET @lunes_sem3   = @lunes_actual - INTERVAL 3 WEEK;

-- Primero se marcan CANCELADO para liberar el índice único (veterinario_id, fecha, hora, ocupa_horario)
-- si las semillas se habían corrido otro día con otras fechas.
UPDATE turno
SET estado = 'CANCELADO'
WHERE id BETWEEN 951 AND 962;

INSERT INTO turno
  (id, mascota_id, veterinario_id, fecha, hora, motivo, estado)
VALUES
  -- Lunes a la mañana: solo 2 turnos en las últimas 4 semanas (la franja con menor ocupación).
  (951, 101, 101, @lunes_sem1,                   '07:00', 'CONSULTA',   'ATENDIDO'),
  (952, 102, 101, @lunes_sem2,                   '07:00', 'VACUNACION', 'ATENDIDO'),

  -- Lunes a la tarde: 4 turnos.
  (953, 101, 101, @lunes_sem1,                   '19:00', 'CONSULTA',   'ATENDIDO'),
  (954, 102, 101, @lunes_sem1,                   '19:30', 'CONSULTA',   'ATENDIDO'),
  (955, 103, 101, @lunes_sem2,                   '19:00', 'VACUNACION', 'ATENDIDO'),
  (956, 104, 101, @lunes_sem3,                   '19:00', 'CONSULTA',   'ATENDIDO'),

  -- Martes a la mañana: 3 turnos.
  (957, 101, 101, @lunes_sem1 + INTERVAL 1 DAY,  '07:00', 'CONSULTA',   'ATENDIDO'),
  (958, 102, 101, @lunes_sem2 + INTERVAL 1 DAY,  '07:00', 'CONSULTA',   'ATENDIDO'),
  (959, 103, 101, @lunes_sem3 + INTERVAL 1 DAY,  '07:00', 'VACUNACION', 'ATENDIDO'),

  -- Martes a la tarde: 3 turnos.
  (960, 101, 101, @lunes_sem1 + INTERVAL 1 DAY,  '19:00', 'CONSULTA',   'ATENDIDO'),
  (961, 102, 101, @lunes_sem2 + INTERVAL 1 DAY,  '19:00', 'CONSULTA',   'ATENDIDO'),
  (962, 104, 101, @lunes_sem3 + INTERVAL 1 DAY,  '19:00', 'CONSULTA',   'ATENDIDO')
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id),
  veterinario_id = VALUES(veterinario_id),
  fecha = VALUES(fecha),
  hora = VALUES(hora),
  motivo = VALUES(motivo),
  estado = VALUES(estado);

-- Cada turno ATENDIDO tiene su consulta finalizada y su factura, como cuando la veterinaria finaliza una
-- consulta (24/11: sin esto, "Ver en el historial" de Mis turnos llevaba a un historial vacío).
-- Consulta y factura con el mismo id que el turno (C-000951...).
INSERT INTO consulta (id, turno_id, diagnostico, observaciones, valor_base, estado, finalizada_en)
SELECT t.id, t.id,
       IF(t.motivo = 'VACUNACION', 'Vacunación de rutina: sin novedades.', 'Control general: sano.'),
       NULL, 15000.00, 'FINALIZADA', TIMESTAMP(t.fecha, t.hora) + INTERVAL 25 MINUTE
FROM turno t
WHERE t.id BETWEEN 951 AND 962
ON DUPLICATE KEY UPDATE
  turno_id = VALUES(turno_id), diagnostico = VALUES(diagnostico), observaciones = VALUES(observaciones),
  valor_base = VALUES(valor_base), estado = VALUES(estado), finalizada_en = VALUES(finalizada_en);

INSERT INTO factura_consulta
  (id, numero, consulta_id, subtotal_base, subtotal_insumos, subtotal_productos, total,
   huellitas_usadas, estado, fecha)
SELECT c.id, CONCAT('C-', LPAD(c.id, 6, '0')), c.id, 15000.00, 0.00, 0.00, 15000.00, NULL, 'PAGADA', c.finalizada_en
FROM consulta c
WHERE c.id BETWEEN 951 AND 962
ON DUPLICATE KEY UPDATE
  numero = VALUES(numero), consulta_id = VALUES(consulta_id), subtotal_base = VALUES(subtotal_base),
  subtotal_insumos = VALUES(subtotal_insumos), subtotal_productos = VALUES(subtotal_productos),
  total = VALUES(total), huellitas_usadas = VALUES(huellitas_usadas), estado = VALUES(estado),
  fecha = VALUES(fecha);
