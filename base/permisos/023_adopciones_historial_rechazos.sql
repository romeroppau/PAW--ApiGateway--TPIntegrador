-- Permisos sobre la tabla de la migración 023 (base/023_adopciones_historial_rechazos.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- publicacion_rechazo: la escribe Adopciones al rechazar. Solo se agrega: nunca se edita ni se borra.
GRANT SELECT, INSERT ON {{DB_NAME}}.publicacion_rechazo TO 'adopciones'@'%';
