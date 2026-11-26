-- Semilla 010 · compras de prueba de la tienda (usuarios de la semilla 001, productos de la 002)
-- Correr las semillas de nuevo vuelve todo a su estado inicial (ids fijos desde 101).
--
--   V-000101  cliente 102          2 x alimento cachorro (101)   PAGADA: lista para retirar (comprada ayer)
--   V-000102  rescatista 104       1 x collar (110)              ENTREGADA (comprada hace 10 días)
--   V-000103  cliente 102          1 x antiparasitario (106)     CANCELADA: venció el plazo de retiro, sin devolución
--   V-000100  rescatista 104       1 x snacks dentales (105)     PENDIENTE_PAGO hace 40 minutos: venció el plazo para
--                                                                pagar y se cancela sola (la tarea o al pasar)
--   V-000099  cliente 103          1 x correa extensible (113)   PAGADA hace 2 días: para probar que el comprador
--                                                                cancela un pedido pagado (sin devolución)
--   carrito 103 (abierto)  cliente 103   1 x comedero (112)      para probar el carrito y la confirmación
--
-- Las compras pagadas tienen su pago aprobado de Mercado Pago (con un número de operación de prueba)
-- y sus movimientos de stock. El stock lo deja la semilla 002; solo la V-000100 (1 snack) y la
-- V-000099 (1 correa) lo tienen reservado: se resta acá y vuelve cuando se cancelan.
--
-- La V-000100, la V-000099 y sus carritos usan ids menores que 101 porque se agregaron después: los
-- ids desde 104 ya los pueden tener compras reales de dev. La base numera las nuevas desde el más
-- alto que existe, así que un id menor que 101 nunca lo toma otra compra.

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;   -- hora de Argentina (Aiven trabaja en UTC)

-- Un comprador tiene un solo carrito abierto: si las pruebas le dejaron otro a alguno de los
-- compradores de prueba, se cancela antes de volver a abrir el 103.
UPDATE carrito SET estado = 'CANCELADO'
  WHERE cliente_id IN (102, 103, 104) AND estado = 'ABIERTO' AND id <> 103;

INSERT INTO carrito (id, cliente_id, estado, creado_en) VALUES
  (101, 102, 'PAGADO',    @ahora - INTERVAL 1 DAY),
  (102, 104, 'RETIRADO',  @ahora - INTERVAL 10 DAY),
  (103, 103, 'ABIERTO',   @ahora),
  (104, 102, 'CANCELADO', @ahora - INTERVAL 12 DAY),
  (100, 104, 'CONFIRMADO', @ahora - INTERVAL 40 MINUTE),
  (99,  103, 'PAGADO',    @ahora - INTERVAL 2 DAY)
ON DUPLICATE KEY UPDATE
  cliente_id = VALUES(cliente_id), estado = VALUES(estado), creado_en = VALUES(creado_en);

-- Los ítems de cada carrito, con el precio del momento.
DELETE FROM item_carrito WHERE carrito_id IN (99, 100, 101, 102, 103, 104);
INSERT INTO item_carrito (carrito_id, producto_id, cantidad, precio_unitario) VALUES
  (101, 101, 2, 15999.90),
  (102, 110, 1,  5200.00),
  (103, 112, 1,  6700.00),
  (104, 106, 1,  7800.00),
  (100, 105, 1,  4500.00),
  (99,  113, 1, 14500.00);

-- Las facturas (el carrito abierto todavía no tiene).
-- motivo_cancelacion y cancelada_en (migración 012): solo en la cancelada.
INSERT INTO factura_compra (id, numero, carrito_id, total, estado, motivo_cancelacion, cancelada_en, fecha, entregada_en, entregada_por) VALUES
  (101, 'V-000101', 101, 31999.80, 'PAGADA',         NULL,      NULL,                   @ahora - INTERVAL 1 DAY,      NULL,                   NULL),
  (102, 'V-000102', 102,  5200.00, 'ENTREGADA',      NULL,      NULL,                   @ahora - INTERVAL 10 DAY,     @ahora - INTERVAL 7 DAY, 101),
  (103, 'V-000103', 104,  7800.00, 'CANCELADA',      'VENCIDA', @ahora - INTERVAL 4 DAY, @ahora - INTERVAL 12 DAY,     NULL,                   NULL),
  (100, 'V-000100', 100,  4500.00, 'PENDIENTE_PAGO', NULL,      NULL,                   @ahora - INTERVAL 40 MINUTE,  NULL,                   NULL),
  (99,  'V-000099', 99,  14500.00, 'PAGADA',         NULL,      NULL,                   @ahora - INTERVAL 2 DAY,      NULL,                   NULL)
