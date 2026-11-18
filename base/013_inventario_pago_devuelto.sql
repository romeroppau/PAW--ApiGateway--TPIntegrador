-- Migración 013 · módulo Inventario (tienda, pago con Mercado Pago)
-- Suma el estado DEVUELTO a la tabla pago (migración 010): un pago aprobado que no se pudo aplicar
-- (llegó con la compra ya cancelada y sin stock, o la compra ya estaba pagada con otro pago) se
-- registra DEVUELTO y se le pide la devolución a Mercado Pago. No cambia los permisos: Inventario ya
-- escribe esta tabla (permisos/010).

ALTER TABLE pago
  MODIFY estado ENUM('PENDIENTE','APROBADO','RECHAZADO','DEVUELTO') NOT NULL DEFAULT 'PENDIENTE';
