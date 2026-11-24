-- Volumen 003 · turnos de 6 meses, con sus consultas y facturas, y vacunas por vencer
--
--   Turnos 20001 a 20760: cuatro por día, desde hace 180 días hasta dentro de 9, con el Veterinario
--   Dos (2001), entre las 9:00 y las 18:30. Los pasados quedan ATENDIDO (con consulta finalizada y
--   factura), CANCELADO (1 de cada 10) o AUSENTE (1 de cada 10); los de hoy, los primeros atendidos y
--   el resto PROGRAMADO; los que vienen, PROGRAMADO. Mascotas del volumen 001 (también las dos del
--   cliente de prueba 102).
--   Consulta y factura: el mismo id que su turno. Factura C-0200xx; pagada si tiene más de una
--   semana. Una de cada tres usa un insumo (101) y una de cada cuatro vende un producto (105).
--   Vacunas 20001 a 20030: antirrábica pendiente para los próximos 0 a 9 días (el aviso del motor
--   avisa las de los próximos 7).
--   Los lunes a la tarde quedan CANCELADO: es la franja sin turnos, que el motor sugiere promocionar.
-- Correr de nuevo deja todo como estaba, con las fechas corridas a hoy.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);

-- 1. Lo que se hizo al probar sobre los turnos del volumen: consultas con otro id (por ejemplo,
--    atender un turno PROGRAMADO), con sus ítems y su factura. Así esos turnos se pueden atender
--    de nuevo. En orden, por las claves foráneas.
DELETE f FROM factura_consulta f JOIN consulta c ON c.id = f.consulta_id
  WHERE c.turno_id BETWEEN 20001 AND 20760 AND c.id NOT BETWEEN 20001 AND 20760;
DELETE i FROM item_insumo_consulta i JOIN consulta c ON c.id = i.consulta_id
  WHERE c.turno_id BETWEEN 20001 AND 20760 AND c.id NOT BETWEEN 20001 AND 20760;
DELETE i FROM item_producto_consulta i JOIN consulta c ON c.id = i.consulta_id
  WHERE c.turno_id BETWEEN 20001 AND 20760 AND c.id NOT BETWEEN 20001 AND 20760;
UPDATE evento_sanitario e JOIN consulta c ON c.id = e.consulta_id
  SET e.consulta_id = NULL, e.fecha_aplicada = NULL
  WHERE c.turno_id BETWEEN 20001 AND 20760 AND c.id NOT BETWEEN 20001 AND 20760;
DELETE FROM consulta WHERE turno_id BETWEEN 20001 AND 20760 AND id NOT BETWEEN 20001 AND 20760;

-- 2. Los turnos. Primero se marcan cancelados (no ocupan horario): si no, al correr las fechas
--    chocarían con los de la carga anterior.
UPDATE turno SET estado = 'CANCELADO' WHERE id BETWEEN 20001 AND 20760;

INSERT INTO turno (id, mascota_id, veterinario_id, fecha, hora, motivo, estado)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 760),
d AS (
  SELECT i,
         (i - 1) DIV 4 - 180 AS dia,
         ((i - 1) % 4) * 5 + (((i - 1) DIV 4) % 5) AS lugar
  FROM n
)
SELECT 20000 + i,
       20001 + ((i * 13) % 82),
       2001,
       @hoy + INTERVAL dia DAY,
       SEC_TO_TIME(9 * 3600 + lugar * 1800),
       IF(i % 5 = 0, 'VACUNACION', 'CONSULTA'),
       CASE
         -- Los lunes a la tarde (desde las 13:00) quedan sin turnos: así el motor sugiere esa franja
         -- para promocionarla y se puede probar un turno con descuento un lunes a la tarde o a la noche.
         WHEN DAYOFWEEK(@hoy + INTERVAL dia DAY) = 2 AND lugar >= 8 THEN 'CANCELADO'
         WHEN i % 10 = 0 THEN 'CANCELADO'
         WHEN dia > 0 THEN 'PROGRAMADO'
         WHEN dia = 0 THEN IF(lugar < 6, 'ATENDIDO', 'PROGRAMADO')
         WHEN i % 10 = 3 THEN 'AUSENTE'
         ELSE 'ATENDIDO'
       END
FROM d
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id), veterinario_id = VALUES(veterinario_id), fecha = VALUES(fecha),
  hora = VALUES(hora), motivo = VALUES(motivo), estado = VALUES(estado);

-- 3. Las consultas finalizadas de los atendidos (y se borran las de la carga anterior cuyo turno
--    ya no está atendido, por si cambió algo).
DELETE f FROM factura_consulta f JOIN consulta c ON c.id = f.consulta_id JOIN turno t ON t.id = c.turno_id
  WHERE c.id BETWEEN 20001 AND 20760 AND t.estado <> 'ATENDIDO';
DELETE i FROM item_insumo_consulta i JOIN consulta c ON c.id = i.consulta_id JOIN turno t ON t.id = c.turno_id
  WHERE c.id BETWEEN 20001 AND 20760 AND t.estado <> 'ATENDIDO';
