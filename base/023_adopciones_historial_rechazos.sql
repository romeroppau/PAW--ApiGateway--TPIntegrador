-- Migración 023 · módulo Adopciones
-- Historial de los rechazos de publicaciones. publicacion.motivo_rechazo guarda solo el último y se
-- borra cuando el rescatista la corrige (vuelve a PENDIENTE); acá queda cada rechazo para siempre,
-- con su motivo, la fecha y hora (de Argentina) y la veterinaria que lo hizo. No se borran ni se editan.
CREATE TABLE publicacion_rechazo (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  publicacion_id INT UNSIGNED NOT NULL,
  motivo         VARCHAR(255) NOT NULL,
  rechazada_en   DATETIME     NOT NULL,
  -- NULL solo en los rechazos de antes de esta migración (no se sabía quién).
  rechazada_por  INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY ix_publicacion_rechazo_publicacion (publicacion_id, rechazada_en),
  KEY ix_publicacion_rechazo_fecha (rechazada_en),
  CONSTRAINT fk_publicacion_rechazo_publicacion FOREIGN KEY (publicacion_id) REFERENCES publicacion (id),
  CONSTRAINT fk_publicacion_rechazo_veterinaria FOREIGN KEY (rechazada_por) REFERENCES usuario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Las que ya estaban rechazadas pasan al historial. No se guardaba cuándo se rechazaron: va la fecha
-- en que se publicaron.
INSERT INTO publicacion_rechazo (publicacion_id, motivo, rechazada_en, rechazada_por)
SELECT id, motivo_rechazo, creada_en, NULL
FROM publicacion
WHERE estado_moderacion = 'RECHAZADA' AND motivo_rechazo IS NOT NULL;
