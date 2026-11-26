-- Producción 002 · productos e insumos con nombres, marcas y precios reales
--   Productos 3001 a 3030: 3001 a 3006 vencen en los próximos 6 a 27 días (salen en "Qué liquidar"),
--   3007 a 3012 tienen stock bajo (de 0 a 6) y el resto, stock normal. La foto de cada uno (una
--   distinta por producto) la pone 004.
--   Insumos 3001 a 3017: los de una veterinaria (jeringas, vacunas, gasas, antiparasitario); uno en
--   falta y dos con stock bajo.
--   Migración 029: vencen los productos con fecha (alimentos y medicamentos) y los insumos estériles,
--   líquidos y las vacunas, con su fecha; los accesorios, los guantes, el algodón y la venda no.
--   Los productos y los insumos que ya había (de la Entrega 4, algunos repetidos) se dan de baja: no
--   se borran, pero dejan de verse en la tienda y en las listas.
-- Correr de nuevo vuelve stock, precio y vencimiento a estos valores.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);

UPDATE producto SET activo = 0 WHERE id < 3001 AND activo = 1;
UPDATE insumo SET activo = 0 WHERE id < 3001 AND activo = 1;


INSERT INTO producto
  (id, nombre, descripcion, precio, stock, categoria, especie_destino, etapa_vida, fecha_vencimiento, activo)
