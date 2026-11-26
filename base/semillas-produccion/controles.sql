-- Controles de consistencia del juego de datos de producción (solo lecturas: no cambia nada). Cada
-- fila: el control y cuántos casos con problemas hay (0 = bien). Revisa los datos de las semillas
-- (mascotas 30001 a 30144, productos 3001 a 3030, insumos 3001 a 3017). Para correrlo después de
-- cargar.sh, con el mismo cliente de MySQL:  ... mysql ... "$DB_NAME" < base/semillas-produccion/controles.sql
SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);
SELECT 'vacuna dada sin consulta' c, COUNT(*) n FROM evento_sanitario e WHERE e.mascota_id BETWEEN 30001 AND 30144 AND e.fecha_aplicada IS NOT NULL AND e.consulta_id IS NULL
UNION ALL SELECT 'evento sin plan', COUNT(*) FROM evento_sanitario e WHERE e.mascota_id BETWEEN 30001 AND 30144 AND e.plan_sanitario_id IS NULL
UNION ALL SELECT 'dosis dada sin la anterior', COUNT(*) FROM evento_sanitario e JOIN plan_sanitario p ON p.id = e.plan_sanitario_id
  WHERE e.mascota_id BETWEEN 30001 AND 30144 AND p.orden > 1
    AND NOT EXISTS (SELECT 1 FROM evento_sanitario e2 JOIN plan_sanitario p2 ON p2.id = e2.plan_sanitario_id
                    WHERE e2.mascota_id = e.mascota_id AND p2.aplicacion = p.aplicacion AND p2.especie = p.especie AND p2.orden = p.orden - 1
                      AND e2.fecha_aplicada IS NOT NULL AND (e.fecha_aplicada IS NULL OR e2.fecha_aplicada < e.fecha_aplicada))
UNION ALL SELECT 'días mínimos entre dosis', COUNT(*) FROM evento_sanitario a JOIN plan_sanitario pa ON pa.id = a.plan_sanitario_id
  JOIN evento_sanitario b ON b.mascota_id = a.mascota_id AND b.id <> a.id JOIN plan_sanitario pb ON pb.id = b.plan_sanitario_id
  WHERE a.mascota_id BETWEEN 30001 AND 30144 AND a.fecha_aplicada IS NOT NULL AND b.fecha_aplicada IS NOT NULL
    AND pa.aplicacion = pb.aplicacion AND b.fecha_aplicada < a.fecha_aplicada
    AND DATEDIFF(a.fecha_aplicada, b.fecha_aplicada) < CASE
        WHEN pa.aplicacion IN ('ANTIRRABICA', 'TOS_PERRERAS') THEN 330
        WHEN pa.aplicacion = 'ANTIPARASITARIO' THEN 14
        WHEN pa.repetir_cada_meses IS NOT NULL AND pb.repetir_cada_meses IS NOT NULL THEN 330 ELSE 21 END
UNION ALL SELECT 'vacuna dada antes de nacer o de 4 semanas', COUNT(*) FROM evento_sanitario e JOIN mascota m ON m.id = e.mascota_id
  WHERE e.mascota_id BETWEEN 30001 AND 30144 AND e.fecha_aplicada < m.fecha_nacimiento + INTERVAL 28 DAY
UNION ALL SELECT 'dosis dada en consulta sin el insumo', COUNT(*) FROM evento_sanitario e JOIN plan_sanitario p ON p.id = e.plan_sanitario_id
  WHERE e.consulta_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM item_insumo_consulta i JOIN insumo ins ON ins.id = i.insumo_id
                                                 WHERE i.consulta_id = e.consulta_id AND ins.aplicacion = p.aplicacion)
UNION ALL SELECT 'dosis dada en otra fecha que su consulta', COUNT(*) FROM evento_sanitario e JOIN consulta c ON c.id = e.consulta_id
  WHERE e.fecha_aplicada <> DATE(c.finalizada_en)
UNION ALL SELECT 'turno atendido sin consulta', COUNT(*) FROM turno t JOIN mascota m ON m.id = t.mascota_id
  WHERE t.mascota_id BETWEEN 30001 AND 30144 AND t.estado = 'ATENDIDO' AND NOT EXISTS (SELECT 1 FROM consulta c WHERE c.turno_id = t.id)
UNION ALL SELECT 'consulta de un turno no atendido', COUNT(*) FROM consulta c JOIN turno t ON t.id = c.turno_id
  WHERE t.mascota_id BETWEEN 30001 AND 30144 AND t.estado <> 'ATENDIDO' AND c.estado = 'FINALIZADA'
UNION ALL SELECT 'consulta atendida en el futuro', COUNT(*) FROM consulta c JOIN turno t ON t.id = c.turno_id
  WHERE t.mascota_id BETWEEN 30001 AND 30144 AND t.fecha > @hoy
