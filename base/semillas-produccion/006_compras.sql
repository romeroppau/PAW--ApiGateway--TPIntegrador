-- Producción 006 · 150 compras de la tienda (carritos, facturas V-030001 a V-030150 y pagos con el
-- mismo id; "i" es el número del 1 al 150)
--
--   Comprador: el cliente de la demo 1 en una de cada ocho (19 compras; la 2 está pagada y para
--   retirar), el resto los clientes de fondo.
--   Fecha: hace i días (de ayer a hace 5 meses), en horario de comercio.
--   Estado: las de los últimos 4 días PAGADA (para retirar); 1 de cada 7 CANCELADA, alternando el
--   motivo: por el comprador (pagada, con el reintegro del 75 % ya devuelto), sin pago o vencida (no
--   la retiró: sin reintegro); el resto ENTREGADA por la veterinaria, 1 o 2 días después.
--   De 1 a 2 productos de 002 por compra, al precio de hoy. La política de reintegro es la de
--   siempre (75 % / 50 % / 48 horas). Cada compra tiene su plazo para pagar (15 minutos) y para retirar
--   (el 5.º día hábil), como las de verdad: las pagadas para retirar dicen hasta cuándo.
--   Movimientos: la venta de cada producto (se reservó al confirmar) y, si se canceló, la devolución
--   (VENTA_CANCELADA). No cambian el stock: 010_movimientos.sql cierra las cuentas con el de 002.
-- Correr de nuevo deja todo como estaba, con las fechas corridas a hoy.

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

DROP TEMPORARY TABLE IF EXISTS prod_compra;
-- Con clave primaria: Aiven tiene sql_require_primary_key=ON (también para las temporales).
CREATE TEMPORARY TABLE prod_compra (
  i         INT           NOT NULL,
  cliente   INT UNSIGNED  NOT NULL,
  fecha     DATETIME      NOT NULL,
  estado    VARCHAR(20)   NOT NULL,
  motivo    VARCHAR(20)   NULL,
  producto  INT UNSIGNED  NOT NULL,
  cantidad  INT           NOT NULL,
  precio    DECIMAL(10,2) NOT NULL,
  producto2 INT UNSIGNED  NULL,
  precio2   DECIMAL(10,2) NULL,
  PRIMARY KEY (i)
);
INSERT INTO prod_compra (i, cliente, fecha, estado, motivo, producto, cantidad, precio, producto2, precio2)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 150)
SELECT n.i,
       IF(n.i % 8 = 2, @cliente1, 3001 + (n.i % 40)),
       TIMESTAMP(DATE(@ahora) - INTERVAL n.i DAY, SEC_TO_TIME((9 * 60 + (n.i * 47) % 600) * 60)),
       CASE
         WHEN n.i <= 4 THEN 'PAGADA'
         WHEN n.i % 7 = 0 THEN 'CANCELADA'
         ELSE 'ENTREGADA'
       END,
       IF(n.i > 4 AND n.i % 7 = 0, ELT(1 + ((n.i DIV 7) % 3), 'COMPRADOR', 'SIN_PAGO', 'VENCIDA'), NULL),
       p.id, 1 + (n.i % 2), p.precio,
       IF(n.i % 3 = 0, q.id, NULL), IF(n.i % 3 = 0, q.precio, NULL)
FROM n
JOIN producto p ON p.id = 3001 + ((n.i * 11) % 30)
JOIN producto q ON q.id = 3001 + ((n.i * 17 + 5) % 30);
-- No dos veces el mismo producto en una compra.
UPDATE prod_compra SET producto2 = NULL, precio2 = NULL WHERE producto2 = producto;

-- Los carritos (ninguno abierto: no le cambian el carrito a nadie).
INSERT INTO carrito (id, cliente_id, estado, creado_en)
SELECT 30000 + i, cliente,
       CASE estado WHEN 'PAGADA' THEN 'PAGADO' WHEN 'ENTREGADA' THEN 'RETIRADO' ELSE 'CANCELADO' END,
       fecha - INTERVAL 12 MINUTE
FROM prod_compra
ON DUPLICATE KEY UPDATE cliente_id = VALUES(cliente_id), estado = VALUES(estado), creado_en = VALUES(creado_en);

DELETE FROM item_carrito WHERE carrito_id BETWEEN 30001 AND 30150;
INSERT INTO item_carrito (carrito_id, producto_id, cantidad, precio_unitario)
SELECT 30000 + i, producto, cantidad, precio FROM prod_compra;
INSERT INTO item_carrito (carrito_id, producto_id, cantidad, precio_unitario)
SELECT 30000 + i, producto2, 1, precio2 FROM prod_compra WHERE producto2 IS NOT NULL;

-- Las facturas. Primero los pagos de la carga anterior, que apuntan a ellas.
DELETE FROM pago WHERE factura_compra_id BETWEEN 30001 AND 30150;
INSERT INTO factura_compra
  (id, numero, carrito_id, total, estado, motivo_cancelacion, cancelada_en, fecha, pagar_antes_de, retirar_hasta,
   entregada_en, entregada_por, reintegro_anticipado, reintegro_ultimo_momento, reintegro_horas,
   reintegro_porcentaje, reintegro_monto, reintegro_estado)
