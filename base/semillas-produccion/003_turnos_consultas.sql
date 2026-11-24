-- Producción 003 · seis meses de agenda, con sus consultas, facturas y vacunas
--
--   Turnos 30001 a 30760: cuatro por día, desde hace 180 días hasta dentro de 9, con la veterinaria de
--   la demo (@vet), a las y cuarto o menos cuarto entre las 9:15 y las 18:45 (así no chocan con los que
--   se carguen a mano en la demo, que suelen ser en punto o y media). Los pasados quedan ATENDIDO, uno
--   de cada diez CANCELADO y otro AUSENTE; los de hoy, la mitad atendidos; los que vienen, PROGRAMADO.
--   Los lunes a la tarde quedan cancelados: es la franja con menos turnos, que Reportes sugiere promocionar.
--   El precio es el de la consulta de ese momento: $12.000 hasta hace 3 meses y $15.000 desde entonces.
--   Turnos 30761 a 30765: los de las mascotas de la demo (a las 19:20 o 19:50).
--   Ningún turno de este juego pisa uno que ya exista: si el horario está ocupado, el de acá queda
--   cancelado (ON DUPLICATE KEY UPDATE solo actualiza los de estos ids).
--   Consulta y factura (C-030001...): el mismo id que su turno, con diagnóstico, indicaciones y lo que
--   se usó: en las vacunaciones, la vacuna y la jeringa; en algunas consultas, un remedio de la tienda.
--   Calendario: cada vacunación atendida queda aplicada; las mascotas de la demo tienen su calendario
--   (una vacuna vencida, otras al día y la próxima); 30 antirrábicas de otras mascotas vencen esta
--   semana o la que viene (el motor avisa las de los próximos 7 días).
-- Correr de nuevo deja todo como estaba, con las fechas corridas a hoy.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);

-- 1. Lo que se hizo en la demo sobre estos turnos (por ejemplo, atender uno programado): se borra
--    para poder hacerlo de nuevo. En orden, por las claves foráneas.
DELETE f FROM factura_consulta f JOIN consulta c ON c.id = f.consulta_id
  WHERE c.turno_id BETWEEN 30001 AND 30765 AND c.id NOT BETWEEN 30001 AND 30765;
DELETE i FROM item_insumo_consulta i JOIN consulta c ON c.id = i.consulta_id
  WHERE c.turno_id BETWEEN 30001 AND 30765 AND c.id NOT BETWEEN 30001 AND 30765;
DELETE i FROM item_producto_consulta i JOIN consulta c ON c.id = i.consulta_id
  WHERE c.turno_id BETWEEN 30001 AND 30765 AND c.id NOT BETWEEN 30001 AND 30765;
UPDATE evento_sanitario e JOIN consulta c ON c.id = e.consulta_id
  SET e.consulta_id = NULL, e.fecha_aplicada = NULL
  WHERE c.turno_id BETWEEN 30001 AND 30765 AND c.id NOT BETWEEN 30001 AND 30765;
DELETE FROM consulta WHERE turno_id BETWEEN 30001 AND 30765 AND id NOT BETWEEN 30001 AND 30765;

-- 2. Los turnos (primero cancelados: si no, al correr las fechas chocarían con la carga anterior).
UPDATE turno SET estado = 'CANCELADO' WHERE id BETWEEN 30001 AND 30765;

INSERT INTO turno (id, mascota_id, veterinario_id, fecha, hora, motivo, estado, precio_consulta, descuento, promocion_franja_id)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 760),
d AS (
  SELECT i,
         (i - 1) DIV 4 - 180 AS dia,
         ((i - 1) % 4) * 5 + (((i - 1) DIV 4) % 5) AS lugar
  FROM n
)
SELECT 30000 + i,
       30001 + ((i * 13) % 80),
       @vet,
       @hoy + INTERVAL dia DAY,
       SEC_TO_TIME(9 * 3600 + 900 + lugar * 1800),
       IF(i % 5 = 0, 'VACUNACION', 'CONSULTA'),
       CASE
         -- Si en ese horario ya hay un turno que no es de este juego (uno cargado a mano), este queda
         -- cancelado: así nunca choca con él ni lo pisa.
         WHEN EXISTS (SELECT 1 FROM turno o
                      WHERE o.veterinario_id = @vet AND o.fecha = @hoy + INTERVAL dia DAY
                        AND o.hora = SEC_TO_TIME(9 * 3600 + 900 + lugar * 1800)
                        AND o.estado <> 'CANCELADO' AND o.id NOT BETWEEN 30001 AND 30765) THEN 'CANCELADO'
         WHEN DAYOFWEEK(@hoy + INTERVAL dia DAY) = 2 AND lugar >= 8 THEN 'CANCELADO'
         WHEN DAYOFWEEK(@hoy + INTERVAL dia DAY) = 1 THEN 'CANCELADO'   -- los domingos no se atiende
         WHEN i % 10 = 0 THEN 'CANCELADO'
         WHEN dia > 0 THEN 'PROGRAMADO'
         WHEN dia = 0 THEN IF(lugar < 10, 'ATENDIDO', 'PROGRAMADO')
         WHEN i % 10 = 3 THEN 'AUSENTE'
         ELSE 'ATENDIDO'
       END,
       IF(dia < -90, 12000.00, 15000.00), NULL, NULL