DELETE i FROM item_producto_consulta i JOIN consulta c ON c.id = i.consulta_id JOIN turno t ON t.id = c.turno_id
  WHERE c.id BETWEEN 20001 AND 20760 AND t.estado <> 'ATENDIDO';
DELETE c FROM consulta c JOIN turno t ON t.id = c.turno_id
  WHERE c.id BETWEEN 20001 AND 20760 AND t.estado <> 'ATENDIDO';

INSERT INTO consulta (id, turno_id, diagnostico, observaciones, valor_base, estado, finalizada_en)
SELECT t.id, t.id,
       ELT(1 + (t.id % 8), 'Control general: sano.', 'Otitis externa leve.', 'Gastroenteritis leve.',
           'Dermatitis alérgica.', 'Control de peso: sobrepeso leve.', 'Vacunación al día.',
           'Conjuntivitis.', 'Control posoperatorio: buena evolución.'),
       IF(t.id % 4 = 0, 'Volver a control en 15 días.', NULL),
       15000.00 + (t.id % 4) * 2500,
       'FINALIZADA',
       TIMESTAMP(t.fecha, t.hora) + INTERVAL 25 MINUTE
FROM turno t
WHERE t.id BETWEEN 20001 AND 20760 AND t.estado = 'ATENDIDO'
ON DUPLICATE KEY UPDATE
  turno_id = VALUES(turno_id), diagnostico = VALUES(diagnostico), observaciones = VALUES(observaciones),
  valor_base = VALUES(valor_base), estado = VALUES(estado), finalizada_en = VALUES(finalizada_en);

-- Ítems: insumo 101 (jeringa, $150) en una de cada tres; producto 105 (snacks, $4500) en una de cada cuatro.
DELETE FROM item_insumo_consulta WHERE consulta_id BETWEEN 20001 AND 20760;
DELETE FROM item_producto_consulta WHERE consulta_id BETWEEN 20001 AND 20760;

INSERT INTO item_insumo_consulta (consulta_id, insumo_id, cantidad, costo_unitario)
SELECT id, 101, 1 + (id % 2), 150.00 FROM consulta WHERE id BETWEEN 20001 AND 20760 AND id % 3 = 0;

INSERT INTO item_producto_consulta (consulta_id, producto_id, cantidad, precio_unitario)
SELECT id, 105, 1, 4500.00 FROM consulta WHERE id BETWEEN 20001 AND 20760 AND id % 4 = 0;

-- Facturas: mismo id que la consulta (C-020001...), con los subtotales de sus ítems.
INSERT INTO factura_consulta
  (id, numero, consulta_id, subtotal_base, subtotal_insumos, subtotal_productos, total, huellitas_usadas, estado, fecha)
SELECT c.id, CONCAT('C-', LPAD(c.id, 6, '0')), c.id, c.valor_base,
       COALESCE(ii.subtotal, 0), COALESCE(ip.subtotal, 0),
       c.valor_base + COALESCE(ii.subtotal, 0) + COALESCE(ip.subtotal, 0),
       NULL,
       IF(c.finalizada_en < @hoy - INTERVAL 7 DAY, 'PAGADA', 'PENDIENTE_PAGO'),
       c.finalizada_en
FROM consulta c
LEFT JOIN (SELECT consulta_id, SUM(cantidad * costo_unitario) AS subtotal FROM item_insumo_consulta GROUP BY consulta_id) ii
  ON ii.consulta_id = c.id
LEFT JOIN (SELECT consulta_id, SUM(cantidad * precio_unitario) AS subtotal FROM item_producto_consulta GROUP BY consulta_id) ip
  ON ip.consulta_id = c.id
WHERE c.id BETWEEN 20001 AND 20760
ON DUPLICATE KEY UPDATE
  numero = VALUES(numero), consulta_id = VALUES(consulta_id), subtotal_base = VALUES(subtotal_base),
  subtotal_insumos = VALUES(subtotal_insumos), subtotal_productos = VALUES(subtotal_productos),
  total = VALUES(total), estado = VALUES(estado), fecha = VALUES(fecha);

-- 4. Vacunas por vencer: antirrábica sin aplicar, para los próximos 0 a 9 días.
INSERT INTO evento_sanitario
  (id, mascota_id, plan_sanitario_id, tipo, nombre, fecha_programada, fecha_aplicada, consulta_id)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 30)
SELECT 20000 + i,
       IF(i = 30, 20081, 20000 + i * 2),
       NULL, 'VACUNA', 'Antirrábica',
       @hoy + INTERVAL (i % 10) DAY,
       NULL, NULL
FROM n
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id), plan_sanitario_id = VALUES(plan_sanitario_id), tipo = VALUES(tipo),
  nombre = VALUES(nombre), fecha_programada = VALUES(fecha_programada),
  fecha_aplicada = NULL, consulta_id = NULL;
