-- Migración 011 · módulo Backend (notificaciones)
-- Suma el tipo COMPRA a la tabla notificacion (migración 008): los avisos de la tienda al comprador
-- (recordatorios para retirar el pedido y aviso de cancelación por vencimiento). Los manda Inventario
-- por POST /internal/notificaciones. No cambia los permisos: Backend ya escribe esta tabla.

ALTER TABLE notificacion
  MODIFY tipo ENUM('VACUNA','CONTROL_ADOPCION','STOCK_BAJO','PROMOCION','CUENTA','POSTULACION','COMPRA') NOT NULL;
