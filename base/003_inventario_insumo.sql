-- Migración 003 · módulo Inventario
-- Crea la tabla insumo (DER): materiales internos que se usan en las consultas y no se venden.
-- Completa movimiento_inventario: insumo_id pasa a tener su clave foránea, y cada movimiento
-- es de un producto o de un insumo, nunca de los dos.

CREATE TABLE insumo (
  id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre  VARCHAR(120) NOT NULL,
  stock   INT UNSIGNED NOT NULL DEFAULT 0,
  costo   DECIMAL(10,2) NOT NULL,
  -- Lo marca el veterinario: si falta, y si ya lo pidió al proveedor.
  estado  ENUM('DISPONIBLE','EN_FALTA','YA_PEDIDO') NOT NULL DEFAULT 'DISPONIBLE',
  activo  BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id),
  KEY ix_insumo_listado (activo, nombre),
  CONSTRAINT ck_insumo_costo CHECK (costo >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE movimiento_inventario
  ADD CONSTRAINT fk_movimiento_insumo FOREIGN KEY (insumo_id) REFERENCES insumo (id);

-- Antes alcanzaba con uno de los dos (todavía no había insumos); el DER pide exactamente uno.
ALTER TABLE movimiento_inventario
  DROP CHECK ck_movimiento_destino;

ALTER TABLE movimiento_inventario
  ADD CONSTRAINT ck_movimiento_destino CHECK ((producto_id IS NULL) <> (insumo_id IS NULL));
