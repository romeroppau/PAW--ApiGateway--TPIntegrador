-- Migración 006 · módulo Pacientes
-- Crea las tablas de la consulta (DER): consulta, item_insumo_consulta, item_producto_consulta
-- y factura_consulta. Agrega la clave foránea pendiente de evento_sanitario.consulta_id.
-- Diferencias con el DER: diagnostico admite NULL mientras la consulta está ABIERTA (se carga
-- durante la atención), y cada insumo o producto aparece una sola vez por consulta (se suma la
-- cantidad, igual que en item_carrito).

CREATE TABLE consulta (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- Un turno genera cero o una consulta.
  turno_id       INT UNSIGNED NOT NULL,
  diagnostico    TEXT NULL,
  observaciones  TEXT NULL,
  valor_base     DECIMAL(10,2) NOT NULL,
  estado         ENUM('ABIERTA','FINALIZADA') NOT NULL DEFAULT 'ABIERTA',
  finalizada_en  DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_consulta_turno (turno_id),
  CONSTRAINT fk_consulta_turno FOREIGN KEY (turno_id) REFERENCES turno (id),
  CONSTRAINT ck_consulta_valor_base CHECK (valor_base >= 0),
  -- Una consulta finalizada tiene diagnóstico y fecha de finalización.
  CONSTRAINT ck_consulta_finalizada CHECK (
    estado = 'ABIERTA' OR (diagnostico IS NOT NULL AND finalizada_en IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insumos usados en la consulta, con el costo de ese momento.
CREATE TABLE item_insumo_consulta (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  consulta_id    INT UNSIGNED NOT NULL,
  insumo_id      INT UNSIGNED NOT NULL,
  cantidad       INT UNSIGNED NOT NULL,
  costo_unitario DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_item_insumo (consulta_id, insumo_id),
  CONSTRAINT fk_item_insumo_consulta FOREIGN KEY (consulta_id) REFERENCES consulta (id),
  CONSTRAINT fk_item_insumo_insumo   FOREIGN KEY (insumo_id)   REFERENCES insumo (id),
  CONSTRAINT ck_item_insumo_cantidad CHECK (cantidad > 0),
  CONSTRAINT ck_item_insumo_costo    CHECK (costo_unitario >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Productos vendidos durante la consulta, con el precio de ese momento.
CREATE TABLE item_producto_consulta (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  consulta_id     INT UNSIGNED NOT NULL,
  producto_id     INT UNSIGNED NOT NULL,
  cantidad        INT UNSIGNED NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_item_producto (consulta_id, producto_id),
  CONSTRAINT fk_item_producto_consulta FOREIGN KEY (consulta_id) REFERENCES consulta (id),
  CONSTRAINT fk_item_producto_producto FOREIGN KEY (producto_id) REFERENCES producto (id),
  CONSTRAINT ck_item_producto_cantidad CHECK (cantidad > 0),
  CONSTRAINT ck_item_producto_precio   CHECK (precio_unitario >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- La factura que se genera al finalizar la consulta. El número empieza con C- (V- es la de la tienda).
CREATE TABLE factura_consulta (
  id                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  numero             VARCHAR(20) NOT NULL,
  consulta_id        INT UNSIGNED NOT NULL,
  subtotal_base      DECIMAL(10,2) NOT NULL,
  subtotal_insumos   DECIMAL(10,2) NOT NULL,
  subtotal_productos DECIMAL(10,2) NOT NULL,
  total              DECIMAL(10,2) NOT NULL,
  -- Si la consulta base se canjeó con Huellitas (Entrega 5). Por ahora siempre NULL.
  huellitas_usadas   INT UNSIGNED NULL,
  estado             ENUM('PENDIENTE_PAGO','PAGADA') NOT NULL DEFAULT 'PENDIENTE_PAGO',
  fecha              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_factura_consulta_numero (numero),
  -- Una consulta tiene una sola factura: un doble clic en "Finalizar" no la duplica.
  UNIQUE KEY uq_factura_consulta_consulta (consulta_id),
  CONSTRAINT fk_factura_consulta FOREIGN KEY (consulta_id) REFERENCES consulta (id),
  CONSTRAINT ck_factura_numero CHECK (numero LIKE 'C-%'),
  CONSTRAINT ck_factura_montos CHECK (
    subtotal_base >= 0 AND subtotal_insumos >= 0 AND subtotal_productos >= 0 AND total >= 0
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE evento_sanitario
  ADD CONSTRAINT fk_evento_consulta FOREIGN KEY (consulta_id) REFERENCES consulta (id);
