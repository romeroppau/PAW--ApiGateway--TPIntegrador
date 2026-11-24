-- Migración 016 · módulo Inventario (tienda)
-- Promociones: la veterinaria pone un descuento a un producto ("Publicitar", desde las sugerencias de
-- Reportes) y el producto aparece en la sección de promociones de la tienda con el precio rebajado.
-- - El descuento es un porcentaje (5 a 90) y dura hasta el día "hasta" inclusive.
-- - Una promoción está VIGENTE si no se terminó (terminada_en IS NULL) y "hasta" es hoy o después.
-- - Un producto tiene a lo sumo UNA promoción sin terminar: lo asegura la base con el índice único
--   sobre (producto_id, sin_terminar). sin_terminar vale 1 si no se terminó y NULL si se terminó, y
--   un índice único admite muchos NULL (el mismo truco que el carrito "abierto" de la migración 010).
-- - Las promociones no se borran: al terminarlas (o al publicar otra cuando la anterior ya pasó su
--   fecha) se completa terminada_en, así queda el historial.
-- El precio con descuento NO se guarda acá: se calcula con el precio del producto de ese momento.
-- La compra guarda el precio que se cobró (item_carrito.precio_unitario).

CREATE TABLE promocion (
  id            INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  producto_id   INT UNSIGNED     NOT NULL,
  porcentaje    TINYINT UNSIGNED NOT NULL,
  hasta         DATE             NOT NULL,
  creada_en     DATETIME         NOT NULL,
  creada_por    INT UNSIGNED     NOT NULL,
  terminada_en  DATETIME         NULL,
  sin_terminar  TINYINT          GENERATED ALWAYS AS (IF(terminada_en IS NULL, 1, NULL)) STORED,
  PRIMARY KEY (id),
  UNIQUE KEY ux_promocion_una_por_producto (producto_id, sin_terminar),
  KEY ix_promocion_vigentes (terminada_en, hasta),
  CONSTRAINT ck_promocion_porcentaje CHECK (porcentaje BETWEEN 5 AND 90),
  CONSTRAINT fk_promocion_producto FOREIGN KEY (producto_id) REFERENCES producto (id),
  CONSTRAINT fk_promocion_usuario  FOREIGN KEY (creada_por)  REFERENCES usuario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
