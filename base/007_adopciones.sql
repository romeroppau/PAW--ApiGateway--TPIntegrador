-- Migración 007 · módulo Adopciones
-- Crea las tablas publicacion, adopcion y postulacion (DER, Entrega 5). El usuario de MySQL
-- adopciones lo crea migrar.php, y sus permisos están en base/permisos/007_adopciones.sql.
-- Diferencias con el DER:
--   - publicacion suma creada_en (para ordenar los listados y la cola de moderación).
--   - publicacion tiene la columna calculada "vigente": una mascota no puede tener dos
--     publicaciones abiertas a la vez (las dadas de baja y las rechazadas no cuentan).
--   - adopcion.turno_chequeo_id es único: un turno de chequeo es de una sola adopción.

-- El aviso que carga el rescatista. Pasa por la moderación de la veterinaria.
CREATE TABLE publicacion (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  rescatista_id     INT UNSIGNED NOT NULL,
  mascota_id        INT UNSIGNED NOT NULL,
  titulo            VARCHAR(120) NOT NULL,
  descripcion       TEXT NOT NULL,
  foto              MEDIUMBLOB NOT NULL,
  foto_tipo         VARCHAR(20) NOT NULL,
  estado_moderacion ENUM('PENDIENTE','APROBADA','RECHAZADA') NOT NULL DEFAULT 'PENDIENTE',
  motivo_rechazo    VARCHAR(255) NULL,
  activa            BOOLEAN NOT NULL DEFAULT TRUE,
  creada_en         DATETIME NOT NULL,
  -- Se calcula sola: 1 si la publicación está abierta (activa y no rechazada), NULL si no.
  -- Igual que turno.ocupa_horario: MySQL no compara los NULL en un índice único.
  vigente           TINYINT AS (IF(activa = 1 AND estado_moderacion <> 'RECHAZADA', 1, NULL)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_publicacion_mascota_vigente (mascota_id, vigente),
  KEY ix_publicacion_rescatista (rescatista_id, activa),
  KEY ix_publicacion_moderacion (estado_moderacion, activa),
  CONSTRAINT fk_publicacion_rescatista FOREIGN KEY (rescatista_id) REFERENCES usuario (id),
  CONSTRAINT fk_publicacion_mascota    FOREIGN KEY (mascota_id)    REFERENCES mascota (id),
  -- El motivo va solo (y siempre) en las rechazadas.
  CONSTRAINT ck_publicacion_motivo CHECK (
    (estado_moderacion = 'RECHAZADA' AND motivo_rechazo IS NOT NULL)
    OR (estado_moderacion <> 'RECHAZADA' AND motivo_rechazo IS NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- El proceso de adopción. Se crea cuando la veterinaria aprueba la publicación.
-- PUBLICADA → CON_POSTULANTES → ADOPTANTE_ELEGIDO → CHEQUEO_PENDIENTE → FINALIZADA
-- (o CANCELADA en cualquier momento antes de FINALIZADA).
CREATE TABLE adopcion (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  publicacion_id   INT UNSIGNED NOT NULL,
  estado           ENUM('PUBLICADA','CON_POSTULANTES','ADOPTANTE_ELEGIDO','CHEQUEO_PENDIENTE','FINALIZADA','CANCELADA')
                   NOT NULL DEFAULT 'PUBLICADA',
  adoptante_id     INT UNSIGNED NULL,
  turno_chequeo_id INT UNSIGNED NULL,
  fecha_inicio     DATETIME NOT NULL,
  -- Cuándo terminó (FINALIZADA o CANCELADA). El motor la usa para los controles de los 30 y 90 días.
  fecha_fin        DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_adopcion_publicacion (publicacion_id),
  UNIQUE KEY uq_adopcion_turno_chequeo (turno_chequeo_id),
  KEY ix_adopcion_estado (estado, fecha_fin),
  KEY ix_adopcion_adoptante (adoptante_id),
  CONSTRAINT fk_adopcion_publicacion   FOREIGN KEY (publicacion_id)   REFERENCES publicacion (id),
  CONSTRAINT fk_adopcion_adoptante     FOREIGN KEY (adoptante_id)     REFERENCES usuario (id),
  CONSTRAINT fk_adopcion_turno_chequeo FOREIGN KEY (turno_chequeo_id) REFERENCES turno (id),
  -- Desde que se elige al adoptante, tiene que estar cargado.
  CONSTRAINT ck_adopcion_adoptante CHECK (
    estado NOT IN ('ADOPTANTE_ELEGIDO','CHEQUEO_PENDIENTE','FINALIZADA') OR adoptante_id IS NOT NULL
  ),
  -- El turno de chequeo existe desde CHEQUEO_PENDIENTE.
  CONSTRAINT ck_adopcion_chequeo CHECK (
    estado NOT IN ('CHEQUEO_PENDIENTE','FINALIZADA') OR turno_chequeo_id IS NOT NULL
  ),
  CONSTRAINT ck_adopcion_fin CHECK (
    (estado IN ('FINALIZADA','CANCELADA')) = (fecha_fin IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- El formulario de cada cliente interesado.
CREATE TABLE postulacion (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  adopcion_id       INT UNSIGNED NOT NULL,
  cliente_id        INT UNSIGNED NOT NULL,
  tipo_vivienda     VARCHAR(60)  NOT NULL,
  otras_mascotas    VARCHAR(255) NOT NULL,
  tiempo_disponible VARCHAR(120) NOT NULL,
  estado            ENUM('PENDIENTE','ELEGIDA','RECHAZADA') NOT NULL DEFAULT 'PENDIENTE',
  fecha             DATETIME NOT NULL,
  PRIMARY KEY (id),
  -- Un cliente se postula una sola vez por adopción.
  UNIQUE KEY uq_postulacion_adopcion_cliente (adopcion_id, cliente_id),
  KEY ix_postulacion_cliente (cliente_id, fecha),
  CONSTRAINT fk_postulacion_adopcion FOREIGN KEY (adopcion_id) REFERENCES adopcion (id),
  CONSTRAINT fk_postulacion_cliente  FOREIGN KEY (cliente_id)  REFERENCES usuario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
