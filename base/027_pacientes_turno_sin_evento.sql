-- Migración 027 · módulo Pacientes
-- El evento del calendario de cada motivo está en turno_motivo (026): turno.evento_sanitario_id (025)
-- ya no se usa. Correrla después de desplegar el código de la 026.
ALTER TABLE turno
  DROP FOREIGN KEY fk_turno_evento,
  DROP KEY ix_turno_evento,
  DROP COLUMN evento_sanitario_id;
