-- Producción 007 · 120 avisos de la campana (ids 30001 a 30120), de los últimos 2 meses
--
--   La mitad para la veterinaria (stock bajo, pedidos nuevos, postulaciones y reseñas), 45 para el
--   cliente de la demo 1 (vacunas de Rocco y Coco, pedidos listos, promociones) y 15 para el rescatista
--   de la demo (postulaciones y moderación). Nombran productos, mascotas y personas de verdad.
--   Uno cada 12 horas hacia atrás; los 10 más nuevos, sin leer.
--   Todos por la web y ya enviados: la tarea de envío nunca los manda por WhatsApp.
-- Correr de nuevo los vuelve a dejar así (también los que se marcaron como leídos).

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

INSERT INTO notificacion
  (id, usuario_id, tipo, canal, mensaje, fecha_programada, enviada_en, intentos, ultimo_error, leida, id_operacion, creada_en)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 120)
SELECT 30000 + n.i,
       CASE WHEN n.i % 8 < 4 THEN @vet WHEN n.i % 8 < 7 THEN @cliente1 ELSE @rescatista END,
       CASE
         WHEN n.i % 8 < 4 THEN ELT(1 + (n.i DIV 8) % 4, 'STOCK_BAJO', 'COMPRA', 'POSTULACION', 'RESENA')
         WHEN n.i % 8 < 7 THEN ELT(1 + (n.i DIV 8) % 4, 'VACUNA', 'COMPRA', 'PROMOCION', 'VACUNA')
         ELSE ELT(1 + (n.i DIV 8) % 2, 'POSTULACION', 'CUENTA')
       END,
       'WEB',
       CASE
         WHEN n.i % 8 < 4 THEN ELT(1 + (n.i DIV 8) % 4,
           CONCAT('Stock bajo: quedan ', p.stock, ' unidades de ', p.nombre, '.'),
           CONCAT('Nuevo pedido para retirar: V-', LPAD(30001 + (n.i % 150), 6, '0'), ' de ', u.nombre, '.'),
           CONCAT(u.nombre, ' se postuló para adoptar a ', m.nombre, '.'),
           CONCAT('Nueva reseña de ', SUBSTRING_INDEX(u.nombre, ' ', 1), ' ',
                  LEFT(SUBSTRING_INDEX(u.nombre, ' ', -1), 1), '. (', 4 + n.i % 2, ' estrellas).'))
         WHEN n.i % 8 < 7 THEN ELT(1 + (n.i DIV 8) % 4,
           CONCAT('A Rocco le toca la vacuna antirrábica el ',
                  DATE_FORMAT(@ahora + INTERVAL 3 DAY, '%d/%m/%Y'), '. Ya tiene el turno.'),
           CONCAT('Tu pedido V-', LPAD(30002 + 8 * (n.i % 18), 6, '0'), ' está listo para retirar.'),
           CONCAT(p.nombre, ' tiene 15 % de descuento en la tienda.'),
           'Coco tiene la vacuna séxtuple vencida. Pedí un turno para ponerla al día.')
         ELSE ELT(1 + (n.i DIV 8) % 2,
           CONCAT(u.nombre, ' se postuló para adoptar a Bartolo.'),
           'La veterinaria aprobó tu publicación de Pimienta: ya la ven los clientes.')
       END,
       @ahora - INTERVAL (n.i * 12) HOUR,
       @ahora - INTERVAL (n.i * 12) HOUR,
       0, NULL,
       n.i > 10,
       CONCAT('prod-aviso-', n.i),
       @ahora - INTERVAL (n.i * 12) HOUR
FROM n
JOIN producto p ON p.id = 3007 + (n.i % 6)
JOIN usuario u ON u.id = 3001 + (n.i % 40)
JOIN mascota m ON m.id = 30101 + (n.i % 40)
ON DUPLICATE KEY UPDATE
  usuario_id = VALUES(usuario_id), tipo = VALUES(tipo), canal = VALUES(canal), mensaje = VALUES(mensaje),
  fecha_programada = VALUES(fecha_programada), enviada_en = VALUES(enviada_en), intentos = 0, ultimo_error = NULL,
  leida = VALUES(leida), creada_en = VALUES(creada_en);
