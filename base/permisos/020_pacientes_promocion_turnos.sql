-- Permisos sobre la tabla de la migración 020 (base/020_pacientes_promocion_turnos.sql).
-- promocion_franja: la escribe Pacientes. Sin DELETE: terminar una promoción completa terminada_en.
-- Las columnas nuevas de turno no cambian permisos: Pacientes ya actualiza la tabla.
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.promocion_franja TO 'pacientes'@'%';
