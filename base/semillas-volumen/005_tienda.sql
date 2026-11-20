-- Volumen 005 · 150 compras de la tienda (carritos, facturas V-020001 a V-020150 y pagos con el
-- mismo id; "i" es el número del 1 al 150)
--
--   Comprador: el cliente de prueba 102 en una de cada cinco (30 compras: "Mis compras" de a 20 y
--   el filtro de fechas), el resto los clientes del volumen.
--   Fecha: hace i días (de ayer a hace 5 meses).
--   Estado: 1 de cada 7 CANCELADA (por el comprador, sin pago o vencida, alternando); las de los
--   últimos 4 días PAGADA (para retirar); el resto ENTREGADA (por la veterinaria 101, 2 días después).
--   Un producto de las semillas comunes (101 a 115) por compra, de 1 a 3 unidades, al precio de hoy.
--   Los plazos (migración 015) quedan vacíos: Inventario los calcula desde la fecha.
--   No mueven el stock (lo deja la semilla 002), pero sí dejan su movimiento de venta, para los reportes.
-- Correr de nuevo deja todo como estaba, con las fechas corridas a hoy.

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

DROP TEMPORARY TABLE IF EXISTS vol_compra;
CREATE TEMPORARY TABLE vol_compra AS
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 150)
SELECT n.i,
       IF(n.i % 5 = 0, 102, 2002 + (n.i % 40)) AS cliente,
       @ahora - INTERVAL n.i DAY - INTERVAL (n.i % 9) HOUR AS fecha,
       CASE
         WHEN n.i % 7 = 0 THEN 'CANCELADA'
         WHEN n.i <= 4 THEN 'PAGADA'
         ELSE 'ENTREGADA'
       END AS estado,
       IF(n.i % 7 = 0, ELT(1 + ((n.i DIV 7) % 3), 'COMPRADOR', 'SIN_PAGO', 'VENCIDA'), NULL) AS motivo,
       101 + (n.i % 15) AS producto,
       1 + (n.i % 3) AS cantidad,
       p.precio
FROM n JOIN producto p ON p.id = 101 + (n.i % 15);

-- Los carritos (ninguno abierto: no le cambian el carrito a nadie).
INSERT INTO carrito (id, cliente_id, estado, creado_en)
SELECT 20000 + i, cliente,
       CASE estado WHEN 'PAGADA' THEN 'PAGADO' WHEN 'ENTREGADA' THEN 'RETIRADO' ELSE 'CANCELADO' END,
       fecha - INTERVAL 10 MINUTE
FROM vol_compra
ON DUPLICATE KEY UPDATE cliente_id = VALUES(cliente_id), estado = VALUES(estado), creado_en = VALUES(creado_en);

DELETE FROM item_carrito WHERE carrito_id BETWEEN 20001 AND 20150;
INSERT INTO item_carrito (carrito_id, producto_id, cantidad, precio_unitario)
SELECT 20000 + i, producto, cantidad, precio FROM vol_compra;

-- Las facturas. Primero los pagos de la carga anterior, que apuntan a ellas.
DELETE FROM pago WHERE factura_compra_id BETWEEN 20001 AND 20150;
INSERT INTO factura_compra
  (id, numero, carrito_id, total, estado, motivo_cancelacion, cancelada_en, fecha, entregada_en, entregada_por)
SELECT 20000 + i, CONCAT('V-', LPAD(20000 + i, 6, '0')), 20000 + i, precio * cantidad, estado, motivo,
       CASE motivo WHEN 'SIN_PAGO' THEN fecha + INTERVAL 15 MINUTE WHEN 'COMPRADOR' THEN fecha + INTERVAL 2 HOUR
                   WHEN 'VENCIDA' THEN fecha + INTERVAL 8 DAY ELSE NULL END,
       fecha,
       IF(estado = 'ENTREGADA', fecha + INTERVAL 2 DAY, NULL),
       IF(estado = 'ENTREGADA', 101, NULL)
FROM vol_compra
ON DUPLICATE KEY UPDATE
  numero = VALUES(numero), carrito_id = VALUES(carrito_id), total = VALUES(total), estado = VALUES(estado),
  motivo_cancelacion = VALUES(motivo_cancelacion), cancelada_en = VALUES(cancelada_en), fecha = VALUES(fecha),
  entregada_en = VALUES(entregada_en), entregada_por = VALUES(entregada_por),
  pagar_antes_de = NULL, retirar_hasta = NULL;

-- Los pagos aprobados: las pagadas, las entregadas y las que vencieron sin retirar (las canceladas
-- por el comprador o por falta de pago no se pagaron).
INSERT INTO pago (id, factura_compra_id, monto, id_externo, estado, fecha)
SELECT 20000 + i, 20000 + i, precio * cantidad, CONCAT('volumen-pago-', i), 'APROBADO', fecha + INTERVAL 5 MINUTE
FROM vol_compra
WHERE estado <> 'CANCELADA' OR motivo = 'VENCIDA';

-- El movimiento de la venta de cada compra (id_operacion fijo: una recarga solo le corre la fecha).
INSERT INTO movimiento_inventario (producto_id, tipo, cantidad, motivo, usuario_id, id_operacion, fecha)
SELECT producto, 'SALIDA', cantidad, 'VENTA', cliente,
       CONCAT('volumen-venta-V-', LPAD(20000 + i, 6, '0'), '-', producto), fecha
FROM vol_compra
ON DUPLICATE KEY UPDATE producto_id = VALUES(producto_id), cantidad = VALUES(cantidad), fecha = VALUES(fecha);

DROP TEMPORARY TABLE IF EXISTS vol_compra;