FROM d
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id), veterinario_id = VALUES(veterinario_id), fecha = VALUES(fecha),
  hora = VALUES(hora), motivo = VALUES(motivo), estado = VALUES(estado),
  precio_consulta = VALUES(precio_consulta), descuento = NULL, promocion_franja_id = NULL;

-- Los de las mascotas de la demo: Rocco tuvo otitis hace 20 días y vuelve a vacunarse en 3; Mishi se
-- vacunó hace 2 meses; Coco tuvo su control de senior hace 10 días; Lola tiene consulta en 5 días.
INSERT INTO turno (id, mascota_id, veterinario_id, fecha, hora, motivo, estado, precio_consulta, descuento, promocion_franja_id)
SELECT d.id, d.mascota, @vet, d.fecha, d.hora, d.motivo,
       IF(EXISTS (SELECT 1 FROM turno o
                  WHERE o.veterinario_id = @vet AND o.fecha = d.fecha AND o.hora = d.hora
                    AND o.estado <> 'CANCELADO' AND o.id NOT BETWEEN 30001 AND 30765), 'CANCELADO', d.estado),
       15000.00, NULL, NULL
FROM (
            SELECT 30761 AS id, 30081 AS mascota, @hoy - INTERVAL 20 DAY AS fecha, '19:20:00' AS hora, 'CONSULTA' AS motivo, 'ATENDIDO' AS estado
  UNION ALL SELECT 30762, 30082, @hoy - INTERVAL 61 DAY, '19:20:00', 'VACUNACION', 'ATENDIDO'
  UNION ALL SELECT 30763, 30083, @hoy - INTERVAL 10 DAY, '19:50:00', 'CONSULTA',   'ATENDIDO'
  UNION ALL SELECT 30764, 30081, @hoy + INTERVAL 3 DAY,  '19:20:00', 'VACUNACION', 'PROGRAMADO'
  UNION ALL SELECT 30765, 30084, @hoy + INTERVAL 5 DAY,  '19:50:00', 'CONSULTA',   'PROGRAMADO'
) d
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id), veterinario_id = VALUES(veterinario_id), fecha = VALUES(fecha),
  hora = VALUES(hora), motivo = VALUES(motivo), estado = VALUES(estado),
  precio_consulta = VALUES(precio_consulta), descuento = NULL, promocion_franja_id = NULL;

-- 3. Las consultas de los atendidos (y se borran las de la carga anterior cuyo turno ya no está atendido).
DELETE f FROM factura_consulta f JOIN consulta c ON c.id = f.consulta_id JOIN turno t ON t.id = c.turno_id
  WHERE c.id BETWEEN 30001 AND 30765 AND t.estado <> 'ATENDIDO';
DELETE i FROM item_insumo_consulta i JOIN consulta c ON c.id = i.consulta_id JOIN turno t ON t.id = c.turno_id
  WHERE c.id BETWEEN 30001 AND 30765 AND t.estado <> 'ATENDIDO';
DELETE i FROM item_producto_consulta i JOIN consulta c ON c.id = i.consulta_id JOIN turno t ON t.id = c.turno_id
  WHERE c.id BETWEEN 30001 AND 30765 AND t.estado <> 'ATENDIDO';
UPDATE evento_sanitario SET consulta_id = NULL WHERE consulta_id BETWEEN 30001 AND 30765;
DELETE c FROM consulta c JOIN turno t ON t.id = c.turno_id
  WHERE c.id BETWEEN 30001 AND 30765 AND t.estado <> 'ATENDIDO';

