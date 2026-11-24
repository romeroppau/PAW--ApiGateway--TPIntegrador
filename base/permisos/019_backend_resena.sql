-- Permisos sobre la tabla de la migración 019 (base/019_backend_resena.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- resena: la maneja Backend. DELETE porque el autor puede borrar su reseña.
GRANT SELECT, INSERT, UPDATE, DELETE ON {{DB_NAME}}.resena TO 'backend'@'%';
