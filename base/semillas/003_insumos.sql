-- Semilla 003 · insumos de prueba para el ABM de insumos y la consulta
-- Ids fijos desde 101. Correr las semillas de nuevo vuelve el stock y el estado a estos valores.
-- El 107 está en falta (sin stock), el 108 tiene stock bajo (3) y el 109 está dado de baja.
-- El estado se calcula según el stock: 0 → EN_FALTA, más de 0 → DISPONIBLE (YA_PEDIDO no se usa).
-- Migración 025: las vacunas y el antiparasitario dicen qué aplicación del calendario son. La
-- leucemia felina (191) está sin stock, para probar la carga de stock desde la consulta. Las tres
-- nuevas usan ids desde 190, lejos de los que se crean a mano en dev.
-- Migración 029: vence = 1 en lo que tiene vencimiento (las vacunas, el antiparasitario y el material
-- estéril o líquido: jeringas, gasas, sutura, solución), con su fecha; los guantes y la venda no vencen.
-- El stock va a los lotes con la semilla 013.

INSERT INTO insumo
  (id, nombre, aplicacion, stock, fecha_vencimiento, vence, costo, estado, activo)
VALUES
  (101, 'Jeringa descartable 3 ml',           NULL,              200, CURDATE() + INTERVAL 700 DAY, 1,   150.00, 'DISPONIBLE', 1),
  (102, 'Guantes de látex (par)',             NULL,              150, NULL,                         0,   220.00, 'DISPONIBLE', 1),
  (103, 'Gasa estéril 10 x 10',               NULL,              100, CURDATE() + INTERVAL 500 DAY, 1,   180.00, 'DISPONIBLE', 1),
  (104, 'Vacuna séxtuple canina (dosis)',     'SEXTUPLE',         25, CURDATE() + INTERVAL 150 DAY, 1,  6500.00, 'DISPONIBLE', 1),
  (105, 'Vacuna triple felina (dosis)',       'TRIPLE_FELINA',    20, CURDATE() + INTERVAL 160 DAY, 1,  7200.00, 'DISPONIBLE', 1),
  (106, 'Vacuna antirrábica (dosis)',         'ANTIRRABICA',      30, CURDATE() + INTERVAL 170 DAY, 1,  3800.00, 'DISPONIBLE', 1),
  (107, 'Sutura absorbible 3-0',              NULL,                0, NULL,                         1,  2500.00, 'EN_FALTA',   1),
  (108, 'Solución fisiológica 500 ml',        NULL,                3, CURDATE() + INTERVAL 400 DAY, 1,  1900.00, 'DISPONIBLE', 1),
  (109, 'Venda elástica 5 cm',                NULL,               10, NULL,                         0,   900.00, 'DISPONIBLE', 0),
  (190, 'Vacuna tos de las perreras (dosis)', 'TOS_PERRERAS',      8, CURDATE() + INTERVAL 180 DAY, 1,  9400.00, 'DISPONIBLE', 1),
  (191, 'Vacuna leucemia felina (dosis)',     'LEUCEMIA_FELINA',   0, NULL,                         1,  9800.00, 'EN_FALTA',   1),
  (192, 'Antiparasitario interno (dosis)',    'ANTIPARASITARIO',  40, CURDATE() + INTERVAL 365 DAY, 1,  2500.00, 'DISPONIBLE', 1)
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre),
  aplicacion = VALUES(aplicacion),
  stock = VALUES(stock),
  fecha_vencimiento = VALUES(fecha_vencimiento),
  vence = VALUES(vence),
  costo = VALUES(costo),
  estado = VALUES(estado),
  activo = VALUES(activo);

-- La migración 025 crea con stock 0 el insumo de cada aplicación que falte (en una base nueva, todos): se borran los
-- que no se usaron, para que no queden repetidos con los de arriba (primero sus lotes vacíos, de la 029).
DELETE l FROM lote_insumo l JOIN insumo i ON i.id = l.insumo_id
WHERE i.aplicacion IS NOT NULL AND i.id NOT IN (104, 105, 106, 190, 191, 192) AND l.stock = 0
  AND NOT EXISTS (SELECT 1 FROM movimiento_inventario m WHERE m.insumo_id = i.id)
  AND NOT EXISTS (SELECT 1 FROM item_insumo_consulta c WHERE c.insumo_id = i.id);
DELETE FROM insumo
WHERE aplicacion IS NOT NULL AND id NOT IN (104, 105, 106, 190, 191, 192)
  AND NOT EXISTS (SELECT 1 FROM movimiento_inventario m WHERE m.insumo_id = insumo.id)
  AND NOT EXISTS (SELECT 1 FROM item_insumo_consulta c WHERE c.insumo_id = insumo.id);
