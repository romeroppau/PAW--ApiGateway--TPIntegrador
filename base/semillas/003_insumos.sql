-- Semilla 003 · insumos de prueba para el ABM de insumos y la consulta
-- Ids fijos desde 101. Correr las semillas de nuevo vuelve el stock y el estado a estos valores.
-- El 107 está en falta (sin stock), el 108 ya se pidió y el 109 está dado de baja.

INSERT INTO insumo
  (id, nombre, stock, costo, estado, activo)
VALUES
  (101, 'Jeringa descartable 3 ml',         200,   150.00, 'DISPONIBLE', 1),
  (102, 'Guantes de látex (par)',           150,   220.00, 'DISPONIBLE', 1),
  (103, 'Gasa estéril 10 x 10',             100,   180.00, 'DISPONIBLE', 1),
  (104, 'Vacuna séxtuple canina (dosis)',    25,  6500.00, 'DISPONIBLE', 1),
  (105, 'Vacuna triple felina (dosis)',      20,  7200.00, 'DISPONIBLE', 1),
  (106, 'Vacuna antirrábica (dosis)',        30,  3800.00, 'DISPONIBLE', 1),
  (107, 'Sutura absorbible 3-0',              0,  2500.00, 'EN_FALTA',   1),
  (108, 'Solución fisiológica 500 ml',        3,  1900.00, 'YA_PEDIDO',  1),
  (109, 'Venda elástica 5 cm',               10,   900.00, 'DISPONIBLE', 0)
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre),
  stock = VALUES(stock),
  costo = VALUES(costo),
  estado = VALUES(estado),
  activo = VALUES(activo);
