-- Migración 002 · módulo Inventario
-- Crea las tablas producto y movimiento_inventario (DER, Entrega 3).
-- La tabla insumo queda para cuando existan las consultas (módulo Pacientes):
-- por eso insumo_id todavía no tiene clave foránea.

CREATE TABLE producto (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre            VARCHAR(120) NOT NULL,
  descripcion       TEXT NULL,
  precio            DECIMAL(10,2) NOT NULL,
  huellitas         INT UNSIGNED NULL,
  stock             INT UNSIGNED NOT NULL DEFAULT 0,
  categoria         ENUM('MEDICAMENTO','ALIMENTO','ACCESORIO') NOT NULL,
  especie_destino   ENUM('PERRO','GATO','TODAS') NOT NULL,
  etapa_vida        ENUM('CACHORRO','ADULTO','SENIOR','TODAS') NOT NULL DEFAULT 'TODAS',
  peso_kg           DECIMAL(6,2) NULL,
  fecha_vencimiento DATE NULL,
  imagen            MEDIUMBLOB NULL,
  imagen_tipo       VARCHAR(20) NULL,
  activo            BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id),
  KEY ix_producto_catalogo (activo, categoria, especie_destino, nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE movimiento_inventario (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  producto_id   INT UNSIGNED NULL,
  insumo_id     INT UNSIGNED NULL,
  tipo          ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
  cantidad      INT UNSIGNED NOT NULL,
  motivo        ENUM('CARGA_VETERINARIO','CONSULTA','VENTA','AJUSTE') NOT NULL,
  usuario_id    INT UNSIGNED NULL,
  id_operacion  CHAR(36) NULL,
  fecha         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_movimiento_operacion (id_operacion),
  KEY ix_movimiento_producto (producto_id, fecha),
  CONSTRAINT fk_movimiento_producto FOREIGN KEY (producto_id) REFERENCES producto (id),
  CONSTRAINT fk_movimiento_usuario  FOREIGN KEY (usuario_id)  REFERENCES usuario (id),
  -- Cada movimiento es de un producto o de un insumo, nunca de ninguno.
  CONSTRAINT ck_movimiento_destino CHECK (producto_id IS NOT NULL OR insumo_id IS NOT NULL),
  CONSTRAINT ck_movimiento_cantidad CHECK (cantidad > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
