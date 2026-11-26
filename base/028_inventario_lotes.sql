-- Migración 028 · módulo Inventario: lotes de productos (26/11).
-- Un producto puede tener varios lotes, cada uno con su fecha de vencimiento y su stock. La
-- veterinaria carga stock en un lote que ya existe o crea uno nuevo.
--   - producto.stock pasa a ser la suma del stock de sus lotes (lo mantiene Inventario en la misma
--     transacción que cambia un lote). Así Pacientes y Reportes, que leen producto.stock, siguen igual.
--   - producto.fecha_vencimiento pasa a ser el vencimiento del lote con stock que vence primero
--     (también lo mantiene Inventario). Lo que se vende o no, lo deciden los lotes.
--   - Las ventas y las consultas sacan primero del lote que vence primero; una venta cancelada
--     devuelve cada unidad al lote del que salió (movimiento_inventario.lote_id).
--   - Una promoción es de un lote: el descuento vale para las unidades que le quedan a ese lote
--     (promocion.lote_id). Si se compran más, las demás van a precio normal: el ítem del carrito
--     guarda cuántas fueron con descuento y a qué precio (cantidad_promocion, precio_promocion).
-- Cada producto que ya existe queda con un lote con todo su stock y su vencimiento de hoy, y sus
-- movimientos y su promoción pasan a ese lote. No se borra nada.

CREATE TABLE lote_producto (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  producto_id  INT UNSIGNED NOT NULL,
  -- El número de lote del envase (opcional): "L-0425".
  codigo       VARCHAR(40)  NULL,
  -- NULL: no vence (accesorios, por ejemplo).
  vencimiento  DATE         NULL,
  stock        INT UNSIGNED NOT NULL DEFAULT 0,
  creado_en    DATETIME     NOT NULL,
  PRIMARY KEY (id),
  -- El orden en que se usan: el que vence primero.
  KEY ix_lote_producto_vencimiento (producto_id, vencimiento),
  CONSTRAINT fk_lote_producto FOREIGN KEY (producto_id) REFERENCES producto (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO lote_producto (producto_id, codigo, vencimiento, stock, creado_en)
SELECT id, NULL, fecha_vencimiento, stock, UTC_TIMESTAMP() - INTERVAL 3 HOUR FROM producto ORDER BY id;

-- De qué lote salió o entró cada unidad (NULL en los movimientos de insumos).
ALTER TABLE movimiento_inventario
  ADD COLUMN lote_id INT UNSIGNED NULL AFTER producto_id,
  ADD KEY ix_movimiento_lote (lote_id),
  ADD CONSTRAINT fk_movimiento_lote FOREIGN KEY (lote_id) REFERENCES lote_producto (id);

UPDATE movimiento_inventario m JOIN lote_producto l ON l.producto_id = m.producto_id
SET m.lote_id = l.id;

-- El lote de cada promoción (sigue habiendo a lo sumo una vigente por producto).
ALTER TABLE promocion
  ADD COLUMN lote_id INT UNSIGNED NULL AFTER producto_id,
  ADD CONSTRAINT fk_promocion_lote FOREIGN KEY (lote_id) REFERENCES lote_producto (id);

UPDATE promocion pr JOIN lote_producto l ON l.producto_id = pr.producto_id
SET pr.lote_id = l.id;

-- Cuántas unidades del ítem se cobraron con el descuento de la promoción y a qué precio. Las demás
-- (cantidad - cantidad_promocion) se cobraron a precio_unitario. Las compras de antes quedan con 0:
-- su precio_unitario ya es el que se cobró.
ALTER TABLE item_carrito
  ADD COLUMN cantidad_promocion INT UNSIGNED NOT NULL DEFAULT 0 AFTER precio_unitario,
  ADD COLUMN precio_promocion DECIMAL(10,2) NULL AFTER cantidad_promocion,
  ADD CONSTRAINT ck_item_carrito_promocion CHECK (cantidad_promocion <= cantidad);