UNION ALL SELECT 'turno programado en el pasado', COUNT(*) FROM turno t WHERE t.mascota_id BETWEEN 30001 AND 30144 AND t.estado = 'PROGRAMADO' AND t.fecha < @hoy
UNION ALL SELECT 'turno en domingo (no cancelado)', COUNT(*) FROM turno t WHERE t.mascota_id BETWEEN 30001 AND 30144 AND DAYOFWEEK(t.fecha) = 1 AND t.estado <> 'CANCELADO'
UNION ALL SELECT 'consulta sin factura', COUNT(*) FROM consulta c JOIN turno t ON t.id = c.turno_id
  WHERE t.mascota_id BETWEEN 30001 AND 30144 AND c.estado = 'FINALIZADA' AND NOT EXISTS (SELECT 1 FROM factura_consulta f WHERE f.consulta_id = c.id)
UNION ALL SELECT 'factura que no suma', COUNT(*) FROM factura_consulta f
  WHERE f.consulta_id BETWEEN 30001 AND 30844 AND (f.total <> f.subtotal_base + f.subtotal_insumos + f.subtotal_productos
     OR f.subtotal_insumos <> COALESCE((SELECT SUM(cantidad * costo_unitario) FROM item_insumo_consulta WHERE consulta_id = f.consulta_id), 0)
     OR f.subtotal_productos <> COALESCE((SELECT SUM(cantidad * precio_unitario) FROM item_producto_consulta WHERE consulta_id = f.consulta_id), 0))
UNION ALL SELECT 'vacunación sin evento en su motivo', COUNT(*) FROM turno_motivo tm JOIN turno t ON t.id = tm.turno_id
  WHERE t.mascota_id BETWEEN 30001 AND 30144 AND tm.motivo IN ('VACUNACION', 'DESPARASITACION') AND tm.evento_sanitario_id IS NULL
UNION ALL SELECT 'turno sin motivos', COUNT(*) FROM turno t WHERE t.mascota_id BETWEEN 30001 AND 30144 AND NOT EXISTS (SELECT 1 FROM turno_motivo tm WHERE tm.turno_id = t.id)
UNION ALL SELECT 'adopción finalizada sin chequeo atendido con consulta', COUNT(*) FROM adopcion a
  WHERE a.id BETWEEN 30001 AND 30044 AND a.estado = 'FINALIZADA'
    AND NOT EXISTS (SELECT 1 FROM turno t JOIN consulta c ON c.turno_id = t.id WHERE t.id = a.turno_chequeo_id AND t.estado = 'ATENDIDO')
UNION ALL SELECT 'mascota adoptada que no es del adoptante', COUNT(*) FROM adopcion a JOIN publicacion pu ON pu.id = a.publicacion_id
  JOIN mascota m ON m.id = pu.mascota_id WHERE a.estado = 'FINALIZADA' AND m.duenio_id <> a.adoptante_id
UNION ALL SELECT 'adoptante sin su postulación elegida', COUNT(*) FROM adopcion a
  -- (una adopción cancelada deja todas las postulaciones rechazadas, también la elegida)
  WHERE a.adoptante_id IS NOT NULL AND a.estado <> 'CANCELADA' AND NOT EXISTS (SELECT 1 FROM postulacion p WHERE p.adopcion_id = a.id AND p.cliente_id = a.adoptante_id AND p.estado = 'ELEGIDA')
UNION ALL SELECT 'chequeo de adopción de alguien sin adopción', COUNT(*) FROM turno t JOIN turno_motivo tm ON tm.turno_id = t.id AND tm.motivo = 'CHEQUEO_ADOPCION'
  WHERE t.estado <> 'CANCELADO' AND NOT EXISTS (SELECT 1 FROM adopcion a WHERE a.turno_chequeo_id = t.id)
UNION ALL SELECT 'publicación que dice vacunas al día', COUNT(*) FROM publicacion WHERE id BETWEEN 30001 AND 30044 AND descripcion LIKE '%vacunas al día%'
UNION ALL SELECT 'compra con pago sin plazo de retiro', COUNT(*) FROM factura_compra WHERE id BETWEEN 30001 AND 30150 AND (motivo_cancelacion IS NULL OR motivo_cancelacion <> 'SIN_PAGO') AND retirar_hasta IS NULL
UNION ALL SELECT 'compra para retirar vencida', COUNT(*) FROM factura_compra WHERE id BETWEEN 30001 AND 30150 AND estado = 'PAGADA' AND retirar_hasta < @hoy
UNION ALL SELECT 'entregada después del plazo', COUNT(*) FROM factura_compra WHERE estado = 'ENTREGADA' AND DATE(entregada_en) > retirar_hasta
UNION ALL SELECT 'stock de producto que no cierra con movimientos', COUNT(*) FROM producto p WHERE p.id BETWEEN 3001 AND 3030 AND p.stock <>
  (SELECT COALESCE(SUM(IF(m.tipo = 'ENTRADA', m.cantidad, -m.cantidad)), 0) FROM movimiento_inventario m WHERE m.producto_id = p.id)
