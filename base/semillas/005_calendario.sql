-- Semilla 005 · calendario sanitario de las mascotas de prueba (semilla 004)
-- Ids fijos desde 101. Correr las semillas de nuevo vuelve cada evento a su estado inicial
-- (por ejemplo, la vacuna que se aplicó en una consulta vuelve a quedar pendiente).
-- No es el calendario completo que armaría CalendarioSanitario::generarPara: son algunos
-- eventos elegidos para probar los casos (al día, vencida, pendiente para el turno de hoy).

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);

INSERT INTO evento_sanitario
  (id, mascota_id, plan_sanitario_id, tipo, nombre, fecha_programada, fecha_aplicada, consulta_id)
VALUES
  -- Firulais (101, perro de 3 años): el refuerzo anual está vencido, la antirrábica al día.
  (101, 101, 6,  'VACUNA',          'Séxtuple (refuerzo anual)',      @hoy - INTERVAL 2 WEEK,  NULL,                    NULL),
  (102, 101, 5,  'VACUNA',          'Antirrábica',                    @hoy + INTERVAL 1 MONTH, NULL,                    NULL),
  -- Michi (102, gato de 5 años): desparasitado hace un mes, refuerzo en tres meses.
  (103, 102, 7,  'DESPARASITACION', 'Desparasitación interna',        @hoy - INTERVAL 1 MONTH, @hoy - INTERVAL 1 MONTH, NULL),
  (104, 102, 11, 'VACUNA',          'Triple felina (refuerzo anual)', @hoy + INTERVAL 3 MONTH, NULL,                    NULL),
  -- Luna (103, cachorra de 10 semanas): la 1.ª dosis aplicada; la 2.ª le toca en el turno 102 de hoy.
  (105, 103, 2,  'VACUNA',          'Séxtuple (1.ª dosis)',           @hoy - INTERVAL 4 WEEK,  @hoy - INTERVAL 4 WEEK,  NULL),
  (106, 103, 3,  'VACUNA',          'Séxtuple (2.ª dosis)',           @hoy - INTERVAL 1 WEEK,  NULL,                    NULL),
  (107, 103, 4,  'VACUNA',          'Séxtuple (3.ª dosis)',           @hoy + INTERVAL 2 WEEK,  NULL,                    NULL),
  (108, 103, 5,  'VACUNA',          'Antirrábica',                    @hoy + INTERVAL 6 WEEK,  NULL,                    NULL),
  -- Tom (104, gato de 2 años): antirrábica en dos meses.
  (109, 104, 10, 'VACUNA',          'Antirrábica',                    @hoy + INTERVAL 2 MONTH, NULL,                    NULL)
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id),
  plan_sanitario_id = VALUES(plan_sanitario_id),
  tipo = VALUES(tipo),
  nombre = VALUES(nombre),
  fecha_programada = VALUES(fecha_programada),
  fecha_aplicada = VALUES(fecha_aplicada),
  consulta_id = VALUES(consulta_id);
