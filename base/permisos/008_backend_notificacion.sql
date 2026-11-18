-- Permisos sobre las tablas de la migración 008 (base/008_backend_notificacion.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- notificacion: la escribe Backend. No se borran: se marcan como leídas.
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.notificacion TO 'backend'@'%';