-- Diagnóstico e indicaciones: en las vacunaciones, la vacuna que le toca según la especie; en las
-- consultas, uno de diez motivos comunes (el número sale del id del turno).
INSERT INTO consulta (id, turno_id, diagnostico, observaciones, valor_base, estado, finalizada_en)
SELECT t.id, t.id,
       CASE
         WHEN t.id = 30761 THEN 'Otitis externa en el oído derecho, con secreción y picazón.'
         WHEN t.id = 30763 THEN 'Control de senior: buen estado general. Sarro moderado y leve soplo, a controlar.'
         WHEN t.motivo = 'VACUNACION' THEN
           IF(m.especie = 'GATO',
              IF(t.id % 2 = 0, 'Aplicación de vacuna triple felina (refuerzo anual).', 'Aplicación de vacuna antirrábica.'),
              IF(t.id % 2 = 0, 'Aplicación de vacuna séxtuple (refuerzo anual).', 'Aplicación de vacuna antirrábica.'))
         ELSE ELT(1 + (t.id % 10),
           'Control general: sano, peso adecuado.',
           'Otitis externa leve.',
           'Gastroenteritis leve: vómitos y diarrea de 48 horas.',
           'Dermatitis alérgica por picadura de pulga.',
           'Control de peso: sobrepeso leve.',
           'Conjuntivitis bacteriana.',
           'Control posquirúrgico de castración: buena cicatrización.',
           'Cojera leve del miembro posterior izquierdo, sin fractura.',
           'Sarro dental moderado y gingivitis.',
           'Parásitos intestinales.')
       END,
       CASE
         WHEN t.id = 30761 THEN 'Limpieza de oído y gotas óticas cada 12 horas por 7 días. Control en 15 días.'
         WHEN t.id = 30763 THEN 'Se sugiere limpieza dental programada y ecocardiograma de control.'
         WHEN t.motivo = 'VACUNACION' THEN 'Sin reacciones. Próxima dosis según el calendario.'
         ELSE ELT(1 + (t.id % 10),
           NULL,
           'Limpieza y gotas óticas por 7 días.',
           'Dieta blanda por 3 días e hidratación. Volver si no mejora.',
           'Antiparasitario externo mensual y antiinflamatorio por 5 días.',
           'Reducir la ración un 15 % y más paseos. Control en 30 días.',
           'Colirio antibiótico cada 8 horas por 7 días.',
           'Retirar los puntos en 3 días.',
           'Reposo y antiinflamatorio por 5 días. Si sigue, radiografía.',
           'Se sugiere limpieza dental con anestesia.',
           'Antiparasitario interno y repetir en 15 días.')
       END,
       t.precio_consulta,
       'FINALIZADA',
       TIMESTAMP(t.fecha, t.hora) + INTERVAL (20 + t.id % 20) MINUTE
FROM turno t JOIN mascota m ON m.id = t.mascota_id
WHERE t.id BETWEEN 30001 AND 30765 AND t.estado = 'ATENDIDO'
ON DUPLICATE KEY UPDATE
  turno_id = VALUES(turno_id), diagnostico = VALUES(diagnostico), observaciones = VALUES(observaciones),
  valor_base = VALUES(valor_base), estado = VALUES(estado), finalizada_en = VALUES(finalizada_en);

-- Lo que se usó. Insumos: en las vacunaciones, la vacuna (séxtuple 3009, triple felina 3010 o
-- antirrábica 3011) y una jeringa (3001); en el resto, guantes (3004) y a veces gasa (3005).
DELETE FROM item_insumo_consulta WHERE consulta_id BETWEEN 30001 AND 30765;
DELETE FROM item_producto_consulta WHERE consulta_id BETWEEN 30001 AND 30765;

INSERT INTO item_insumo_consulta (consulta_id, insumo_id, cantidad, costo_unitario)
SELECT c.id, i.id, 1, i.costo
FROM consulta c JOIN turno t ON t.id = c.turno_id JOIN mascota m ON m.id = t.mascota_id
JOIN insumo i ON i.id = IF(t.motivo = 'VACUNACION',
                           IF(c.diagnostico LIKE '%antirrábica%', 3011, IF(m.especie = 'GATO', 3010, 3009)),
                           3004)
WHERE c.id BETWEEN 30001 AND 30765;

INSERT INTO item_insumo_consulta (consulta_id, insumo_id, cantidad, costo_unitario)
SELECT c.id, i.id, 1, i.costo
FROM consulta c JOIN turno t ON t.id = c.turno_id
JOIN insumo i ON i.id = IF(t.motivo = 'VACUNACION', 3001, 3005)
WHERE c.id BETWEEN 30001 AND 30765 AND (t.motivo = 'VACUNACION' OR c.id % 3 = 0);

-- Productos de la tienda que se llevan de la consulta, según el diagnóstico: antiinflamatorio (3019),
-- antibiótico (3020), pipeta (3001) o antiparasitario (3009).
INSERT INTO item_producto_consulta (consulta_id, producto_id, cantidad, precio_unitario)
SELECT c.id, p.id, 1, p.precio
FROM consulta c JOIN turno t ON t.id = c.turno_id
JOIN producto p ON p.id = CASE
    WHEN c.diagnostico LIKE 'Dermatitis%' THEN 3001
    WHEN c.diagnostico LIKE 'Cojera%' THEN 3019
    WHEN c.diagnostico LIKE 'Conjuntivitis%' THEN 3020
    WHEN c.diagnostico LIKE 'Parásitos%' THEN 3009
    ELSE NULL END
WHERE c.id BETWEEN 30001 AND 30765 AND t.motivo = 'CONSULTA';

