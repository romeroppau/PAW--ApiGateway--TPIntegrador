-- Migración 025 · módulos Pacientes e Inventario
-- El calendario sanitario manda en los turnos de vacunación y desparasitación (25/11):
--   * Cada ítem del plan dice qué se aplica (aplicacion) y qué dosis es dentro de esa vacuna (orden):
--     la 3.ª séxtuple no se da si en el calendario hay una dosis anterior sin dar.
--   * Vacunas opcionales (automatico = 0): no se cargan solas al crear la mascota; el veterinario las
--     agrega al calendario si las va a dar (tos de las perreras, leucemia felina).
--   * El turno de vacunación o desparasitación queda atado al evento del calendario que se va a dar,
--     y hay más motivos (desparasitación, castración, cirugía, control, urgencia).
--   * Cada insumo puede decir qué aplicación del calendario es; la consulta de una vacuna tiene que
--     llevar ese insumo. Los insumos que falten se crean con stock 0 (el stock se carga desde la
--     consulta o desde Insumos).

-- ---------- plan_sanitario ----------

ALTER TABLE plan_sanitario
  ADD COLUMN aplicacion ENUM('SEXTUPLE','TRIPLE_FELINA','ANTIRRABICA','TOS_PERRERAS','LEUCEMIA_FELINA','ANTIPARASITARIO') NULL AFTER nombre,
  -- La dosis dentro de su aplicación: 1.ª, 2.ª, 3.ª, refuerzo.
  ADD COLUMN orden SMALLINT UNSIGNED NOT NULL DEFAULT 1 AFTER aplicacion,
  -- 1: se agrega solo al calendario de la mascota (generarPara); 0: lo agrega el veterinario.
  ADD COLUMN automatico BOOLEAN NOT NULL DEFAULT TRUE AFTER repetir_cada_meses;

UPDATE plan_sanitario SET aplicacion = 'ANTIPARASITARIO', orden = 1 WHERE id IN (1, 7, 12);
UPDATE plan_sanitario SET aplicacion = 'SEXTUPLE',        orden = 1 WHERE id = 2;
UPDATE plan_sanitario SET aplicacion = 'SEXTUPLE',        orden = 2 WHERE id = 3;
UPDATE plan_sanitario SET aplicacion = 'SEXTUPLE',        orden = 3 WHERE id = 4;
UPDATE plan_sanitario SET aplicacion = 'SEXTUPLE',        orden = 4 WHERE id = 6;
UPDATE plan_sanitario SET aplicacion = 'ANTIRRABICA',     orden = 1 WHERE id IN (5, 10);
UPDATE plan_sanitario SET aplicacion = 'TRIPLE_FELINA',   orden = 1 WHERE id = 8;
UPDATE plan_sanitario SET aplicacion = 'TRIPLE_FELINA',   orden = 2 WHERE id = 9;
UPDATE plan_sanitario SET aplicacion = 'TRIPLE_FELINA',   orden = 3 WHERE id = 11;

INSERT INTO plan_sanitario
  (id, especie, tipo, nombre, aplicacion, orden, edad_inicio_semanas, repetir_cada_meses, automatico)
VALUES
  (13, 'PERRO', 'VACUNA', 'Tos de las perreras',               'TOS_PERRERAS',    1,  8,   12, 0),
  (14, 'GATO',  'VACUNA', 'Leucemia felina (1.ª dosis)',       'LEUCEMIA_FELINA', 1,  8, NULL, 0),
  (15, 'GATO',  'VACUNA', 'Leucemia felina (2.ª dosis)',       'LEUCEMIA_FELINA', 2, 12, NULL, 0),
  (16, 'GATO',  'VACUNA', 'Leucemia felina (refuerzo anual)',  'LEUCEMIA_FELINA', 3, 52,   12, 0);

ALTER TABLE plan_sanitario MODIFY aplicacion ENUM('SEXTUPLE','TRIPLE_FELINA','ANTIRRABICA','TOS_PERRERAS','LEUCEMIA_FELINA','ANTIPARASITARIO') NOT NULL;

-- ---------- turno ----------

ALTER TABLE turno
  MODIFY motivo ENUM('CONSULTA','VACUNACION','CHEQUEO_ADOPCION','DESPARASITACION','CASTRACION','CIRUGIA','CONTROL','URGENCIA') NOT NULL,
  -- Vacunación o desparasitación: el evento del calendario que se da en este turno.
  -- NULL en los demás motivos (y en los turnos de vacunación de antes de esta migración).
  ADD COLUMN evento_sanitario_id INT UNSIGNED NULL AFTER motivo,
  ADD KEY ix_turno_evento (evento_sanitario_id),
  ADD CONSTRAINT fk_turno_evento FOREIGN KEY (evento_sanitario_id) REFERENCES evento_sanitario (id);

-- ---------- insumo ----------

ALTER TABLE insumo
  -- Qué aplicación del calendario es este insumo (NULL: no es una vacuna ni un antiparasitario).
  ADD COLUMN aplicacion ENUM('SEXTUPLE','TRIPLE_FELINA','ANTIRRABICA','TOS_PERRERAS','LEUCEMIA_FELINA','ANTIPARASITARIO') NULL AFTER nombre;

-- Los insumos que ya existen, por su nombre (la intercalación no distingue tildes ni mayúsculas).
UPDATE insumo SET aplicacion = 'SEXTUPLE'        WHERE aplicacion IS NULL AND nombre LIKE '%sextuple%';
UPDATE insumo SET aplicacion = 'TRIPLE_FELINA'   WHERE aplicacion IS NULL AND nombre LIKE '%triple felina%';
UPDATE insumo SET aplicacion = 'ANTIRRABICA'     WHERE aplicacion IS NULL AND nombre LIKE '%antirrabica%';
UPDATE insumo SET aplicacion = 'TOS_PERRERAS'    WHERE aplicacion IS NULL AND nombre LIKE '%tos de las perreras%';
UPDATE insumo SET aplicacion = 'LEUCEMIA_FELINA' WHERE aplicacion IS NULL AND nombre LIKE '%leucemia felina%';
UPDATE insumo SET aplicacion = 'ANTIPARASITARIO' WHERE aplicacion IS NULL AND nombre LIKE '%antiparasitario%';

-- Los que falten, con stock 0 (EN_FALTA): así cada vacuna del calendario tiene su insumo.
INSERT INTO insumo (nombre, aplicacion, stock, costo, estado, activo)
SELECT n.nombre, n.aplicacion, 0, n.costo, 'EN_FALTA', 1
FROM (
            SELECT 'Vacuna séxtuple canina (dosis)'     AS nombre, 'SEXTUPLE'        AS aplicacion, 7200.00 AS costo
  UNION ALL SELECT 'Vacuna triple felina (dosis)',                 'TRIPLE_FELINA',                 8100.00
  UNION ALL SELECT 'Vacuna antirrábica (dosis)',                   'ANTIRRABICA',                   4300.00
  UNION ALL SELECT 'Vacuna tos de las perreras (dosis)',           'TOS_PERRERAS',                  9400.00
  UNION ALL SELECT 'Vacuna leucemia felina (dosis)',               'LEUCEMIA_FELINA',               9800.00
  UNION ALL SELECT 'Antiparasitario interno (dosis)',              'ANTIPARASITARIO',               2500.00
) n
WHERE NOT EXISTS (SELECT 1 FROM insumo i WHERE i.aplicacion = n.aplicacion);
