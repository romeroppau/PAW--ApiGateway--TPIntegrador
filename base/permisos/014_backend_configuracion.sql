-- Permisos sobre la tabla de la migración 014 (base/014_backend_configuracion.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- configuracion: la escribe Backend. DELETE porque "volver al valor por defecto" borra la fila.
GRANT SELECT, INSERT, UPDATE, DELETE ON {{DB_NAME}}.configuracion TO 'backend'@'%';

-- Los módulos que usan algún parámetro solo la leen (comun/configuracion.php):
-- Pacientes (horario de los turnos), Reportes (avisos del motor y stock bajo) e Inventario
-- (los plazos de la tienda, cuando los conecte).
GRANT SELECT ON {{DB_NAME}}.configuracion TO 'pacientes'@'%';
GRANT SELECT ON {{DB_NAME}}.configuracion TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.configuracion TO 'inventario'@'%';
