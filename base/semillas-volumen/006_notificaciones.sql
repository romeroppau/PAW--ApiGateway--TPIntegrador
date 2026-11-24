-- Volumen 006 · 200 avisos web viejos y nuevos (ids 20001 a 20200), para la campana y su paginación
--
--   Mitad para la veterinaria de prueba 101 (stock bajo, compras, postulaciones) y mitad para el
--   cliente de prueba 102 (vacunas, controles de adopción, promociones, compras).
--   Uno cada 11 horas hacia atrás (los últimos ~3 meses). Los 12 más nuevos, sin leer.
--   Todos por la web y ya enviados: la tarea de envío nunca los manda por WhatsApp.
-- Correr de nuevo los vuelve a dejar así (también los que se marcaron como leídos).

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

INSERT INTO notificacion
  (id, usuario_id, tipo, canal, mensaje, fecha_programada, enviada_en, leida, id_operacion, creada_en)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 200)
SELECT 20000 + i,
       IF(i % 2 = 0, 101, 102),
       IF(i % 2 = 0,
          ELT(1 + (i DIV 2) % 3, 'STOCK_BAJO', 'COMPRA', 'POSTULACION'),
          ELT(1 + (i DIV 2) % 4, 'VACUNA', 'CONTROL_ADOPCION', 'PROMOCION', 'COMPRA')),
       'WEB',
       IF(i % 2 = 0,
          ELT(1 + (i DIV 2) % 3,
              CONCAT('Stock bajo: quedan ', 1 + i % 9, ' unidades de un producto de la tienda (aviso ', i, ').'),
              CONCAT('Nuevo pedido para retirar: V-', LPAD(20000 + (i % 150) + 1, 6, '0'), '.'),
              CONCAT('Nueva postulación para una adopción (aviso ', i, ').')),
          ELT(1 + (i DIV 2) % 4,
              CONCAT('A tu mascota le toca la vacuna antirrábica esta semana (aviso ', i, ').'),
              CONCAT('Pasaron 30 días de la adopción: ¿cómo se está adaptando? (aviso ', i, ')'),
              CONCAT('Hay productos en promoción en la tienda (aviso ', i, ').'),
              CONCAT('Tu pedido V-', LPAD(20000 + (i % 150) + 1, 6, '0'), ' está listo para retirar.'))),
       @ahora - INTERVAL (i * 11) HOUR,
       @ahora - INTERVAL (i * 11) HOUR,
       i > 12,
       CONCAT('volumen-aviso-', i),
       @ahora - INTERVAL (i * 11) HOUR
FROM n
ON DUPLICATE KEY UPDATE
  usuario_id = VALUES(usuario_id), tipo = VALUES(tipo), canal = VALUES(canal), mensaje = VALUES(mensaje),
  fecha_programada = VALUES(fecha_programada), enviada_en = VALUES(enviada_en), leida = VALUES(leida),
  creada_en = VALUES(creada_en);
