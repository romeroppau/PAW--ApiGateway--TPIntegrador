-- Migración 029 · módulo Inventario: "vence", lotes numerados y lotes de insumos (26/11).
--   - producto.vence e insumo.vence: si el producto o el insumo tiene vencimiento. Si vence, cada lote
--     nuevo lleva su fecha de vencimiento; si no vence, ninguno la lleva (lo controla Inventario). Se
--     cambia solo con el stock en 0.
--   - Los lotes de cada producto y de cada insumo se numeran 1, 2, 3… (en la pantalla: L1, L2, L3…),
--     en el orden en que se crearon. lote_producto.codigo queda como el número de lote del
--     fabricante (opcional).
--   - Los insumos también tienen lotes (lote_insumo), igual que los productos: insumo.stock es la suma
--     de sus lotes e insumo.fecha_vencimiento, el del lote con stock que vence primero (los mantiene
--     Inventario). Las consultas usan primero el lote sin vencer que vence antes.
-- Lo que ya existe:
--   - Un producto vence si tiene fecha de vencimiento (en él o en alguno de sus lotes).
--   - Los insumos no tenían fecha: vencen las vacunas y los antiparasitarios (los que tienen
--     aplicación del calendario). La veterinaria cambia los demás desde el panel (con el stock en 0).
--   - Cada insumo queda con un lote L1 con todo su stock (sin vencimiento), y sus movimientos pasan a
--     ese lote. No se borra nada.

-- ---------- Productos ----------

ALTER TABLE producto
  ADD COLUMN vence BOOLEAN NOT NULL DEFAULT TRUE AFTER fecha_vencimiento;

UPDATE producto p
SET p.vence = (p.fecha_vencimiento IS NOT NULL
               OR EXISTS (SELECT 1 FROM lote_producto l WHERE l.producto_id = p.id AND l.vencimiento IS NOT NULL));

ALTER TABLE lote_producto
  ADD COLUMN numero INT UNSIGNED NULL AFTER producto_id,
  MODIFY COLUMN codigo VARCHAR(40) NULL COMMENT 'Número de lote del fabricante (opcional)';

UPDATE lote_producto l
JOIN (SELECT id, ROW_NUMBER() OVER (PARTITION BY producto_id ORDER BY id) AS n FROM lote_producto) orden
  ON orden.id = l.id
SET l.numero = orden.n;

-- NULL solo en un lote que cree el Inventario de antes de esta migración (entre que se migra y se
-- publica el Inventario nuevo, y en el CI de este cambio): el nuevo siempre pone el número.
ALTER TABLE lote_producto
  MODIFY COLUMN numero INT UNSIGNED NULL COMMENT 'L1, L2, L3… de cada producto',
  ADD UNIQUE KEY uq_lote_producto_numero (producto_id, numero);

-- ---------- Insumos ----------

ALTER TABLE insumo
  ADD COLUMN fecha_vencimiento DATE NULL AFTER stock,
  ADD COLUMN vence BOOLEAN NOT NULL DEFAULT TRUE AFTER fecha_vencimiento;

UPDATE insumo SET vence = (aplicacion IS NOT NULL);

CREATE TABLE lote_insumo (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  insumo_id    INT UNSIGNED NOT NULL,
  -- L1, L2, L3… de cada insumo.
  numero       INT UNSIGNED NOT NULL,
  -- El número de lote del fabricante (opcional).
  codigo       VARCHAR(40)  NULL,
  -- NULL: no vence.
  vencimiento  DATE         NULL,
  stock        INT UNSIGNED NOT NULL DEFAULT 0,
  creado_en    DATETIME     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_lote_insumo_numero (insumo_id, numero),
  -- El orden en que se usan: el que vence primero.
  KEY ix_lote_insumo_vencimiento (insumo_id, vencimiento),
  CONSTRAINT fk_lote_insumo FOREIGN KEY (insumo_id) REFERENCES insumo (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO lote_insumo (insumo_id, numero, codigo, vencimiento, stock, creado_en)
SELECT id, 1, NULL, NULL, stock, UTC_TIMESTAMP() - INTERVAL 3 HOUR FROM insumo ORDER BY id;

-- De qué lote salió o entró cada unidad de un insumo (NULL en los de productos, que usan lote_id).
ALTER TABLE movimiento_inventario
  ADD COLUMN lote_insumo_id INT UNSIGNED NULL AFTER insumo_id,
  ADD KEY ix_movimiento_lote_insumo (lote_insumo_id),
  ADD CONSTRAINT fk_movimiento_lote_insumo FOREIGN KEY (lote_insumo_id) REFERENCES lote_insumo (id);

UPDATE movimiento_inventario m JOIN lote_insumo l ON l.insumo_id = m.insumo_id
SET m.lote_insumo_id = l.id;
