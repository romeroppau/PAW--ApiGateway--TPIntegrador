-- Migración 015 · módulo Inventario (tienda)
-- Cada compra guarda sus plazos al confirmarse: hasta cuándo se puede pagar y hasta qué día se puede
-- retirar. Hace falta porque la veterinaria ahora puede cambiar esos plazos desde su panel
-- (configuración, migración 014): un cambio vale solo para las compras NUEVAS; las que ya existen
-- siguen con lo que se les prometió.
-- Las columnas aceptan NULL: si una compra no las tiene (por ejemplo, una creada por código viejo
-- mientras se publicaba la versión nueva), Inventario las calcula como antes (15 minutos y 5 días
-- hábiles). No cambia los permisos: Inventario ya actualiza factura_compra (permisos/010).

ALTER TABLE factura_compra
  ADD COLUMN pagar_antes_de DATETIME NULL AFTER fecha,
  ADD COLUMN retirar_hasta  DATE     NULL AFTER pagar_antes_de;

-- Las compras que ya existen: con las reglas de siempre.
--   pagar_antes_de = la fecha de la compra + 15 minutos
--   retirar_hasta  = el 5.º día hábil después de la compra (lunes a viernes): desde un día de semana
--                    es el mismo día de la semana siguiente (+7); desde un sábado, el viernes (+6);
--                    desde un domingo, el viernes (+5).
UPDATE factura_compra
SET pagar_antes_de = fecha + INTERVAL 15 MINUTE,
    retirar_hasta  = DATE(fecha) + INTERVAL (CASE WEEKDAY(fecha) WHEN 5 THEN 6 WHEN 6 THEN 5 ELSE 7 END) DAY
WHERE pagar_antes_de IS NULL;
