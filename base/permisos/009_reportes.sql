-- Permisos del usuario reportes (migración 009). Solo lectura: el motor y los reportes no escriben;
-- los avisos los pide a Backend por la llamada interna /internal/notificaciones.
-- Siguen la tabla "Permisos de MySQL por módulo" del DER.

-- Reportes de turnos, consultas y facturas.
GRANT SELECT ON {{DB_NAME}}.turno                  TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.consulta               TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.item_insumo_consulta   TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.item_producto_consulta TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.factura_consulta       TO 'reportes'@'%';

-- Stock, vencimientos y movimientos.
GRANT SELECT ON {{DB_NAME}}.producto               TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.insumo                 TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.movimiento_inventario  TO 'reportes'@'%';

-- Motor: vacunas (a quién avisar) y controles de la adopción (30 y 90 días).
GRANT SELECT ON {{DB_NAME}}.evento_sanitario       TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.plan_sanitario         TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.mascota                TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.usuario                TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.adopcion               TO 'reportes'@'%';
GRANT SELECT ON {{DB_NAME}}.publicacion            TO 'reportes'@'%';

-- La vista de turnos atendidos.
GRANT SELECT ON {{DB_NAME}}.v_turnos_atendidos TO 'reportes'@'%';