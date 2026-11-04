-- Permisos sobre las tablas de la migración 003 (base/003_inventario_insumo.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- insumo: inventario lee, crea y modifica (la baja es lógica: UPDATE activo = 0, nunca DELETE).
-- Pacientes solo lo lee, para tomar el costo al agregar un insumo a una consulta. El stock lo
-- descuenta Inventario, cuando Pacientes se lo pide por /internal/.
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.insumo TO 'inventario'@'%';
GRANT SELECT                 ON {{DB_NAME}}.insumo TO 'pacientes'@'%';