SELECT 30000 + i, CONCAT('V-', LPAD(30000 + i, 6, '0')), 30000 + i,
       precio * cantidad + COALESCE(precio2, 0), estado, motivo,
       CASE motivo WHEN 'SIN_PAGO' THEN fecha + INTERVAL 15 MINUTE WHEN 'COMPRADOR' THEN fecha + INTERVAL 1 DAY
                   WHEN 'VENCIDA' THEN fecha + INTERVAL 8 DAY ELSE NULL END,
       fecha, fecha + INTERVAL 15 MINUTE,
       -- Sin pagar no llegó a tener plazo de retiro (migración 015: el 5.º día hábil).
       IF(motivo = 'SIN_PAGO', NULL, DATE(fecha) + INTERVAL (CASE WEEKDAY(fecha) WHEN 5 THEN 6 WHEN 6 THEN 5 ELSE 7 END) DAY),
       IF(estado = 'ENTREGADA', fecha + INTERVAL (1 + i % 2) DAY + INTERVAL 2 HOUR, NULL),
       IF(estado = 'ENTREGADA', @vet, NULL),
       75, 50, 48,
       IF(motivo = 'COMPRADOR', 75, NULL),
       IF(motivo = 'COMPRADOR', ROUND((precio * cantidad + COALESCE(precio2, 0)) * 0.75, 2), NULL),
       IF(motivo = 'COMPRADOR', 'HECHO', NULL)
FROM prod_compra
ON DUPLICATE KEY UPDATE
  numero = VALUES(numero), carrito_id = VALUES(carrito_id), total = VALUES(total), estado = VALUES(estado),
  motivo_cancelacion = VALUES(motivo_cancelacion), cancelada_en = VALUES(cancelada_en), fecha = VALUES(fecha),
  entregada_en = VALUES(entregada_en), entregada_por = VALUES(entregada_por),
  pagar_antes_de = VALUES(pagar_antes_de), retirar_hasta = VALUES(retirar_hasta),
  reintegro_anticipado = VALUES(reintegro_anticipado), reintegro_ultimo_momento = VALUES(reintegro_ultimo_momento),
  reintegro_horas = VALUES(reintegro_horas), reintegro_porcentaje = VALUES(reintegro_porcentaje),
  reintegro_monto = VALUES(reintegro_monto), reintegro_estado = VALUES(reintegro_estado);

-- Los pagos aprobados: todas menos las canceladas sin pago.
INSERT INTO pago (id, factura_compra_id, monto, id_externo, estado, fecha)
SELECT 30000 + i, 30000 + i, precio * cantidad + COALESCE(precio2, 0), CONCAT('prod-pago-', i), 'APROBADO',
       fecha + INTERVAL 4 MINUTE
FROM prod_compra
WHERE motivo IS NULL OR motivo <> 'SIN_PAGO';

-- Los movimientos (id_operacion fijo: una recarga solo les corre la fecha). Primero los de la carga
-- anterior, por si una compra cambió de productos.
DELETE FROM movimiento_inventario WHERE id_operacion LIKE 'prod-venta-V-0%' OR id_operacion LIKE 'prod-cancela-V-0%';
-- La venta de cada producto: al confirmar se reserva el stock (también en las que después no se pagaron).
INSERT INTO movimiento_inventario (producto_id, insumo_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha)
SELECT producto, NULL, 'SALIDA', cantidad, 'VENTA', cliente,
       CONCAT('prod-venta-V-', LPAD(30000 + i, 6, '0'), '-', producto), fecha
FROM prod_compra;
INSERT INTO movimiento_inventario (producto_id, insumo_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha)
SELECT producto2, NULL, 'SALIDA', 1, 'VENTA', cliente,
       CONCAT('prod-venta-V-', LPAD(30000 + i, 6, '0'), '-', producto2), fecha
FROM prod_compra
WHERE producto2 IS NOT NULL;
-- La devolución de las canceladas, cuando se cancelaron (la del comprador, a su nombre; las demás, de
-- la tarea de vencimientos).
INSERT INTO movimiento_inventario (producto_id, insumo_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha)
SELECT producto, NULL, 'ENTRADA', cantidad, 'VENTA_CANCELADA', IF(motivo = 'COMPRADOR', cliente, NULL),
       CONCAT('prod-cancela-V-', LPAD(30000 + i, 6, '0'), '-', producto),
       CASE motivo WHEN 'SIN_PAGO' THEN fecha + INTERVAL 15 MINUTE WHEN 'COMPRADOR' THEN fecha + INTERVAL 1 DAY ELSE fecha + INTERVAL 8 DAY END
FROM prod_compra WHERE estado = 'CANCELADA';
INSERT INTO movimiento_inventario (producto_id, insumo_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha)
SELECT producto2, NULL, 'ENTRADA', 1, 'VENTA_CANCELADA', IF(motivo = 'COMPRADOR', cliente, NULL),
       CONCAT('prod-cancela-V-', LPAD(30000 + i, 6, '0'), '-', producto2),
       CASE motivo WHEN 'SIN_PAGO' THEN fecha + INTERVAL 15 MINUTE WHEN 'COMPRADOR' THEN fecha + INTERVAL 1 DAY ELSE fecha + INTERVAL 8 DAY END
FROM prod_compra WHERE estado = 'CANCELADA' AND producto2 IS NOT NULL;

DROP TEMPORARY TABLE IF EXISTS prod_compra;