ON DUPLICATE KEY UPDATE
  numero = VALUES(numero), carrito_id = VALUES(carrito_id), total = VALUES(total), estado = VALUES(estado),
  motivo_cancelacion = VALUES(motivo_cancelacion), cancelada_en = VALUES(cancelada_en),
  fecha = VALUES(fecha), entregada_en = VALUES(entregada_en), entregada_por = VALUES(entregada_por),
  -- Los plazos (migración 015) y la política de reintegro (017) quedan vacíos: Inventario usa los
  -- valores de siempre (15 minutos, 5 días hábiles, 75 % / 50 % / 48 horas). Así una recarga no deja
  -- los datos de la carga anterior (tampoco un reintegro de una cancelación de las pruebas).
  pagar_antes_de = NULL, retirar_hasta = NULL,
  reintegro_anticipado = NULL, reintegro_ultimo_momento = NULL, reintegro_horas = NULL,
  reintegro_porcentaje = NULL, reintegro_monto = NULL, reintegro_estado = NULL, reintegro_en = NULL;

-- Los pagos aprobados por Mercado Pago (la 103 venció después, sin devolución).
INSERT INTO pago (id, factura_compra_id, monto, id_externo, estado, fecha) VALUES
  (101, 101, 31999.80, 'semilla-pago-101', 'APROBADO', @ahora - INTERVAL 1 DAY),
  (102, 102,  5200.00, 'semilla-pago-102', 'APROBADO', @ahora - INTERVAL 10 DAY),
  (103, 103,  7800.00, 'semilla-pago-103', 'APROBADO', @ahora - INTERVAL 12 DAY),
  (99,  99,  14500.00, 'semilla-pago-99',  'APROBADO', @ahora - INTERVAL 2 DAY)
ON DUPLICATE KEY UPDATE
  factura_compra_id = VALUES(factura_compra_id), monto = VALUES(monto), id_externo = VALUES(id_externo),
  estado = VALUES(estado), fecha = VALUES(fecha);

-- Los movimientos de stock: la reserva al confirmar (SALIDA / VENTA) y, en la cancelada, la vuelta
-- del stock (ENTRADA / VENTA_CANCELADA). id_operacion es único: si ya están, no se repiten.
INSERT IGNORE INTO movimiento_inventario (producto_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha) VALUES
  (101, 'SALIDA',  2, 'VENTA',           102, 'semilla-venta-V-000101-101',   @ahora - INTERVAL 1 DAY),
  (110, 'SALIDA',  1, 'VENTA',           104, 'semilla-venta-V-000102-110',   @ahora - INTERVAL 10 DAY),
  (106, 'SALIDA',  1, 'VENTA',           102, 'semilla-venta-V-000103-106',   @ahora - INTERVAL 12 DAY),
  (106, 'ENTRADA', 1, 'VENTA_CANCELADA', 102, 'semilla-cancela-V-000103-106', @ahora - INTERVAL 4 DAY),
  (105, 'SALIDA',  1, 'VENTA',           104, 'semilla-venta-V-000100-105',   @ahora - INTERVAL 40 MINUTE),
  (113, 'SALIDA',  1, 'VENTA',           103, 'semilla-venta-V-000099-113',   @ahora - INTERVAL 2 DAY);

-- Las compras vuelven a su estado: se borran las vueltas del stock de las cancelaciones que hicieron
-- las pruebas (su id_operacion es fijo y, si quedara, no se podrían volver a cancelar), y la V-000100
-- y la V-000099 vuelven a tener su producto reservado.
-- Desde la migración 028 la vuelta del stock es por lote: "cancela-V-000100-105-lote-{lote}".
DELETE FROM movimiento_inventario
  WHERE id_operacion IN ('cancela-V-000100-105', 'cancela-V-000099-113', 'cancela-V-000101-101')
     OR id_operacion LIKE 'cancela-V-000100-105-lote-%'
     OR id_operacion LIKE 'cancela-V-000099-113-lote-%'
     OR id_operacion LIKE 'cancela-V-000101-101-lote-%';
UPDATE producto SET stock = stock - 1 WHERE id IN (105, 113);
