-- Semilla 002 · productos de prueba para el catálogo y el panel del veterinario
-- Ids fijos desde 101. Correr las semillas de nuevo vuelve el stock a estos valores.
-- El 104 no tiene stock y el 107 vence en 20 días (fecha relativa a hoy).

INSERT INTO producto
  (id, nombre, descripcion, precio, stock, categoria, especie_destino, etapa_vida, fecha_vencimiento, activo)
VALUES
  (101, 'Alimento Royal Canin Medium Puppy para cachorros 3 kg', 'Alimento balanceado para cachorros de razas medianas, de 2 a 12 meses.', 15999.90, 20, 'ALIMENTO',    'PERRO', 'CACHORRO', NULL, 1),
  (102, 'Alimento Pro Plan Perro Adulto Raza Mediana 15 kg', 'Alimento balanceado para perros adultos de razas medianas.', 48999.00, 12, 'ALIMENTO',    'PERRO', 'ADULTO',   NULL, 1),
  (103, 'Alimento Excellent Gato Adulto Pollo y Arroz 7,5 kg', 'Alimento balanceado para gatos adultos, sabor pollo y arroz.', 35999.00, 15, 'ALIMENTO',    'GATO',  'ADULTO',   NULL, 1),
  (104, 'Alimento Royal Canin Kitten para gatitos 1,5 kg', 'Alimento para gatitos de 4 a 12 meses. Sin stock por ahora.', 9999.00,  0, 'ALIMENTO',    'GATO',  'CACHORRO', NULL, 1),
  (105, 'Snacks dentales Pedigree Dentastix para perros x 7', 'Premios que ayudan a la limpieza dental. Paquete de 7 unidades.', 4500.00, 30, 'ALIMENTO',    'TODAS', 'TODAS',    NULL, 1),
  (106, 'Antiparasitario interno Total Full para perros x 4 comprimidos', 'Comprimidos antiparasitarios internos para perros.', 7800.00, 25, 'MEDICAMENTO', 'PERRO', 'TODAS',    NULL, 1),
  (107, 'Pipeta antipulgas Frontline Plus para gatos', 'Pipeta contra pulgas y garrapatas para gatos.', 6500.00, 18, 'MEDICAMENTO', 'GATO',  'TODAS',    CURDATE() + INTERVAL 20 DAY, 1),
  (108, 'Antiinflamatorio Meloxivet para perros x 10 comprimidos', 'Antiinflamatorio de uso veterinario (meloxicam).', 12300.00, 10, 'MEDICAMENTO', 'PERRO', 'ADULTO',   NULL, 1),
  (109, 'Vitaminas Vitamix para perros y gatos x 60 comprimidos', 'Suplemento vitamínico para perros y gatos.', 8900.00, 14, 'MEDICAMENTO', 'TODAS', 'TODAS',    NULL, 1),
  (110, 'Collar de nylon ajustable con hebilla talle M', 'Collar de nylon con hebilla, ajustable, para perros medianos.', 5200.00, 22, 'ACCESORIO',   'PERRO', 'TODAS',    NULL, 1),
  (111, 'Rascador para gatos con poste de sisal 60 cm', 'Rascador con base y poste de sisal de 60 cm de alto.', 21000.00,  6, 'ACCESORIO',   'GATO',  'TODAS',    NULL, 1),
  (112, 'Comedero de acero inoxidable 500 ml', 'Comedero de acero inoxidable apto para perros y gatos.', 6700.00, 30, 'ACCESORIO',   'TODAS', 'TODAS',    NULL, 1),
  (113, 'Correa extensible Flexi 5 m (hasta 25 kg)', 'Correa retráctil de 5 m para perros de hasta 25 kg.', 14500.00,  9, 'ACCESORIO',   'PERRO', 'TODAS',    NULL, 1),
  (114, 'Arena sanitaria aglomerante Piedritas 4 kg', 'Arena aglomerante para gatos.', 7400.00, 40, 'ACCESORIO',   'GATO',  'TODAS',    NULL, 1),
  (115, 'Cama acolchada lavable mediana 60 x 50 cm', 'Cama acolchada y lavable para perros y gatos, de 60 x 50 cm.', 28900.00,  5, 'ACCESORIO',   'TODAS', 'TODAS',    NULL, 1)
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre),
  descripcion = VALUES(descripcion),
  precio = VALUES(precio),
  stock = VALUES(stock),
  categoria = VALUES(categoria),
  especie_destino = VALUES(especie_destino),
  etapa_vida = VALUES(etapa_vida),
  fecha_vencimiento = VALUES(fecha_vencimiento),
  activo = VALUES(activo);
