-- Producción 010 · los movimientos de stock de productos e insumos, para que cierren con el stock
-- Va después de 009 (los lotes). Lo que dejó cada semilla:
--   - 003 y 005: lo que usó cada consulta (sus ítems) sale del stock: un movimiento SALIDA / CONSULTA por
--     insumo y por producto, con el id que usa Pacientes ("consulta-{consulta}-insumo-{insumo}"), así
--     en Movimientos enlaza a su consulta.
--   - 006: las ventas y las devoluciones de las compras canceladas.
--   - Las cargas de la veterinaria: cuatro por producto o insumo en los seis meses, por lo que tuvo que
--     entrar para que, con las salidas y las devoluciones, quede exactamente el stock de 002.
--   Cada movimiento queda en el lote del producto o insumo (009).
-- Correr de nuevo deja todo como estaba.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);
SET @lunes = @hoy - INTERVAL WEEKDAY(@hoy) DAY;

-- 1. Lo que usaron las consultas de las semillas (las de la carga anterior se borran antes).
DELETE FROM movimiento_inventario
WHERE motivo = 'CONSULTA' AND id_operacion LIKE 'consulta-%'
  AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(id_operacion, '-', 2), '-', -1) AS UNSIGNED) BETWEEN 30001 AND 30844;

INSERT INTO movimiento_inventario (producto_id, insumo_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha)
SELECT NULL, i.insumo_id, 'SALIDA', i.cantidad, 'CONSULTA', @vet, CONCAT('consulta-', i.consulta_id, '-insumo-', i.insumo_id), c.finalizada_en
FROM item_insumo_consulta i JOIN consulta c ON c.id = i.consulta_id
WHERE c.id BETWEEN 30001 AND 30844;

INSERT INTO movimiento_inventario (producto_id, insumo_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha)
SELECT i.producto_id, NULL, 'SALIDA', i.cantidad, 'CONSULTA', @vet, CONCAT('consulta-', i.consulta_id, '-producto-', i.producto_id), c.finalizada_en
FROM item_producto_consulta i JOIN consulta c ON c.id = i.consulta_id
WHERE c.id BETWEEN 30001 AND 30844;

-- 2. Las cargas. Lo que tuvo que entrar = el stock de hoy + lo que salió - lo que volvió (sin contar las
--    cargas de la carga anterior, que se borran). Se reparte en cuatro cargas: hace 26, 19, 13 y 6
--    semanas (la primera con lo que sobra de dividir).
DELETE FROM movimiento_inventario WHERE id_operacion LIKE 'prod-carga-%';

DROP TEMPORARY TABLE IF EXISTS prod_carga;
CREATE TEMPORARY TABLE prod_carga (tipo CHAR(1) NOT NULL, item INT UNSIGNED NOT NULL, total INT NOT NULL, PRIMARY KEY (tipo, item));
INSERT INTO prod_carga (tipo, item, total)
SELECT 'P', p.id, p.stock + COALESCE(SUM(CASE WHEN m.tipo = 'SALIDA' THEN m.cantidad WHEN m.tipo = 'ENTRADA' THEN -m.cantidad ELSE 0 END), 0)
FROM producto p LEFT JOIN movimiento_inventario m ON m.producto_id = p.id
WHERE p.id BETWEEN 3001 AND 3030 GROUP BY p.id, p.stock;
INSERT INTO prod_carga (tipo, item, total)
SELECT 'I', i.id, i.stock + COALESCE(SUM(CASE WHEN m.tipo = 'SALIDA' THEN m.cantidad WHEN m.tipo = 'ENTRADA' THEN -m.cantidad ELSE 0 END), 0)
FROM insumo i LEFT JOIN movimiento_inventario m ON m.insumo_id = i.id
WHERE i.id BETWEEN 3001 AND 3017 GROUP BY i.id, i.stock;

INSERT INTO movimiento_inventario (producto_id, insumo_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha)
WITH k AS (SELECT 0 AS k, 182 AS dias UNION ALL SELECT 1, 136 UNION ALL SELECT 2, 91 UNION ALL SELECT 3, 45)
SELECT IF(c.tipo = 'P', c.item, NULL), IF(c.tipo = 'I', c.item, NULL), 'ENTRADA',
       IF(k.k = 0, c.total - 3 * FLOOR(c.total / 4), FLOOR(c.total / 4)), 'CARGA_VETERINARIO', @vet,
       CONCAT('prod-carga-', IF(c.tipo = 'P', 'producto-', 'insumo-'), c.item, '-', k.k),
       TIMESTAMP(@lunes - INTERVAL k.dias DAY, '09:30:00') + INTERVAL c.item % 50 MINUTE
FROM prod_carga c CROSS JOIN k
WHERE IF(k.k = 0, c.total - 3 * FLOOR(c.total / 4), FLOOR(c.total / 4)) > 0;
DROP TEMPORARY TABLE IF EXISTS prod_carga;

-- 3. El lote de cada movimiento de las semillas: el lote del producto o insumo que tiene el stock (el
--    más nuevo, si ninguno tiene).
UPDATE movimiento_inventario m
SET m.lote_id = (SELECT l.id FROM lote_producto l WHERE l.producto_id = m.producto_id ORDER BY l.stock > 0 DESC, l.id DESC LIMIT 1)
WHERE m.producto_id BETWEEN 3001 AND 3030
  AND (m.id_operacion LIKE 'prod-%' OR m.id_operacion LIKE 'consulta-%');
UPDATE movimiento_inventario m
SET m.lote_insumo_id = (SELECT l.id FROM lote_insumo l WHERE l.insumo_id = m.insumo_id ORDER BY l.stock > 0 DESC, l.id DESC LIMIT 1)
WHERE m.insumo_id BETWEEN 3001 AND 3017
  AND (m.id_operacion LIKE 'prod-%' OR m.id_operacion LIKE 'consulta-%');
