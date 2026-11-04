-- Semilla 002 · productos de prueba para el catálogo y el panel del veterinario
-- Ids fijos desde 101. Correr las semillas de nuevo vuelve el stock a estos valores.
-- El 104 no tiene stock y el 107 vence en 20 días (fecha relativa a hoy).

INSERT INTO producto
  (id, nombre, descripcion, precio, stock, categoria, especie_destino, etapa_vida, fecha_vencimiento, activo)
VALUES
  (101, 'Alimento cachorro 3 kg',        'Alimento balanceado para cachorros.',            15999.90, 20, 'ALIMENTO',    'PERRO', 'CACHORRO', NULL, 1),
  (102, 'Alimento perro adulto 15 kg',   'Alimento balanceado para perros adultos.',       48999.00, 12, 'ALIMENTO',    'PERRO', 'ADULTO',   NULL, 1),
  (103, 'Alimento gato adulto 7,5 kg',   'Alimento balanceado para gatos adultos.',        35999.00, 15, 'ALIMENTO',    'GATO',  'ADULTO',   NULL, 1),
  (104, 'Alimento gatito 1,5 kg',        'Alimento para gatitos. Sin stock por ahora.',     9999.00,  0, 'ALIMENTO',    'GATO',  'CACHORRO', NULL, 1),
  (105, 'Snacks dentales',               'Premios que ayudan a la limpieza dental.',        4500.00, 30, 'ALIMENTO',    'TODAS', 'TODAS',    NULL, 1),
  (106, 'Antiparasitario interno perro', 'Comprimidos antiparasitarios para perros.',       7800.00, 25, 'MEDICAMENTO', 'PERRO', 'TODAS',    NULL, 1),
  (107, 'Pipeta antipulgas gato',        'Pipeta contra pulgas y garrapatas para gatos.',   6500.00, 18, 'MEDICAMENTO', 'GATO',  'TODAS',    CURDATE() + INTERVAL 20 DAY, 1),
  (108, 'Antiinflamatorio canino',       'Antiinflamatorio de uso veterinario.',           12300.00, 10, 'MEDICAMENTO', 'PERRO', 'ADULTO',   NULL, 1),
  (109, 'Vitaminas multiespecie',        'Suplemento vitamínico para perros y gatos.',      8900.00, 14, 'MEDICAMENTO', 'TODAS', 'TODAS',    NULL, 1),
  (110, 'Collar ajustable',              'Collar de nylon con hebilla.',                    5200.00, 22, 'ACCESORIO',   'PERRO', 'TODAS',    NULL, 1),
  (111, 'Rascador para gatos',           'Rascador con base y poste de sisal.',            21000.00,  6, 'ACCESORIO',   'GATO',  'TODAS',    NULL, 1),
  (112, 'Comedero de acero inoxidable',  'Comedero apto para perros y gatos.',              6700.00, 30, 'ACCESORIO',   'TODAS', 'TODAS',    NULL, 1),
  (113, 'Correa extensible 5 m',         'Correa retráctil para perros medianos.',         14500.00,  9, 'ACCESORIO',   'PERRO', 'TODAS',    NULL, 1),
  (114, 'Arena sanitaria 4 kg',          'Arena aglomerante para gatos.',                   7400.00, 40, 'ACCESORIO',   'GATO',  'TODAS',    NULL, 1),
  (115, 'Cama acolchada mediana',        'Cama lavable para perros y gatos.',              28900.00,  5, 'ACCESORIO',   'TODAS', 'TODAS',    NULL, 1)
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
