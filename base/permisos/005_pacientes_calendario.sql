-- Permisos sobre las tablas de la migración 005 (base/005_pacientes_calendario.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- plan_sanitario: es un catálogo fijo que se carga en la migración; Pacientes solo lo lee.
GRANT SELECT ON {{DB_NAME}}.plan_sanitario TO 'pacientes'@'%';

-- evento_sanitario: lo escribe Pacientes (generarPara crea los eventos, marcarAplicado los completa).
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.evento_sanitario TO 'pacientes'@'%';
