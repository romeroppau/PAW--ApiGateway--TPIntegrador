-- Permisos sobre la tabla de la migración 016 (base/016_inventario_promocion.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- promocion: la escribe Inventario. Sin DELETE: terminar una promoción completa terminada_en.
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.promocion TO 'inventario'@'%';