VALUES
  (3001, 'Pipeta antipulgas Frontline Plus para gatos', 'Pipeta contra pulgas, garrapatas y piojos para gatos. Protege hasta 4 semanas. Una pipeta.', 9800.00, 14, 'MEDICAMENTO', 'GATO', 'TODAS', @hoy + INTERVAL 6 DAY, 1),
  (3002, 'Pipeta Revolution para gatos de 2,6 a 7,5 kg', 'Antiparasitario externo e interno de amplio espectro para gatos. Una pipeta.', 11200.00, 9, 'MEDICAMENTO', 'GATO', 'TODAS', @hoy + INTERVAL 12 DAY, 1),
  (3003, 'Alimento húmedo Whiskas pouch sabor carne x 85 g', 'Alimento completo para gatos adultos, en sobre individual.', 1150.00, 48, 'ALIMENTO', 'GATO', 'ADULTO', @hoy + INTERVAL 9 DAY, 1),
  (3004, 'Snacks dentales Pedigree Dentastix razas medianas x 7', 'Premios que ayudan a reducir el sarro. Paquete de 7 unidades.', 5200.00, 22, 'ALIMENTO', 'PERRO', 'ADULTO', @hoy + INTERVAL 15 DAY, 1),
  (3005, 'Shampoo antipulgas Osspret para perros y gatos 250 ml', 'Shampoo con piretrinas para el baño de perros y gatos de más de 3 meses.', 6900.00, 11, 'MEDICAMENTO', 'TODAS', 'TODAS', @hoy + INTERVAL 21 DAY, 1),
  (3006, 'Vitaminas Vitamix para perros y gatos x 60 comprimidos', 'Suplemento vitamínico y mineral para perros y gatos.', 10400.00, 8, 'MEDICAMENTO', 'TODAS', 'TODAS', @hoy + INTERVAL 27 DAY, 1),
  (3007, 'Alimento Royal Canin Mini Adult 7,5 kg', 'Alimento balanceado para perros adultos de razas pequeñas (hasta 10 kg).', 58900.00, 3, 'ALIMENTO', 'PERRO', 'ADULTO', @hoy + INTERVAL 263 DAY, 1),
  (3008, 'Alimento Royal Canin Kitten para gatitos 1,5 kg', 'Alimento para gatitos de 4 a 12 meses, para un crecimiento sano.', 18900.00, 0, 'ALIMENTO', 'GATO', 'CACHORRO', @hoy + INTERVAL 272 DAY, 1),
  (3009, 'Antiparasitario interno Total Full para perros de hasta 10 kg x 2', 'Comprimidos palatables contra parásitos internos. Dosis única.', 6400.00, 5, 'MEDICAMENTO', 'PERRO', 'TODAS', @hoy + INTERVAL 281 DAY, 1),
  (3010, 'Rascador para gatos con poste de sisal 60 cm', 'Rascador con base de madera y poste de sisal natural de 60 cm.', 24900.00, 2, 'ACCESORIO', 'GATO', 'TODAS', NULL, 1),
  (3011, 'Cama acolchada lavable mediana 60 x 50 cm', 'Cama con relleno siliconado y funda desmontable lavable.', 31500.00, 4, 'ACCESORIO', 'TODAS', 'TODAS', NULL, 1),
  (3012, 'Correa extensible Flexi 5 m para perros de hasta 25 kg', 'Correa retráctil con freno y bloqueo de una mano.', 16800.00, 6, 'ACCESORIO', 'PERRO', 'TODAS', NULL, 1),
  (3013, 'Alimento Royal Canin Medium Puppy 15 kg', 'Alimento para cachorros de razas medianas, de 2 a 12 meses.', 112000.00, 12, 'ALIMENTO', 'PERRO', 'CACHORRO', @hoy + INTERVAL 317 DAY, 1),
  (3014, 'Alimento Pro Plan Adulto razas medianas 15 kg', 'Alimento balanceado para perros adultos de 10 a 25 kg, con pollo.', 98500.00, 10, 'ALIMENTO', 'PERRO', 'ADULTO', @hoy + INTERVAL 326 DAY, 1),
  (3015, 'Alimento Eukanuba Senior razas medianas 3 kg', 'Alimento para perros de más de 7 años, con glucosamina.', 27800.00, 9, 'ALIMENTO', 'PERRO', 'SENIOR', @hoy + INTERVAL 335 DAY, 1),
  (3016, 'Alimento Excellent Gato Adulto pollo y arroz 7,5 kg', 'Alimento balanceado para gatos adultos, sabor pollo y arroz.', 46900.00, 15, 'ALIMENTO', 'GATO', 'ADULTO', @hoy + INTERVAL 344 DAY, 1),
  (3017, 'Alimento Royal Canin Sterilised 37 para gatos 2 kg', 'Alimento para gatos castrados, ayuda a mantener el peso.', 33400.00, 11, 'ALIMENTO', 'GATO', 'ADULTO', @hoy + INTERVAL 353 DAY, 1),
  (3018, 'Alimento Old Prince cordero y arroz adulto 15 kg', 'Alimento súper premium para perros adultos, con cordero.', 71200.00, 8, 'ALIMENTO', 'PERRO', 'ADULTO', @hoy + INTERVAL 362 DAY, 1),
  (3019, 'Antiinflamatorio Meloxivet 2 mg x 10 comprimidos', 'Antiinflamatorio y analgésico (meloxicam). Venta bajo indicación veterinaria.', 13900.00, 18, 'MEDICAMENTO', 'PERRO', 'ADULTO', @hoy + INTERVAL 371 DAY, 1),
  (3020, 'Antibiótico Amoxicilina veterinaria 250 mg x 10 comprimidos', 'Antibiótico de amplio espectro. Venta bajo indicación veterinaria.', 8700.00, 20, 'MEDICAMENTO', 'TODAS', 'TODAS', @hoy + INTERVAL 380 DAY, 1),
  (3021, 'Desparasitante Drontal para gatos x 2 comprimidos', 'Antiparasitario interno para gatos. Un comprimido cada 4 kg.', 7600.00, 25, 'MEDICAMENTO', 'GATO', 'TODAS', @hoy + INTERVAL 389 DAY, 1),
  (3022, 'Collar de nylon ajustable con hebilla talle M', 'Collar resistente para perros medianos, de 35 a 50 cm.', 6200.00, 30, 'ACCESORIO', 'PERRO', 'TODAS', NULL, 1),
  (3023, 'Pretal acolchado con correa talle S', 'Pretal ajustable con acolchado y correa de 1,2 m, para perros chicos.', 15400.00, 14, 'ACCESORIO', 'PERRO', 'TODAS', NULL, 1),
  (3024, 'Comedero de acero inoxidable 500 ml', 'Comedero con base de goma antideslizante, apto lavavajillas.', 7900.00, 26, 'ACCESORIO', 'TODAS', 'TODAS', NULL, 1),
  (3025, 'Pelota de goma maciza 7 cm', 'Pelota resistente para morder y buscar. Flota en el agua.', 4300.00, 40, 'ACCESORIO', 'PERRO', 'TODAS', NULL, 1),
  (3026, 'Soga de algodón para tirar 30 cm', 'Juguete de algodón trenzado: ayuda a la limpieza de los dientes.', 5100.00, 33, 'ACCESORIO', 'PERRO', 'TODAS', NULL, 1),
  (3027, 'Ratones de peluche con catnip x 2', 'Juguetes livianos con hierba gatera para estimular el juego.', 3600.00, 35, 'ACCESORIO', 'GATO', 'TODAS', NULL, 1),
  (3028, 'Arena sanitaria aglomerante Piedritas 4 kg', 'Arena de bentonita que forma bolitas firmes y controla el olor.', 8900.00, 45, 'ACCESORIO', 'GATO', 'TODAS', NULL, 1),
  (3029, 'Transportadora para gatos y perros chicos', 'Transportadora rígida con puerta de reja, hasta 8 kg.', 42600.00, 7, 'ACCESORIO', 'TODAS', 'TODAS', NULL, 1),
  (3030, 'Chapita identificatoria grabada', 'Chapita de aluminio con el nombre y el teléfono, grabada en el momento.', 5900.00, 50, 'ACCESORIO', 'TODAS', 'TODAS', NULL, 1)
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre), descripcion = VALUES(descripcion), precio = VALUES(precio), stock = VALUES(stock),
  categoria = VALUES(categoria), especie_destino = VALUES(especie_destino), etapa_vida = VALUES(etapa_vida),
  fecha_vencimiento = VALUES(fecha_vencimiento),
  activo = VALUES(activo);


