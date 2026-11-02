-- Permisos sobre las tablas de la migración 002 (base/002_inventario_producto.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- producto: inventario lee, crea y modifica (la baja es lógica: UPDATE activo = 0, nunca DELETE).
-- Pacientes solo lo lee, para tomar el precio al agregar un producto a una consulta.
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.producto TO 'inventario'@'%';
GRANT SELECT                 ON {{DB_NAME}}.producto TO 'pacientes'@'%';

-- movimiento_inventario: los movimientos no se modifican ni se borran, son el historial del stock.
-- Solo los escribe Inventario (también las salidas por consulta, que Pacientes pide por /internal/).
GRANT SELECT, INSERT ON {{DB_NAME}}.movimiento_inventario TO 'inventario'@'%';
