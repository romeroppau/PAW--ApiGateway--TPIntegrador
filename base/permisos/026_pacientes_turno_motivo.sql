-- Permisos de la migración 026 (base/026_pacientes_turno_motivo.sql).

-- turno_motivo: lo escribe Pacientes al cargar el turno; quitar un evento del calendario suelta los
-- motivos de los turnos cancelados (UPDATE). Reportes lo lee.
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.turno_motivo TO 'pacientes'@'%';
GRANT SELECT ON {{DB_NAME}}.turno_motivo TO 'reportes'@'%';
