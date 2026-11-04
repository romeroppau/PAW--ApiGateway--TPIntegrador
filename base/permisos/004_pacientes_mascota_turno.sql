-- Permisos sobre las tablas de la migración 004 (base/004_pacientes_mascota_turno.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- mascota: la escribe Pacientes (la baja es lógica: UPDATE activo = 0, nunca DELETE).
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.mascota TO 'pacientes'@'%';

-- turno: lo escribe Pacientes. Un turno no se borra: se cancela o se marca ausente (UPDATE estado).
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.turno TO 'pacientes'@'%';
