-- Migración 026 · módulo Pacientes
-- Un turno (y su consulta) puede tener más de un motivo (25/11): por ejemplo, la antirrábica, la
-- séxtuple y un control en la misma visita. Cada motivo es una fila de turno_motivo; los de
-- vacunación y desparasitación dicen además qué evento del calendario se da.
-- turno.motivo queda como el motivo principal (el chequeo de adopción si está entre los motivos; si no,
-- el primero): lo siguen leyendo Adopciones y Reportes.
-- Solo agrega: el código de antes sigue andando. La 027 borra turno.evento_sanitario_id (025).

CREATE TABLE turno_motivo (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  turno_id            INT UNSIGNED NOT NULL,
  motivo              ENUM('CONSULTA','VACUNACION','CHEQUEO_ADOPCION','DESPARASITACION','CASTRACION','CIRUGIA','CONTROL','URGENCIA') NOT NULL,
  -- Vacunación o desparasitación: el evento del calendario que se da. NULL en los demás motivos.
  evento_sanitario_id INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY ix_turno_motivo_turno (turno_id),
  KEY ix_turno_motivo_evento (evento_sanitario_id),
  CONSTRAINT fk_turno_motivo_turno  FOREIGN KEY (turno_id)            REFERENCES turno (id),
  CONSTRAINT fk_turno_motivo_evento FOREIGN KEY (evento_sanitario_id) REFERENCES evento_sanitario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Los turnos que ya existen: su único motivo (y, si lo tenían, el evento de la 025).
INSERT INTO turno_motivo (turno_id, motivo, evento_sanitario_id)
SELECT id, motivo, evento_sanitario_id FROM turno;
