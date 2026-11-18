-- Migración 009 (rol 4): vistas de solo lectura para los reportes. Solo usa tablas de las migraciones
-- 001 a 007: las de la tienda (010) llegan después y, si un reporte las necesita, van en otra migración.

-- Turnos atendidos con su consulta, sus ítems y su factura: el reporte "turnos atendidos".
-- Los ítems se cuentan con subconsultas: un JOIN con las dos tablas de ítems multiplicaría las filas.
CREATE VIEW v_turnos_atendidos AS
SELECT
  t.id                 AS turno_id,
  t.fecha              AS fecha,
  t.hora               AS hora,
  t.motivo             AS motivo,
  t.mascota_id         AS mascota_id,
  t.veterinario_id     AS veterinario_id,
  c.id                 AS consulta_id,
  c.diagnostico        AS diagnostico,
  c.finalizada_en      AS finalizada_en,
  (SELECT COUNT(*) FROM item_insumo_consulta i   WHERE i.consulta_id = c.id) AS cantidad_insumos,
  (SELECT COUNT(*) FROM item_producto_consulta p WHERE p.consulta_id = c.id) AS cantidad_productos,
  f.numero             AS factura_numero,
  f.subtotal_base      AS subtotal_base,
  f.subtotal_insumos   AS subtotal_insumos,
  f.subtotal_productos AS subtotal_productos,
  f.total              AS total,
  f.estado             AS factura_estado
FROM turno t
JOIN consulta c          ON c.turno_id    = t.id AND c.estado = 'FINALIZADA'
JOIN factura_consulta f  ON f.consulta_id = c.id
WHERE t.estado = 'ATENDIDO';