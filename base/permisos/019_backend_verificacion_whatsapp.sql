-- Permisos sobre la tabla de la migración 019 (base/019_backend_verificacion_whatsapp.sql).
-- La usa solo Backend. Sin DELETE: las filas quedan para limitar los envíos por número.
GRANT SELECT, INSERT, UPDATE ON {{DB_NAME}}.verificacion_whatsapp TO 'backend'@'%';
