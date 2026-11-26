-- 009 · lotes de los productos (migración 028) y de los insumos (029), datos para producción. Igual que base/semillas/013_lotes.sql.
-- Las semillas de antes (002, 003 y las demás) cargan el stock y el vencimiento en producto e insumo.
-- Desde la 028 y la 029 el stock está en los lotes: este archivo los pone de acuerdo, sin ids fijos
-- (busca los lotes por producto o insumo y vencimiento). Va al final, después de las semillas que
-- cambian stock. Cada lote nuevo lleva el número que sigue (L1, L2, L3…) de su producto o insumo.
--   1. Un producto o insumo sin lotes: uno con todo su stock y su vencimiento (si vence y no tiene
--      stock ni fecha, ninguno: el primer lote lo carga la veterinaria con su vencimiento).
--   2. Uno cuyo stock no es la suma de sus lotes (la semilla lo volvió a su valor), o que tiene stock
--      en un lote con vencimiento y no vence (o al revés, por ejemplo el L1 sin fecha de cada insumo
--      que dejó la migración 029): sus lotes quedan en 0 y el stock va a un lote con su vencimiento
--      (el que ya había, o uno nuevo).
-- Correrlo de nuevo no cambia nada si el stock y los lotes ya coinciden.

-- ---------- Productos ----------

-- 0. Un lote sin número (lo creó el Inventario de antes de la 029): el que sigue de su producto.
UPDATE lote_producto l
JOIN (SELECT s.id, (SELECT COALESCE(MAX(x.numero), 0) FROM lote_producto x WHERE x.producto_id = s.producto_id)
                   + ROW_NUMBER() OVER (PARTITION BY s.producto_id ORDER BY s.id) AS n
      FROM lote_producto s WHERE s.numero IS NULL) orden ON orden.id = l.id
SET l.numero = orden.n;

-- 1.
INSERT INTO lote_producto (producto_id, numero, codigo, vencimiento, stock, creado_en)
SELECT p.id, 1, NULL, p.fecha_vencimiento, p.stock, UTC_TIMESTAMP() - INTERVAL 3 HOUR
FROM producto p
WHERE NOT EXISTS (SELECT 1 FROM lote_producto l WHERE l.producto_id = p.id)
  AND (p.stock > 0 OR p.fecha_vencimiento IS NOT NULL OR NOT p.vence);

-- 2. (con una tabla temporal: MySQL no deja leer y cambiar lote_producto en la misma sentencia)
CREATE TEMPORARY TABLE semilla_lotes_distintos (id INT UNSIGNED PRIMARY KEY);
INSERT INTO semilla_lotes_distintos (id)
SELECT p.id FROM producto p
WHERE p.stock <> (SELECT COALESCE(SUM(l.stock), 0) FROM lote_producto l WHERE l.producto_id = p.id)
   -- o tiene stock en un lote con vencimiento y la semilla dice que no vence (o al revés)
   OR EXISTS (SELECT 1 FROM lote_producto l WHERE l.producto_id = p.id AND l.stock > 0
              AND (l.vencimiento IS NULL) <> (p.fecha_vencimiento IS NULL));

UPDATE lote_producto l JOIN semilla_lotes_distintos d ON d.id = l.producto_id SET l.stock = 0;

INSERT INTO lote_producto (producto_id, numero, codigo, vencimiento, stock, creado_en)
SELECT p.id, (SELECT COALESCE(MAX(l2.numero), 0) + 1 FROM lote_producto l2 WHERE l2.producto_id = p.id),
       NULL, p.fecha_vencimiento, 0, UTC_TIMESTAMP() - INTERVAL 3 HOUR
FROM producto p JOIN semilla_lotes_distintos d ON d.id = p.id
WHERE NOT EXISTS (SELECT 1 FROM lote_producto l WHERE l.producto_id = p.id AND l.vencimiento <=> p.fecha_vencimiento);

