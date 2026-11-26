-- Permisos sobre la tabla de la migración 028 (base/028_inventario_lotes.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- lote_producto: la escribe Inventario. Sin DELETE: un lote vacío queda (sus movimientos lo nombran).
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.lote_producto TO 'inventario'@'%';
-- Reportes lo lee: "Qué liquidar", el aviso del motor y el stock bajo, por lote.
GRANT SELECT ON {{DB_NAME}}.lote_producto TO 'reportes'@'%';
