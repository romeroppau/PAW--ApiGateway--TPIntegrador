-- Migración 012 · módulo Inventario (tienda)
-- Guarda por qué y cuándo se canceló cada compra. Hace falta porque el comprador ahora también puede
-- cancelar una compra ya pagada (sin devolución), y hay que distinguirla de las que vencieron:
--   - la veterinaria ve el motivo en la pestaña "Cancelados";
--   - cada cancelación lleva su propio aviso al comprador.
--   COMPRADOR: la canceló el comprador (antes de pagar o ya pagada)
--   SIN_PAGO:  no se pagó en 15 minutos
--   VENCIDA:   venció el plazo de retiro (5 días hábiles)
-- No cambia los permisos: Inventario ya actualiza factura_compra (permisos/010).

ALTER TABLE factura_compra
  ADD COLUMN motivo_cancelacion ENUM('COMPRADOR','SIN_PAGO','VENCIDA') NULL AFTER estado,
  ADD COLUMN cancelada_en DATETIME NULL AFTER motivo_cancelacion;

-- Las que ya estaban canceladas. Hasta ahora el comprador solo podía cancelar antes de pagar, y esa
-- cancelación deja movimientos "cancela-V-…" con su usuario; las automáticas, sin usuario. Una
-- cancelada con pago aprobado solo pudo vencer. La fecha: la del movimiento que devolvió el stock.
UPDATE factura_compra f
SET f.motivo_cancelacion = CASE
      WHEN EXISTS (SELECT 1 FROM movimiento_inventario m
                   WHERE m.id_operacion LIKE CONCAT('cancela-', f.numero, '-%') AND m.usuario_id IS NOT NULL)
        THEN 'COMPRADOR'
      WHEN EXISTS (SELECT 1 FROM pago p WHERE p.factura_compra_id = f.id AND p.estado = 'APROBADO')
        THEN 'VENCIDA'
      ELSE 'SIN_PAGO'
    END,
    f.cancelada_en = COALESCE(
      (SELECT MAX(m.fecha) FROM movimiento_inventario m WHERE m.id_operacion LIKE CONCAT('%cancela-', f.numero, '-%')),
      f.fecha)
WHERE f.estado = 'CANCELADA';
