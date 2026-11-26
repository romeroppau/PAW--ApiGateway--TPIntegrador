-- Permisos sobre la tabla de la migración 029 (base/029_inventario_vence_y_lotes_de_insumos.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- lote_insumo: la escribe Inventario (igual que lote_producto). Sin DELETE: un lote vacío queda (sus
-- movimientos lo nombran).
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.lote_insumo TO 'inventario'@'%';
-- Reportes lo lee: el stock bajo de los insumos sin lo vencido y los lotes vencidos para retirar.
GRANT SELECT ON {{DB_NAME}}.lote_insumo TO 'reportes'@'%';
