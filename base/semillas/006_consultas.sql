-- Semilla 006 · consultas de prueba
-- 1. Borra las consultas que se hayan hecho al probar sobre los turnos de hoy y de mañana
--    (101 a 103), con sus ítems y su factura. Así esos turnos, que la semilla 004 volvió a dejar
--    en PROGRAMADO, se pueden atender de nuevo.
-- 2. Carga la consulta finalizada del turno 104 (ayer, ya atendido), con su factura, para que el
--    historial clínico no salga vacío.
-- Las consultas de prueba no generan movimientos de inventario: el stock lo vuelven a dejar
-- las semillas 002 y 003.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);

DELETE f FROM factura_consulta f
  JOIN consulta c ON c.id = f.consulta_id
  WHERE c.turno_id IN (101, 102, 103);

DELETE i FROM item_insumo_consulta i
  JOIN consulta c ON c.id = i.consulta_id
  WHERE c.turno_id IN (101, 102, 103);

DELETE i FROM item_producto_consulta i
  JOIN consulta c ON c.id = i.consulta_id
  WHERE c.turno_id IN (101, 102, 103);

UPDATE evento_sanitario e
  JOIN consulta c ON c.id = e.consulta_id
  SET e.consulta_id = NULL, e.fecha_aplicada = NULL
  WHERE c.turno_id IN (101, 102, 103);

DELETE FROM consulta WHERE turno_id IN (101, 102, 103);

-- Consulta 101: Tom (mascota 104), turno 104 de ayer.
INSERT INTO consulta
  (id, turno_id, diagnostico, observaciones, valor_base, estado, finalizada_en)
VALUES
  (101, 104, 'Otitis externa leve en el oído derecho.', 'Control en 10 días.', 15000.00, 'FINALIZADA',
   TIMESTAMP(@hoy - INTERVAL 1 DAY, '08:40:00'))
ON DUPLICATE KEY UPDATE
  turno_id = VALUES(turno_id),
  diagnostico = VALUES(diagnostico),
  observaciones = VALUES(observaciones),
  valor_base = VALUES(valor_base),
  estado = VALUES(estado),
  finalizada_en = VALUES(finalizada_en);

-- Insumos: 2 jeringas y 1 par de guantes. Producto: 1 vitaminas multiespecie.
INSERT INTO item_insumo_consulta
  (id, consulta_id, insumo_id, cantidad, costo_unitario)
VALUES
  (101, 101, 101, 2, 150.00),
  (102, 101, 102, 1, 220.00)
ON DUPLICATE KEY UPDATE
  consulta_id = VALUES(consulta_id),
  insumo_id = VALUES(insumo_id),
  cantidad = VALUES(cantidad),
  costo_unitario = VALUES(costo_unitario);

INSERT INTO item_producto_consulta
  (id, consulta_id, producto_id, cantidad, precio_unitario)
VALUES
  (101, 101, 109, 1, 8900.00)
ON DUPLICATE KEY UPDATE
  consulta_id = VALUES(consulta_id),
  producto_id = VALUES(producto_id),
  cantidad = VALUES(cantidad),
  precio_unitario = VALUES(precio_unitario);

-- Factura: 15.000 + 520 (insumos) + 8.900 (productos) = 24.420.
INSERT INTO factura_consulta
  (id, numero, consulta_id, subtotal_base, subtotal_insumos, subtotal_productos, total,
   huellitas_usadas, estado, fecha)
VALUES
  (101, 'C-000101', 101, 15000.00, 520.00, 8900.00, 24420.00, NULL, 'PAGADA',
   TIMESTAMP(@hoy - INTERVAL 1 DAY, '08:40:00'))
ON DUPLICATE KEY UPDATE
  numero = VALUES(numero),
  consulta_id = VALUES(consulta_id),
  subtotal_base = VALUES(subtotal_base),
  subtotal_insumos = VALUES(subtotal_insumos),
  subtotal_productos = VALUES(subtotal_productos),
  total = VALUES(total),
  huellitas_usadas = VALUES(huellitas_usadas),
  estado = VALUES(estado),
  fecha = VALUES(fecha);
