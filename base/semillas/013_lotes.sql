-- Semilla 013 · lotes de los productos (migración 028)
-- Las semillas de antes (002 y las demás) cargan el stock y el vencimiento en producto. Desde la 028
-- el stock está en los lotes: este archivo los pone de acuerdo, sin ids fijos (busca los lotes por
-- producto y vencimiento). Va al final, después de las semillas que cambian stock.
--   1. Un producto sin lotes: uno con todo su stock y su vencimiento.
--   2. Un producto cuyo stock no es la suma de sus lotes (la semilla lo volvió a su valor): sus lotes
--      quedan en 0 y el stock va a un lote con su vencimiento (el que ya había, o uno nuevo).
-- Correrlo de nuevo no cambia nada si el stock y los lotes ya coinciden.

-- 1.
INSERT INTO lote_producto (producto_id, codigo, vencimiento, stock, creado_en)
SELECT p.id, NULL, p.fecha_vencimiento, p.stock, UTC_TIMESTAMP() - INTERVAL 3 HOUR
FROM producto p
WHERE NOT EXISTS (SELECT 1 FROM lote_producto l WHERE l.producto_id = p.id);

-- 2. (con una tabla temporal: MySQL no deja leer y cambiar lote_producto en la misma sentencia)
CREATE TEMPORARY TABLE semilla_lotes_distintos (producto_id INT UNSIGNED PRIMARY KEY);
INSERT INTO semilla_lotes_distintos (producto_id)
SELECT p.id FROM producto p
WHERE p.stock <> (SELECT COALESCE(SUM(l.stock), 0) FROM lote_producto l WHERE l.producto_id = p.id);

UPDATE lote_producto l JOIN semilla_lotes_distintos d ON d.producto_id = l.producto_id SET l.stock = 0;

INSERT INTO lote_producto (producto_id, codigo, vencimiento, stock, creado_en)
SELECT p.id, NULL, p.fecha_vencimiento, 0, UTC_TIMESTAMP() - INTERVAL 3 HOUR
FROM producto p JOIN semilla_lotes_distintos d ON d.producto_id = p.id
WHERE NOT EXISTS (SELECT 1 FROM lote_producto l WHERE l.producto_id = p.id AND l.vencimiento <=> p.fecha_vencimiento);

-- El lote con ese vencimiento que se creó primero recibe el stock.
UPDATE lote_producto l
JOIN producto p ON p.id = l.producto_id
JOIN semilla_lotes_distintos d ON d.producto_id = p.id
JOIN (SELECT l2.producto_id, MIN(l2.id) AS id FROM lote_producto l2
      JOIN producto p2 ON p2.id = l2.producto_id
      WHERE l2.vencimiento <=> p2.fecha_vencimiento GROUP BY l2.producto_id) primero ON primero.id = l.id
SET l.stock = p.stock;

DROP TEMPORARY TABLE semilla_lotes_distintos;

-- 3. Solo en las semillas de prueba: la pipeta Frontline (107) tiene dos lotes, para probar que se
--    vende primero el que vence antes y la promoción de un lote. 8 unidades vencen en 20 días (el
--    vencimiento de la semilla 002) y 10 más en 200 días, con número de lote.
UPDATE lote_producto SET codigo = 'FL-2612' WHERE producto_id = 107 AND vencimiento = CURDATE() + INTERVAL 20 DAY;
INSERT INTO lote_producto (producto_id, codigo, vencimiento, stock, creado_en)
SELECT 107, 'FL-0627', CURDATE() + INTERVAL 200 DAY, 0, UTC_TIMESTAMP() - INTERVAL 3 HOUR
FROM producto WHERE id = 107
  AND NOT EXISTS (SELECT 1 FROM lote_producto WHERE producto_id = 107 AND codigo = 'FL-0627');
UPDATE lote_producto SET stock = 8  WHERE producto_id = 107 AND codigo = 'FL-2612' AND (SELECT stock FROM producto WHERE id = 107) = 18;
UPDATE lote_producto SET stock = 10 WHERE producto_id = 107 AND codigo = 'FL-0627' AND (SELECT stock FROM producto WHERE id = 107) = 18
  AND (SELECT s.stock FROM (SELECT stock FROM lote_producto WHERE producto_id = 107 AND codigo = 'FL-2612') s) = 8;

-- 4. producto.stock y producto.fecha_vencimiento, de los lotes (como los deja Inventario).
UPDATE producto p SET
  p.stock = (SELECT COALESCE(SUM(l.stock), 0) FROM lote_producto l WHERE l.producto_id = p.id),
  p.fecha_vencimiento = (SELECT MIN(l.vencimiento) FROM lote_producto l WHERE l.producto_id = p.id AND l.stock > 0);
