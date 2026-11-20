-- Volumen 002 · productos en cantidad (ids 2001 a 2030)
--   2001 a 2010: vencen en los próximos 5 a 32 días, con stock: aparecen en "Qué liquidar" de
--                Reportes (los que vencen dentro de dias_liquidar, 30 por defecto) para Publicitar.
--   2011 a 2018: con stock bajo (de 0 a 7 unidades).
--   2019 a 2030: normales.
-- Correr de nuevo vuelve el stock, el precio y el vencimiento a estos valores.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);

INSERT INTO producto
  (id, nombre, descripcion, precio, stock, categoria, especie_destino, etapa_vida, fecha_vencimiento, activo)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 30)
SELECT 2000 + i,
       CONCAT(ELT(1 + (i % 3), 'Alimento', 'Antiparasitario', 'Juguete'), ' ',
              ELT(1 + (i % 10), 'Premium', 'Clásico', 'Natural', 'Light', 'Senior', 'Cachorro', 'Plus',
                  'Original', 'Mix', 'Max'),
              ' ', ELT(1 + (i % 3), 'perro', 'gato', 'perro y gato'), ' (', i, ')'),
       'Producto de prueba del juego de datos en cantidad.',
       2500.00 + i * 730,
       CASE WHEN i <= 10 THEN 3 + i WHEN i <= 18 THEN i - 11 ELSE 25 + i END,
       ELT(1 + (i % 3), 'ALIMENTO', 'MEDICAMENTO', 'ACCESORIO'),
       ELT(1 + (i % 3), 'PERRO', 'GATO', 'TODAS'),
       'TODAS',
       CASE WHEN i <= 10 THEN @hoy + INTERVAL (2 + i * 3) DAY
            WHEN i % 3 = 0 THEN NULL
            ELSE @hoy + INTERVAL (120 + i * 5) DAY END,
       1
FROM n
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre), descripcion = VALUES(descripcion), precio = VALUES(precio), stock = VALUES(stock),
  categoria = VALUES(categoria), especie_destino = VALUES(especie_destino), etapa_vida = VALUES(etapa_vida),
  fecha_vencimiento = VALUES(fecha_vencimiento), activo = VALUES(activo);

-- Movimientos de stock de los productos del volumen: una carga por mes en los últimos 6 meses
-- (para que la pestaña Movimientos de Reportes tenga páginas). id_operacion fijo: una recarga
-- no los repite, solo les corre la fecha.
INSERT INTO movimiento_inventario (producto_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 180)
SELECT 2001 + (i % 30), 'ENTRADA', 5 + (i % 20), 'CARGA_VETERINARIO', 101,
       CONCAT('volumen-carga-', i),
       TIMESTAMP(@hoy - INTERVAL i DAY, '09:15:00')
FROM n
ON DUPLICATE KEY UPDATE
  producto_id = VALUES(producto_id), cantidad = VALUES(cantidad), fecha = VALUES(fecha);
