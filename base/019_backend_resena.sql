-- Migración 019 · módulo Backend (reseñas)
-- Las reseñas de la veterinaria: las escriben los clientes y los rescatistas (estrellas y texto), se
-- publican enseguida y la veterinaria las puede responder (no borrar). Cada autor puede escribir
-- todas las que quiera y borrar las suyas. Las ve cualquiera en la página "Reseñas" y las 3 más
-- nuevas de 4 o 5 estrellas aparecen en la portada.
-- Sus permisos están en base/permisos/019_backend_resena.sql.
-- Decisiones:
--   - El nombre del autor no se copia: se lee de usuario (si lo cambia en "Mis datos", se actualiza).
--   - Una sola respuesta por reseña (respuesta, respondida_en, respondida_por); la veterinaria la
--     puede corregir. Si el autor borra la reseña, se borra con su respuesta.
--   - Al escribirse una reseña, Backend avisa a las veterinarias por la campana: suma el tipo RESENA
--     a notificacion (migración 008; COMPRA lo sumó la 011).

CREATE TABLE resena (
  id             INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  autor_id       INT UNSIGNED     NOT NULL,
  estrellas      TINYINT UNSIGNED NOT NULL,
  texto          VARCHAR(1000)    NOT NULL,
  creada_en      DATETIME         NOT NULL,
  respuesta      VARCHAR(1000)    NULL,
  respondida_en  DATETIME         NULL,
  respondida_por INT UNSIGNED     NULL,
  PRIMARY KEY (id),
  KEY ix_resena_creada (creada_en),
  KEY ix_resena_estrellas (estrellas, creada_en),
  CONSTRAINT fk_resena_autor FOREIGN KEY (autor_id) REFERENCES usuario (id),
  CONSTRAINT fk_resena_respondida_por FOREIGN KEY (respondida_por) REFERENCES usuario (id),
  CONSTRAINT ck_resena_estrellas CHECK (estrellas BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE notificacion
  MODIFY tipo ENUM('VACUNA','CONTROL_ADOPCION','STOCK_BAJO','PROMOCION','CUENTA','POSTULACION','COMPRA','RESENA') NOT NULL;
