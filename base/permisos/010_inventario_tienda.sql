-- Permisos sobre las tablas de la migración 010 (base/010_inventario_tienda.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER: las cuatro las escribe Inventario.
-- Carritos, facturas y pagos no se borran: cambian de estado.

GRANT SELECT, INSERT, UPDATE         ON {{DB_NAME}}.carrito        TO 'inventario'@'%';
-- item_carrito también DELETE: el cliente quita un producto de su carrito.
GRANT SELECT, INSERT, UPDATE, DELETE ON {{DB_NAME}}.item_carrito   TO 'inventario'@'%';
GRANT SELECT, INSERT, UPDATE         ON {{DB_NAME}}.factura_compra TO 'inventario'@'%';
GRANT SELECT, INSERT, UPDATE         ON {{DB_NAME}}.pago           TO 'inventario'@'%';