UNION ALL SELECT 'stock de insumo que no cierra con movimientos', COUNT(*) FROM insumo i WHERE i.id BETWEEN 3001 AND 3017 AND i.stock <>
  (SELECT COALESCE(SUM(IF(m.tipo = 'ENTRADA', m.cantidad, -m.cantidad)), 0) FROM movimiento_inventario m WHERE m.insumo_id = i.id)
UNION ALL SELECT 'stock de producto que no es la suma de lotes', COUNT(*) FROM producto p WHERE p.id BETWEEN 3001 AND 3030
  AND p.stock <> (SELECT COALESCE(SUM(stock), 0) FROM lote_producto WHERE producto_id = p.id)
UNION ALL SELECT 'stock de insumo que no es la suma de lotes', COUNT(*) FROM insumo i WHERE i.id BETWEEN 3001 AND 3017
  AND i.stock <> (SELECT COALESCE(SUM(stock), 0) FROM lote_insumo WHERE insumo_id = i.id)
UNION ALL SELECT 'lote con stock que no sigue vence', (SELECT COUNT(*) FROM lote_producto l JOIN producto p ON p.id = l.producto_id
  WHERE p.id BETWEEN 3001 AND 3030 AND l.stock > 0 AND (l.vencimiento IS NOT NULL) <> p.vence)
  + (SELECT COUNT(*) FROM lote_insumo l JOIN insumo i ON i.id = l.insumo_id WHERE i.id BETWEEN 3001 AND 3017 AND l.stock > 0 AND (l.vencimiento IS NOT NULL) <> i.vence)
UNION ALL SELECT 'lote sin número', (SELECT COUNT(*) FROM lote_producto WHERE numero IS NULL) + (SELECT COUNT(*) FROM lote_insumo WHERE numero IS NULL)
UNION ALL SELECT 'movimiento de semilla sin lote', COUNT(*) FROM movimiento_inventario
  WHERE (id_operacion LIKE 'prod-%' OR id_operacion LIKE 'consulta-30%') AND ((producto_id IS NOT NULL AND lote_id IS NULL) OR (insumo_id IS NOT NULL AND lote_insumo_id IS NULL))
UNION ALL SELECT 'consulta sin su movimiento de stock', COUNT(*) FROM item_insumo_consulta i
  WHERE i.consulta_id BETWEEN 30001 AND 30844 AND NOT EXISTS (SELECT 1 FROM movimiento_inventario m WHERE m.id_operacion = CONCAT('consulta-', i.consulta_id, '-insumo-', i.insumo_id))
UNION ALL SELECT 'foto de mascota repetida', COUNT(*) - COUNT(DISTINCT MD5(foto)) FROM mascota WHERE id BETWEEN 30001 AND 30144 AND foto IS NOT NULL
UNION ALL SELECT 'mascota sin foto', COUNT(*) FROM mascota WHERE (id BETWEEN 30001 AND 30084 OR id BETWEEN 30101 AND 30144) AND foto IS NULL
UNION ALL SELECT 'foto de producto repetida', COUNT(*) - COUNT(DISTINCT MD5(imagen)) FROM producto WHERE id BETWEEN 3001 AND 3030 AND imagen IS NOT NULL
UNION ALL SELECT 'foto de producto igual a la de una mascota', COUNT(*) FROM producto p JOIN mascota m ON MD5(m.foto) = MD5(p.imagen) WHERE p.id BETWEEN 3001 AND 3030
UNION ALL SELECT 'publicación con otra foto que su mascota', COUNT(*) FROM publicacion pu JOIN mascota m ON m.id = pu.mascota_id WHERE pu.id BETWEEN 30001 AND 30044 AND MD5(pu.foto) <> MD5(m.foto)
UNION ALL SELECT 'reseña de alguien sin consulta antes', COUNT(*) FROM resena r WHERE r.id BETWEEN 30001 AND 30022
  AND NOT EXISTS (SELECT 1 FROM consulta c JOIN turno t ON t.id = c.turno_id JOIN mascota m ON m.id = t.mascota_id
                  WHERE m.duenio_id = r.autor_id AND c.finalizada_en < r.creada_en)
UNION ALL SELECT 'aviso futuro', COUNT(*) FROM notificacion WHERE id_operacion LIKE 'prod-aviso-%' AND creada_en > UTC_TIMESTAMP() - INTERVAL 3 HOUR
UNION ALL SELECT 'insumo de calendario repetido activo', COUNT(*) - COUNT(DISTINCT aplicacion) FROM insumo WHERE activo = 1 AND aplicacion IS NOT NULL;