-- Insumos: con la vacuna o el antiparasitario del calendario que son (aplicacion, migración 025). El
-- 3016 (antiparasitario interno) y el 3017 (leucemia felina) son los que usan las consultas de
-- desparasitación y el calendario de los gatos.
INSERT INTO insumo (id, nombre, stock, costo, estado, activo)
VALUES
  (3001, 'Jeringa descartable 3 ml', 300, 160.00, 'DISPONIBLE', 1),
  (3002, 'Jeringa descartable 5 ml', 250, 190.00, 'DISPONIBLE', 1),
  (3003, 'Aguja descartable 21G', 400, 60.00, 'DISPONIBLE', 1),
  (3004, 'Guantes de látex (par)', 180, 240.00, 'DISPONIBLE', 1),
  (3005, 'Gasa estéril 10 x 10', 120, 200.00, 'DISPONIBLE', 1),
  (3006, 'Algodón hidrófilo 500 g', 12, 2900.00, 'DISPONIBLE', 1),
  (3007, 'Alcohol al 70 % 1 L', 8, 4200.00, 'DISPONIBLE', 1),
  (3008, 'Clorhexidina al 2 % 500 ml', 9, 5600.00, 'DISPONIBLE', 1),
  (3009, 'Vacuna séxtuple canina (dosis)', 40, 7200.00, 'DISPONIBLE', 1),
  (3010, 'Vacuna triple felina (dosis)', 25, 8100.00, 'DISPONIBLE', 1),
  (3011, 'Vacuna antirrábica (dosis)', 50, 4300.00, 'DISPONIBLE', 1),
  (3012, 'Vacuna tos de las perreras (dosis)', 6, 9400.00, 'DISPONIBLE', 1),
  (3013, 'Sutura absorbible 3-0', 0, 2900.00, 'EN_FALTA', 1),
  (3014, 'Solución fisiológica 500 ml', 24, 2100.00, 'DISPONIBLE', 1),
  (3015, 'Venda cohesiva 5 cm', 18, 1300.00, 'DISPONIBLE', 1),
  (3016, 'Antiparasitario interno (dosis)', 35, 2600.00, 'DISPONIBLE', 1),
  (3017, 'Vacuna leucemia felina (dosis)', 12, 9900.00, 'DISPONIBLE', 1)
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre), stock = VALUES(stock), costo = VALUES(costo), estado = VALUES(estado), activo = VALUES(activo);

UPDATE insumo SET aplicacion = CASE id WHEN 3009 THEN 'SEXTUPLE' WHEN 3010 THEN 'TRIPLE_FELINA' WHEN 3011 THEN 'ANTIRRABICA'
  WHEN 3012 THEN 'TOS_PERRERAS' WHEN 3016 THEN 'ANTIPARASITARIO' WHEN 3017 THEN 'LEUCEMIA_FELINA' ELSE NULL END
WHERE id BETWEEN 3001 AND 3017;
-- La migración 025 creó, con stock 0, un insumo por cada aplicación que faltaba: con los de arriba
-- quedarían repetidos en la consulta. Se dan de baja (no se borran) los que nunca tuvieron stock.
UPDATE insumo i SET i.activo = 0
WHERE i.id > 3017 AND i.aplicacion IS NOT NULL AND i.stock = 0
  AND NOT EXISTS (SELECT 1 FROM (SELECT insumo_id FROM movimiento_inventario WHERE insumo_id IS NOT NULL) m WHERE m.insumo_id = i.id);

-- Si vence y hasta cuándo (migración 029). Los lotes los arma 009_lotes.sql.
UPDATE producto SET vence = (fecha_vencimiento IS NOT NULL) WHERE id BETWEEN 3001 AND 3030;
UPDATE insumo SET
  vence = id NOT IN (3004, 3006, 3015),
  fecha_vencimiento = CASE id
    WHEN 3001 THEN @hoy + INTERVAL 700 DAY WHEN 3002 THEN @hoy + INTERVAL 690 DAY
    WHEN 3003 THEN @hoy + INTERVAL 800 DAY WHEN 3005 THEN @hoy + INTERVAL 500 DAY
    WHEN 3007 THEN @hoy + INTERVAL 600 DAY WHEN 3008 THEN @hoy + INTERVAL 400 DAY
    WHEN 3009 THEN @hoy + INTERVAL 150 DAY WHEN 3010 THEN @hoy + INTERVAL 160 DAY
    WHEN 3011 THEN @hoy + INTERVAL 170 DAY WHEN 3012 THEN @hoy + INTERVAL 180 DAY
    -- La sutura está en falta: la fecha es la de su último lote, que quedó vacío (009 lo crea así).
    WHEN 3013 THEN @hoy + INTERVAL 250 DAY
    WHEN 3014 THEN @hoy + INTERVAL 420 DAY WHEN 3016 THEN @hoy + INTERVAL 300 DAY
    WHEN 3017 THEN @hoy + INTERVAL 190 DAY ELSE NULL END
WHERE id BETWEEN 3001 AND 3017;

-- Los movimientos de stock (las cargas, las ventas y lo que usaron las consultas) los arma
-- 010_movimientos.sql al final, para que sumen exactamente el stock de arriba.
