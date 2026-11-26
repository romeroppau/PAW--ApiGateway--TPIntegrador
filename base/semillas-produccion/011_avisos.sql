-- Producción 011 · los avisos de la campana, armados con lo que cargaron las otras semillas
-- (reemplaza a 007, que inventaba avisos sueltos). Cada aviso cuenta algo que pasó, con el mismo texto
-- que manda el sistema:
--   - Veterinaria: los pedidos pagados para retirar, las reseñas nuevas, las publicaciones que esperan
--     revisión, los adoptantes elegidos y el stock bajo de hoy.
--   - Cliente de la demo 1: el pago de cada pedido suyo, el turno de Rocco, la antirrábica que le toca
--     y la séxtuple vencida de Coco (una vez por semana, como el motor).
--   - Cliente de la demo 2: el turno de Lola.
--   - Rescatista de la demo: las postulaciones a sus publicaciones y la aprobación de cada una.
--   Todos por la web y ya enviados (la tarea de envío no los manda por WhatsApp); los de los últimos 3
--   días, sin leer. id_operacion "prod-aviso-…": una recarga los vuelve a dejar así.
-- Va al final, después de las compras, las adopciones, las reseñas y los turnos.

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;
SET @hoy = DATE(@ahora);

DELETE FROM notificacion WHERE id_operacion LIKE 'prod-aviso-%';

-- "jueves 03/12/2026"
DROP TEMPORARY TABLE IF EXISTS prod_aviso;
CREATE TEMPORARY TABLE prod_aviso (n INT NOT NULL AUTO_INCREMENT, usuario_id INT UNSIGNED NOT NULL, tipo VARCHAR(20) NOT NULL,
  mensaje VARCHAR(500) NOT NULL, fecha DATETIME NOT NULL, ref VARCHAR(60) NOT NULL, PRIMARY KEY (n));

-- Veterinaria: cada pedido pagado de los últimos dos meses.
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT @vet, 'COMPRA',
       CONCAT('🛍️ Nuevo pedido para retirar: ', f.numero, ' de ', u.nombre, ' ($ ', FORMAT(f.total, 2, 'es_AR'), '). Fecha límite de retiro: ',
              ELT(DAYOFWEEK(f.retirar_hasta), 'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'), ' ',
              DATE_FORMAT(f.retirar_hasta, '%d/%m/%Y'), '.'),
       p.fecha, CONCAT('pedido-', f.numero)
FROM factura_compra f JOIN carrito c ON c.id = f.carrito_id JOIN usuario u ON u.id = c.cliente_id
JOIN pago p ON p.factura_compra_id = f.id AND p.estado = 'APROBADO'
WHERE f.id BETWEEN 30001 AND 30150 AND f.fecha >= @ahora - INTERVAL 60 DAY;

-- Veterinaria: cada reseña.
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT @vet, 'RESENA',
       CONCAT('⭐ Nueva reseña de ', SUBSTRING_INDEX(u.nombre, ' ', 1), ' ', LEFT(SUBSTRING_INDEX(u.nombre, ' ', -1), 1), '. (',
              r.estrellas, IF(r.estrellas = 1, ' estrella', ' estrellas'), '): "',
              IF(CHAR_LENGTH(r.texto) > 80, CONCAT(LEFT(r.texto, 80), '…'), r.texto), '"'),
       r.creada_en, CONCAT('resena-', r.id)
FROM resena r JOIN usuario u ON u.id = r.autor_id WHERE r.id BETWEEN 30001 AND 30022;

-- Veterinaria: las publicaciones que llegaron a revisión y los adoptantes elegidos.
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT @vet, 'POSTULACION',
       CONCAT(u.nombre, ' publicó a ', m.nombre, ' para adopción y espera tu revisión. Está en Adopción → Publicaciones.'),
       pu.creada_en, CONCAT('publicacion-', pu.id)
FROM publicacion pu JOIN usuario u ON u.id = pu.rescatista_id JOIN mascota m ON m.id = pu.mascota_id
WHERE pu.id BETWEEN 30001 AND 30044 AND pu.creada_en >= @ahora - INTERVAL 60 DAY;

INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT @vet, 'POSTULACION',
       CONCAT('Eligieron a ', u.nombre, ' para adoptar a ', m.nombre,
              ' y espera el turno del chequeo. Coordinalo, cargalo en la Agenda y asignalo en Adopción → Adopciones en curso.'),
       po.fecha + INTERVAL 1 DAY, CONCAT('elegido-', a.id)
FROM adopcion a JOIN postulacion po ON po.adopcion_id = a.id AND po.estado = 'ELEGIDA'
JOIN usuario u ON u.id = po.cliente_id JOIN publicacion pu ON pu.id = a.publicacion_id JOIN mascota m ON m.id = pu.mascota_id
WHERE a.id BETWEEN 30001 AND 30044 AND po.fecha + INTERVAL 1 DAY <= @ahora AND po.fecha >= @ahora - INTERVAL 60 DAY;

-- Veterinaria: el stock bajo de hoy (el motor de las 9).
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT @vet, 'STOCK_BAJO', CONCAT('Stock bajo para producto ''', p.nombre, ''' (quedan ', p.stock, ' unidades).'),
       TIMESTAMP(@hoy, '09:00:00'), CONCAT('stock-producto-', p.id)
FROM producto p WHERE p.id BETWEEN 3001 AND 3030 AND p.activo = 1 AND p.stock <= 10 AND @ahora >= TIMESTAMP(@hoy, '09:00:00');
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT @vet, 'STOCK_BAJO', CONCAT('Stock bajo para insumo ''', i.nombre, ''' (quedan ', i.stock, ' unidades).'),
       TIMESTAMP(@hoy, '09:00:00'), CONCAT('stock-insumo-', i.id)
FROM insumo i WHERE i.id BETWEEN 3001 AND 3017 AND i.activo = 1 AND i.stock <= 10 AND @ahora >= TIMESTAMP(@hoy, '09:00:00');

-- Clientes de la demo: el pago de cada pedido suyo.
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT c.cliente_id, 'COMPRA',
       CONCAT('✅ ¡Hola, ', SUBSTRING_INDEX(u.nombre, ' ', 1), '! Recibimos el pago de tu pedido ', f.numero,
              '. Ya podés retirarlo en HuellaVet hasta el ',
              ELT(DAYOFWEEK(f.retirar_hasta), 'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'), ' ',
              DATE_FORMAT(f.retirar_hasta, '%d/%m/%Y'), ' inclusive. ¡Te esperamos!'),
       p.fecha, CONCAT('pagado-', f.numero)
FROM factura_compra f JOIN carrito c ON c.id = f.carrito_id JOIN usuario u ON u.id = c.cliente_id
JOIN pago p ON p.factura_compra_id = f.id AND p.estado = 'APROBADO'
WHERE f.id BETWEEN 30001 AND 30150 AND c.cliente_id IN (@cliente1, @cliente2);

-- Clientes de la demo: el aviso de cada turno que viene de sus mascotas (cuando se cargó, hace 2 días).
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT m.duenio_id, 'TURNO',
       CONCAT('Tenés turno de ',
              (SELECT GROUP_CONCAT(IF(e.id IS NULL, LOWER(REPLACE(tm.motivo, '_', ' ')),
                                      CONCAT(IF(tm.motivo = 'VACUNACION', 'vacunación', 'desparasitación'), ' (', e.nombre, ')'))
                                   ORDER BY tm.id SEPARATOR ' y ')
               FROM turno_motivo tm LEFT JOIN evento_sanitario e ON e.id = tm.evento_sanitario_id WHERE tm.turno_id = t.id),
              ' para ', m.nombre, ' el ',
              ELT(DAYOFWEEK(t.fecha), 'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'), ' ',
              DATE_FORMAT(t.fecha, '%d/%m'), ' a las ', TIME_FORMAT(t.hora, '%H:%i'), ' en HuellaVet. La consulta: $ ',
              FORMAT(t.precio_consulta, 0, 'es_AR'), '. Si no podés ir, avisanos por WhatsApp.'),
       @ahora - INTERVAL 2 DAY, CONCAT('turno-', t.id)
FROM turno t JOIN mascota m ON m.id = t.mascota_id
WHERE m.duenio_id IN (@cliente1, @cliente2) AND t.estado = 'PROGRAMADO' AND t.fecha >= @hoy;

-- Cliente de la demo 1: el motor (la vacuna próxima de los próximos 7 días, una vez; la vencida, una
-- vez por semana desde que venció).
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT m.duenio_id, 'VACUNA', CONCAT('A ', m.nombre, ' le toca la vacuna ', e.nombre, ' el ', DATE_FORMAT(e.fecha_programada, '%d/%m/%Y')),
       TIMESTAMP(GREATEST(e.fecha_programada - INTERVAL 7 DAY, @hoy - INTERVAL 2 DAY), '09:00:00'), CONCAT('vacuna-proxima-', e.id)
FROM evento_sanitario e JOIN mascota m ON m.id = e.mascota_id
WHERE m.duenio_id IN (@cliente1, @cliente2) AND e.tipo = 'VACUNA' AND e.fecha_aplicada IS NULL
  AND e.fecha_programada BETWEEN @hoy AND @hoy + INTERVAL 7 DAY;

INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
WITH RECURSIVE s AS (SELECT 0 AS k UNION ALL SELECT k + 1 FROM s WHERE k < 10)
SELECT m.duenio_id, 'VACUNA',
       CONCAT('La vacuna ', e.nombre, ' de ', m.nombre, ' está vencida desde el ', DATE_FORMAT(e.fecha_programada, '%d/%m/%Y')),
       TIMESTAMP(e.fecha_programada + INTERVAL (1 + 7 * s.k) DAY, '09:00:00'), CONCAT('vacuna-vencida-', e.id, '-', s.k)
FROM evento_sanitario e JOIN mascota m ON m.id = e.mascota_id CROSS JOIN s
WHERE m.duenio_id IN (@cliente1, @cliente2) AND e.tipo = 'VACUNA' AND e.fecha_aplicada IS NULL
  AND e.fecha_programada < @hoy AND e.fecha_programada + INTERVAL (1 + 7 * s.k) DAY <= @hoy;

-- Rescatista de la demo: las postulaciones a sus publicaciones y la aprobación de cada una.
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT @rescatista, 'POSTULACION', CONCAT(u.nombre, ' se postuló para adoptar a ', m.nombre, '. Revisá la postulación en Mis publicaciones.'),
       po.fecha, CONCAT('postulacion-', po.id)
FROM postulacion po JOIN adopcion a ON a.id = po.adopcion_id JOIN publicacion pu ON pu.id = a.publicacion_id
JOIN mascota m ON m.id = pu.mascota_id JOIN usuario u ON u.id = po.cliente_id
WHERE pu.rescatista_id = @rescatista AND a.id BETWEEN 30001 AND 30044;
INSERT INTO prod_aviso (usuario_id, tipo, mensaje, fecha, ref)
SELECT @rescatista, 'POSTULACION', CONCAT('¡Aprobamos la publicación de ', m.nombre, '! Ya se ve en Adopciones y pueden postularse.'),
       pu.creada_en + INTERVAL 3 HOUR, CONCAT('aprobada-', pu.id)
FROM publicacion pu JOIN mascota m ON m.id = pu.mascota_id
WHERE pu.rescatista_id = @rescatista AND pu.id BETWEEN 30001 AND 30044 AND pu.estado_moderacion = 'APROBADA';

INSERT INTO notificacion
  (usuario_id, tipo, canal, mensaje, fecha_programada, enviada_en, intentos, ultimo_error, leida, id_operacion, creada_en)
SELECT usuario_id, tipo, 'WEB', mensaje, fecha, fecha, 0, NULL, fecha < @ahora - INTERVAL 3 DAY,
       CONCAT('prod-aviso-', ref, '-', usuario_id), fecha
FROM prod_aviso WHERE fecha <= @ahora
ORDER BY fecha, n;

DROP TEMPORARY TABLE IF EXISTS prod_aviso;
