-- Migración 020 · módulo Pacientes (turnos)
-- Promoción de las franjas con menos turnos: la veterinaria pone un descuento a la consulta de una
-- franja (un día de lunes a sábado, a la mañana o a la tarde) desde las sugerencias de Reportes
-- ("Qué promocionar" → Publicitar), igual que con los productos por vencer (migración 016).
-- Decisiones:
--   - La franja es la misma que usa el motor de Reportes: mañana = antes de las 13:00; tarde = desde
--     las 13:00. dia_semana: 1 = lunes ... 6 = sábado (el domingo no se atiende).
--   - El descuento es un porcentaje (5 a 90) y la promoción dura hasta el día "hasta" inclusive.
--   - Una franja tiene a lo sumo UNA promoción sin terminar (índice único sobre sin_terminar, el mismo
--     truco que la migración 016). No se borran: terminar una completa terminada_en.
--   - El turno guarda su precio AL SACARSE (también al reprogramarlo): precio_consulta es el precio
--     base de la configuración en ese momento, y descuento/promocion_franja_id, la promoción de su
--     franja si estaba vigente y el turno es hasta el día "hasta". Así, aunque después termine la
--     promoción o cambie el precio base, el turno conserva lo que se le prometió al cliente. La
--     consulta toma ese valor y no se edita. Los turnos de antes de esta migración no lo tienen
--     (precio_consulta NULL): su consulta toma el precio base del momento, sin descuento.

CREATE TABLE promocion_franja (
  id            INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  dia_semana    TINYINT UNSIGNED NOT NULL,
  franja        ENUM('MANIANA','TARDE') NOT NULL,
  porcentaje    TINYINT UNSIGNED NOT NULL,
  hasta         DATE             NOT NULL,
  creada_en     DATETIME         NOT NULL,
  creada_por    INT UNSIGNED     NOT NULL,
  terminada_en  DATETIME         NULL,
  sin_terminar  TINYINT          GENERATED ALWAYS AS (IF(terminada_en IS NULL, 1, NULL)) STORED,
  PRIMARY KEY (id),
  UNIQUE KEY ux_promocion_franja_una (dia_semana, franja, sin_terminar),
  KEY ix_promocion_franja_vigentes (terminada_en, hasta),
  CONSTRAINT ck_promocion_franja_dia        CHECK (dia_semana BETWEEN 1 AND 6),
  CONSTRAINT ck_promocion_franja_porcentaje CHECK (porcentaje BETWEEN 5 AND 90),
  CONSTRAINT fk_promocion_franja_usuario FOREIGN KEY (creada_por) REFERENCES usuario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE turno
  ADD COLUMN precio_consulta     DECIMAL(10,2)    NULL AFTER estado,
  ADD COLUMN descuento           TINYINT UNSIGNED NULL AFTER precio_consulta,
  ADD COLUMN promocion_franja_id INT UNSIGNED     NULL AFTER descuento,
  ADD CONSTRAINT fk_turno_promocion_franja FOREIGN KEY (promocion_franja_id) REFERENCES promocion_franja (id),
  ADD CONSTRAINT ck_turno_descuento CHECK (descuento IS NULL OR descuento BETWEEN 5 AND 90);
