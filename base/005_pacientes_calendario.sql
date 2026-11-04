-- Migración 005 · módulo Pacientes
-- Crea las tablas plan_sanitario y evento_sanitario (DER): el calendario sanitario de cada mascota.
-- El plan base va acá y no en las semillas: es un catálogo fijo que también necesita producción.
-- evento_sanitario.consulta_id todavía no tiene clave foránea: la agrega la migración 006,
-- que es la que crea la tabla consulta.

CREATE TABLE plan_sanitario (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  especie             ENUM('PERRO','GATO','OTRO') NOT NULL,
  tipo                ENUM('VACUNA','DESPARASITACION') NOT NULL,
  nombre              VARCHAR(100) NOT NULL,
  -- A qué edad se da la primera vez.
  edad_inicio_semanas SMALLINT UNSIGNED NOT NULL,
  -- Cada cuántos meses se repite; NULL si se da una sola vez.
  repetir_cada_meses  SMALLINT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY ix_plan_especie (especie, edad_inicio_semanas),
  CONSTRAINT ck_plan_repeticion CHECK (repetir_cada_meses IS NULL OR repetir_cada_meses > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Plan base orientativo, a confirmar con la veterinaria.
INSERT INTO plan_sanitario
  (id, especie, tipo, nombre, edad_inicio_semanas, repetir_cada_meses)
VALUES
  (1,  'PERRO', 'DESPARASITACION', 'Desparasitación interna',         2,    3),
  (2,  'PERRO', 'VACUNA',          'Séxtuple (1.ª dosis)',             6, NULL),
  (3,  'PERRO', 'VACUNA',          'Séxtuple (2.ª dosis)',             9, NULL),
  (4,  'PERRO', 'VACUNA',          'Séxtuple (3.ª dosis)',            12, NULL),
  (5,  'PERRO', 'VACUNA',          'Antirrábica',                     16,   12),
  (6,  'PERRO', 'VACUNA',          'Séxtuple (refuerzo anual)',       52,   12),
  (7,  'GATO',  'DESPARASITACION', 'Desparasitación interna',         2,    3),
  (8,  'GATO',  'VACUNA',          'Triple felina (1.ª dosis)',        8, NULL),
  (9,  'GATO',  'VACUNA',          'Triple felina (2.ª dosis)',       12, NULL),
  (10, 'GATO',  'VACUNA',          'Antirrábica',                     16,   12),
  (11, 'GATO',  'VACUNA',          'Triple felina (refuerzo anual)',  52,   12),
  (12, 'OTRO',  'DESPARASITACION', 'Desparasitación interna',         8,    6);

CREATE TABLE evento_sanitario (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  mascota_id        INT UNSIGNED NOT NULL,
  -- NULL si el veterinario lo agrega a mano, fuera del plan.
  plan_sanitario_id INT UNSIGNED NULL,
  tipo              ENUM('VACUNA','DESPARASITACION') NOT NULL,
  nombre            VARCHAR(100) NOT NULL,
  fecha_programada  DATE NOT NULL,
  fecha_aplicada    DATE NULL,
  -- La consulta en la que se aplicó (CalendarioSanitario::marcarAplicado).
  consulta_id       INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY ix_evento_mascota (mascota_id, fecha_programada),
  KEY ix_evento_consulta (consulta_id),
  CONSTRAINT fk_evento_mascota FOREIGN KEY (mascota_id)        REFERENCES mascota (id),
  CONSTRAINT fk_evento_plan    FOREIGN KEY (plan_sanitario_id) REFERENCES plan_sanitario (id),
  -- Si se aplicó en una consulta, tiene fecha de aplicación.
  CONSTRAINT ck_evento_aplicado CHECK (consulta_id IS NULL OR fecha_aplicada IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
