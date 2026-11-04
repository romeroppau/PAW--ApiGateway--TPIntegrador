-- Migración 004 · módulo Pacientes
-- Crea las tablas mascota y turno (DER, Entrega 4).
-- Diferencias con el DER: mascota suma foto_tipo (igual que producto.imagen_tipo), y en turno
-- un turno cancelado libera su horario (columna ocupa_horario).

CREATE TABLE mascota (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  duenio_id        INT UNSIGNED NOT NULL,
  nombre           VARCHAR(80)  NOT NULL,
  especie          ENUM('PERRO','GATO','OTRO') NOT NULL,
  raza             VARCHAR(80)  NULL,
  fecha_nacimiento DATE NULL,
  peso_kg          DECIMAL(5,2) NULL,
  foto             MEDIUMBLOB NULL,
  foto_tipo        VARCHAR(20) NULL,
  activo           BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id),
  KEY ix_mascota_duenio (duenio_id, activo),
  -- El dueño es un cliente o un rescatista (tabla usuario, de Backend).
  CONSTRAINT fk_mascota_duenio FOREIGN KEY (duenio_id) REFERENCES usuario (id),
  CONSTRAINT ck_mascota_peso CHECK (peso_kg IS NULL OR peso_kg > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE turno (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  mascota_id     INT UNSIGNED NOT NULL,
  veterinario_id INT UNSIGNED NOT NULL,
  fecha          DATE NOT NULL,
  hora           TIME NOT NULL,
  motivo         ENUM('CONSULTA','VACUNACION','CHEQUEO_ADOPCION') NOT NULL,
  estado         ENUM('PROGRAMADO','EN_ATENCION','ATENDIDO','CANCELADO','AUSENTE') NOT NULL DEFAULT 'PROGRAMADO',
  -- Se calcula sola: 1 si el turno ocupa su horario, NULL si está cancelado.
  ocupa_horario  TINYINT AS (IF(estado = 'CANCELADO', NULL, 1)) VIRTUAL,
  PRIMARY KEY (id),
  -- Un veterinario no tiene dos turnos a la misma hora. Los cancelados no cuentan: MySQL no compara
  -- los NULL en un índice único, así que un turno cancelado libera su horario para otro.
  UNIQUE KEY uq_turno_veterinario_horario (veterinario_id, fecha, hora, ocupa_horario),
  KEY ix_turno_agenda (fecha, hora),
  KEY ix_turno_mascota (mascota_id, fecha),
  CONSTRAINT fk_turno_mascota     FOREIGN KEY (mascota_id)     REFERENCES mascota (id),
  CONSTRAINT fk_turno_veterinario FOREIGN KEY (veterinario_id) REFERENCES usuario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