-- Facturas: mismo id que la consulta (C-030001...). Pagadas si tienen más de una semana.
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
WHERE c.id BETWEEN 30001 AND 30765
ON DUPLICATE KEY UPDATE
  numero = VALUES(numero), consulta_id = VALUES(consulta_id), subtotal_base = VALUES(subtotal_base),
  subtotal_insumos = VALUES(subtotal_insumos), subtotal_productos = VALUES(subtotal_productos),
  total = VALUES(total), estado = VALUES(estado), fecha = VALUES(fecha);

-- 4. Calendario sanitario.
-- Cada vacunación atendida queda aplicada en el calendario de su mascota (mismo id que la consulta).
DELETE FROM evento_sanitario WHERE id BETWEEN 30001 AND 30765;
INSERT INTO evento_sanitario
  (id, mascota_id, plan_sanitario_id, tipo, nombre, fecha_programada, fecha_aplicada, consulta_id)
SELECT c.id, t.mascota_id, NULL, 'VACUNA',
       CASE WHEN c.diagnostico LIKE '%antirrábica%' THEN 'Antirrábica'
            WHEN c.diagnostico LIKE '%triple felina%' THEN 'Triple felina (refuerzo anual)'
            ELSE 'Séxtuple (refuerzo anual)' END,
       t.fecha, t.fecha, c.id
FROM consulta c JOIN turno t ON t.id = c.turno_id
WHERE c.id BETWEEN 30001 AND 30765 AND t.motivo = 'VACUNACION';

-- Las mascotas de la demo: Rocco tiene la desparasitación vencida y la antirrábica para el turno de
-- dentro de 3 días; Mishi está al día; Coco tiene la séxtuple vencida; Lola, la antirrábica en 20 días.
INSERT INTO evento_sanitario
  (id, mascota_id, plan_sanitario_id, tipo, nombre, fecha_programada, fecha_aplicada, consulta_id)
VALUES
  (30901, 30081, NULL, 'VACUNA',          'Séxtuple (refuerzo anual)',      @hoy - INTERVAL 11 MONTH, @hoy - INTERVAL 11 MONTH, NULL),
  (30902, 30081, NULL, 'VACUNA',          'Antirrábica',                    @hoy + INTERVAL 3 DAY,    NULL,                     NULL),
  (30903, 30081, NULL, 'DESPARASITACION', 'Desparasitación interna',        @hoy - INTERVAL 2 WEEK,   NULL,                     NULL),
  (30904, 30082, NULL, 'VACUNA',          'Triple felina (refuerzo anual)', @hoy - INTERVAL 61 DAY,   @hoy - INTERVAL 61 DAY,   30762),
  (30905, 30082, NULL, 'VACUNA',          'Antirrábica',                    @hoy + INTERVAL 4 MONTH,  NULL,                     NULL),
  (30906, 30082, NULL, 'DESPARASITACION', 'Desparasitación interna',        @hoy + INTERVAL 1 MONTH,  NULL,                     NULL),
  (30907, 30083, NULL, 'VACUNA',          'Séxtuple (refuerzo anual)',      @hoy - INTERVAL 1 MONTH,  NULL,                     NULL),
  (30908, 30083, NULL, 'VACUNA',          'Antirrábica',                    @hoy + INTERVAL 2 MONTH,  NULL,                     NULL),
  (30909, 30084, NULL, 'VACUNA',          'Séxtuple (3.ª dosis)',           @hoy - INTERVAL 10 MONTH, @hoy - INTERVAL 10 MONTH, NULL),
  (30910, 30084, NULL, 'VACUNA',          'Antirrábica',                    @hoy + INTERVAL 20 DAY,   NULL,                     NULL)
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id), plan_sanitario_id = VALUES(plan_sanitario_id), tipo = VALUES(tipo),
  nombre = VALUES(nombre), fecha_programada = VALUES(fecha_programada),
  fecha_aplicada = VALUES(fecha_aplicada), consulta_id = VALUES(consulta_id);
-- La vacuna de Mishi de hace 2 meses queda aplicada en su consulta (30762), no como evento aparte.
DELETE FROM evento_sanitario WHERE id = 30762;

-- Antirrábicas de otras mascotas que vencen en los próximos 0 a 9 días (aviso del motor).
INSERT INTO evento_sanitario
  (id, mascota_id, plan_sanitario_id, tipo, nombre, fecha_programada, fecha_aplicada, consulta_id)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 30)
SELECT 30800 + i, 30000 + i * 2 + 1, NULL, 'VACUNA', 'Antirrábica', @hoy + INTERVAL (i % 10) DAY, NULL, NULL
FROM n
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id), tipo = VALUES(tipo), nombre = VALUES(nombre),
  fecha_programada = VALUES(fecha_programada), fecha_aplicada = NULL, consulta_id = NULL;