-- El lote con ese vencimiento que se creó primero recibe el stock.
UPDATE lote_producto l
JOIN producto p ON p.id = l.producto_id
JOIN semilla_lotes_distintos d ON d.id = p.id
JOIN (SELECT l2.producto_id, MIN(l2.id) AS id FROM lote_producto l2
      JOIN producto p2 ON p2.id = l2.producto_id
      WHERE l2.vencimiento <=> p2.fecha_vencimiento GROUP BY l2.producto_id) primero ON primero.id = l.id
SET l.stock = p.stock;

DROP TEMPORARY TABLE semilla_lotes_distintos;

-- 4. producto.stock y producto.fecha_vencimiento, de los lotes (como los deja Inventario).
UPDATE producto p SET
  p.stock = (SELECT COALESCE(SUM(l.stock), 0) FROM lote_producto l WHERE l.producto_id = p.id),
  p.fecha_vencimiento = (SELECT MIN(l.vencimiento) FROM lote_producto l WHERE l.producto_id = p.id AND l.stock > 0);

-- ---------- Insumos (lo mismo) ----------

-- 1.
INSERT INTO lote_insumo (insumo_id, numero, codigo, vencimiento, stock, creado_en)
SELECT i.id, 1, NULL, i.fecha_vencimiento, i.stock, UTC_TIMESTAMP() - INTERVAL 3 HOUR
FROM insumo i
WHERE NOT EXISTS (SELECT 1 FROM lote_insumo l WHERE l.insumo_id = i.id)
  AND (i.stock > 0 OR i.fecha_vencimiento IS NOT NULL OR NOT i.vence);

-- 2.
CREATE TEMPORARY TABLE semilla_lotes_distintos (id INT UNSIGNED PRIMARY KEY);
INSERT INTO semilla_lotes_distintos (id)
SELECT i.id FROM insumo i
WHERE i.stock <> (SELECT COALESCE(SUM(l.stock), 0) FROM lote_insumo l WHERE l.insumo_id = i.id)
   OR EXISTS (SELECT 1 FROM lote_insumo l WHERE l.insumo_id = i.id AND l.stock > 0
              AND (l.vencimiento IS NULL) <> (i.fecha_vencimiento IS NULL));

UPDATE lote_insumo l JOIN semilla_lotes_distintos d ON d.id = l.insumo_id SET l.stock = 0;

INSERT INTO lote_insumo (insumo_id, numero, codigo, vencimiento, stock, creado_en)
SELECT i.id, (SELECT COALESCE(MAX(l2.numero), 0) + 1 FROM lote_insumo l2 WHERE l2.insumo_id = i.id),
       NULL, i.fecha_vencimiento, 0, UTC_TIMESTAMP() - INTERVAL 3 HOUR
FROM insumo i JOIN semilla_lotes_distintos d ON d.id = i.id
WHERE NOT EXISTS (SELECT 1 FROM lote_insumo l WHERE l.insumo_id = i.id AND l.vencimiento <=> i.fecha_vencimiento);

UPDATE lote_insumo l
JOIN insumo i ON i.id = l.insumo_id
JOIN semilla_lotes_distintos d ON d.id = i.id
JOIN (SELECT l2.insumo_id, MIN(l2.id) AS id FROM lote_insumo l2
      JOIN insumo i2 ON i2.id = l2.insumo_id
      WHERE l2.vencimiento <=> i2.fecha_vencimiento GROUP BY l2.insumo_id) primero ON primero.id = l.id
SET l.stock = i.stock;

DROP TEMPORARY TABLE semilla_lotes_distintos;

-- 4.
UPDATE insumo i SET
  i.stock = (SELECT COALESCE(SUM(l.stock), 0) FROM lote_insumo l WHERE l.insumo_id = i.id),
  i.fecha_vencimiento = (SELECT MIN(l.vencimiento) FROM lote_insumo l WHERE l.insumo_id = i.id AND l.stock > 0);
