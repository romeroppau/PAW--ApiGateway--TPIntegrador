-- Permisos sobre las tablas de la migración 006 (base/006_pacientes_consulta.sql).
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- consulta y factura_consulta: las escribe Pacientes. No se borran: son la ficha clínica y la
-- facturación.
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.consulta         TO 'pacientes'@'%';
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.factura_consulta TO 'pacientes'@'%';

-- Ítems: mientras la consulta está abierta, el veterinario puede quitarlos (DELETE).
GRANT SELECT, INSERT, UPDATE, DELETE ON {{DB_NAME}}.item_insumo_consulta   TO 'pacientes'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON {{DB_NAME}}.item_producto_consulta TO 'pacientes'@'%';
