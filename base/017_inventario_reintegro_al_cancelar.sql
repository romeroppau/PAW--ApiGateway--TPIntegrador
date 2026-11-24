-- Migración 017 · módulo Inventario (tienda)
-- Reintegro cuando el comprador cancela un pedido ya pagado: si cancela con anticipación (48 horas o
-- más antes del final del último día para retirar) se le devuelve el 75 % de lo que pagó; si cancela
-- después, el 50 %. Si no lo retira a tiempo, nada. Los porcentajes y las horas los configura la
-- veterinaria (configuración, migración 014).
--
-- 1) La política de cada compra, guardada al confirmarse (como los plazos de la migración 015): si la
--    veterinaria la cambia, a las compras que ya existen no se les cambia lo prometido.
--      reintegro_anticipado, reintegro_ultimo_momento: porcentajes (0 a 100)
--      reintegro_horas: cuántas horas antes es "con anticipación"
--    NULL: la compra se confirmó antes de esta migración. Inventario usa los valores por defecto
--    (75 %, 50 % y 48 horas): a esos compradores se les prometió "sin reintegro", así que es a favor.
--
-- 2) El reintegro de una compra cancelada por el comprador:
--      reintegro_porcentaje: el que le tocó (según cuándo canceló)
--      reintegro_monto:      cuánto se le devuelve (el total por el porcentaje)
--      reintegro_estado:     PENDIENTE (todavía no se pudo hacer en Mercado Pago: la tarea programada
--                            lo reintenta) o HECHO; NULL si no hay nada que devolver
--      reintegro_en:         cuándo se hizo
--
-- No cambia los permisos: Inventario ya actualiza factura_compra (permisos/010).

ALTER TABLE factura_compra
  ADD COLUMN reintegro_anticipado     TINYINT UNSIGNED NULL AFTER retirar_hasta,
  ADD COLUMN reintegro_ultimo_momento TINYINT UNSIGNED NULL AFTER reintegro_anticipado,
  ADD COLUMN reintegro_horas          SMALLINT UNSIGNED NULL AFTER reintegro_ultimo_momento,
  ADD COLUMN reintegro_porcentaje     TINYINT UNSIGNED NULL AFTER cancelada_en,
  ADD COLUMN reintegro_monto          DECIMAL(10,2) NULL AFTER reintegro_porcentaje,
  ADD COLUMN reintegro_estado         ENUM('PENDIENTE','HECHO') NULL AFTER reintegro_monto,
  ADD COLUMN reintegro_en             DATETIME NULL AFTER reintegro_estado,
  ADD CONSTRAINT ck_factura_reintegro_politica CHECK (
    (reintegro_anticipado IS NULL OR reintegro_anticipado <= 100)
    AND (reintegro_ultimo_momento IS NULL OR reintegro_ultimo_momento <= 100)
  ),
  ADD CONSTRAINT ck_factura_reintegro CHECK (
    (reintegro_porcentaje IS NULL OR reintegro_porcentaje <= 100)
    AND (reintegro_monto IS NULL OR (reintegro_monto >= 0 AND reintegro_monto <= total))
  );

-- Para que la tarea programada encuentre rápido los reintegros que faltan hacer.
CREATE INDEX ix_factura_reintegro_estado ON factura_compra (reintegro_estado);
