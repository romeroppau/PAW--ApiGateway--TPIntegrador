-- Permisos sobre las tablas de la migración 007 (base/007_adopciones.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- publicacion, adopcion y postulacion: las escribe Adopciones. No se borran: una publicación se
-- da de baja (activa = 0), una adopción se cancela y una postulación queda rechazada.
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.publicacion TO 'adopciones'@'%';
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.adopcion    TO 'adopciones'@'%';
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.postulacion TO 'adopciones'@'%';

-- Adopciones solo lee lo de los demás: el rescatista y su estado (usuario), que la mascota esté a
-- cargo del rescatista (mascota) y que el chequeo esté ATENDIDO (turno). La mascota pasa al
-- adoptante por la llamada interna a Pacientes, nunca con un UPDATE desde Adopciones.
GRANT SELECT ON {{DB_NAME}}.usuario TO 'adopciones'@'%';
GRANT SELECT ON {{DB_NAME}}.mascota TO 'adopciones'@'%';
GRANT SELECT ON {{DB_NAME}}.turno   TO 'adopciones'@'%';
