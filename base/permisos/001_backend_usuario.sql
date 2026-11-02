-- Permisos sobre las tablas de la migración 001 (base/001_backend_usuario.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.
--
-- Cada migración tiene acá su archivo de permisos con el mismo nombre. migrar.php los corre todos
-- cada vez, después de crear los usuarios de MySQL de los módulos: repetir un GRANT no rompe nada.

-- usuario: lo escribe Backend; Inventario y Pacientes solo lo leen
-- (Inventario muestra quién registró cada movimiento; Pacientes, el dueño de cada mascota).
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.usuario TO 'backend'@'%';
GRANT SELECT                 ON {{DB_NAME}}.usuario TO 'inventario'@'%';
GRANT SELECT                 ON {{DB_NAME}}.usuario TO 'pacientes'@'%';
