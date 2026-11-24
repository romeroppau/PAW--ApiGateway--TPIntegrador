-- Migración 010 · módulo Inventario (tienda)
-- Crea las tablas de la compra para retirar: carrito, item_carrito, factura_compra y pago
-- (DER, Entrega 5), y suma el motivo VENTA_CANCELADA a los movimientos de inventario.
-- Las escribe Inventario. Sus permisos están en base/permisos/010_inventario_tienda.sql.

-- La compra en curso de un cliente.
CREATE TABLE carrito (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  cliente_id  INT UNSIGNED NOT NULL,
  estado      ENUM('ABIERTO','CONFIRMADO','PAGADO','RETIRADO','CANCELADO') NOT NULL DEFAULT 'ABIERTO',
  creado_en   DATETIME NOT NULL,
  -- 1 si el carrito está abierto, NULL si no. MySQL no compara los NULL en un índice único,
  -- así que un cliente solo puede tener un carrito ABIERTO a la vez (los cerrados no cuentan).
  abierto     TINYINT AS (IF(estado = 'ABIERTO', 1, NULL)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_carrito_abierto (cliente_id, abierto),
  CONSTRAINT fk_carrito_cliente FOREIGN KEY (cliente_id) REFERENCES usuario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cada producto del carrito, con el precio del momento en que se agregó.
CREATE TABLE item_carrito (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  carrito_id          INT UNSIGNED NOT NULL,
  producto_id         INT UNSIGNED NOT NULL,
  cantidad            INT UNSIGNED NOT NULL,
  precio_unitario     DECIMAL(10,2) NOT NULL,
  -- Huellitas no entra en la entrega final: queda en 0.
  huellitas_a_canjear INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  -- Un producto aparece una sola vez por carrito: agregarlo de nuevo suma la cantidad.
  UNIQUE KEY uq_item_carrito (carrito_id, producto_id),
  CONSTRAINT fk_item_carrito_carrito  FOREIGN KEY (carrito_id)  REFERENCES carrito (id),
  CONSTRAINT fk_item_carrito_producto FOREIGN KEY (producto_id) REFERENCES producto (id),
  CONSTRAINT ck_item_carrito_cantidad CHECK (cantidad > 0),
  CONSTRAINT ck_item_carrito_precio   CHECK (precio_unitario >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- La factura de la compra. Se crea al confirmar el carrito; su número empieza con V-
-- (las de consulta empiezan con C-).
CREATE TABLE factura_compra (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  numero         VARCHAR(20) NOT NULL,
  carrito_id     INT UNSIGNED NOT NULL,
  total          DECIMAL(10,2) NOT NULL,
  estado         ENUM('PENDIENTE_PAGO','PAGADA','ENTREGADA','CANCELADA') NOT NULL DEFAULT 'PENDIENTE_PAGO',
  fecha          DATETIME NOT NULL,
  entregada_en   DATETIME NULL,
  -- La veterinaria que constató el retiro en el local.
  entregada_por  INT UNSIGNED NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_factura_compra_numero (numero),
  -- Un carrito tiene una sola factura.
  UNIQUE KEY uq_factura_compra_carrito (carrito_id),
  CONSTRAINT fk_factura_compra_carrito FOREIGN KEY (carrito_id)    REFERENCES carrito (id),
  CONSTRAINT fk_factura_compra_entrega FOREIGN KEY (entregada_por) REFERENCES usuario (id),
  CONSTRAINT ck_factura_compra_total   CHECK (total >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cada pago de Mercado Pago. id_externo (el número de operación de Mercado Pago) es único:
-- un aviso de pago repetido no se registra dos veces.
CREATE TABLE pago (
  id                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  factura_compra_id  INT UNSIGNED NOT NULL,
  monto              DECIMAL(10,2) NOT NULL,
  id_externo         VARCHAR(64) NULL,
  estado             ENUM('PENDIENTE','APROBADO','RECHAZADO') NOT NULL DEFAULT 'PENDIENTE',
  fecha              DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_pago_externo (id_externo),
  CONSTRAINT fk_pago_factura FOREIGN KEY (factura_compra_id) REFERENCES factura_compra (id),
  CONSTRAINT ck_pago_monto   CHECK (monto >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- VENTA_CANCELADA: el stock que vuelve cuando se cancela una compra impaga o se rechaza el pago.
ALTER TABLE movimiento_inventario
  MODIFY motivo ENUM('CARGA_VETERINARIO','CONSULTA','VENTA','AJUSTE','VENTA_CANCELADA') NOT NULL;
