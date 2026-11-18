-- Semilla 008 · notificaciones de prueba
-- Un aviso web sin leer para el cliente de prueba (cliente@prueba.huellavet), para que el humo
-- tenga algo que marcar como leído. Correr las semillas de nuevo lo deja sin leer otra vez.
--
-- Los ids empiezan en 901: las notificaciones que crean el motor y las pruebas usan los
-- números bajos.

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

-- Borra los avisos que dejaron las pruebas del humo y de los casos internos, sin tocar los de la semilla.
DELETE FROM notificacion
WHERE id_operacion LIKE 'humo-%';

INSERT INTO notificacion
  (id, usuario_id, tipo, canal, mensaje, fecha_programada, enviada_en, leida, id_operacion, creada_en)
VALUES
  (901, (SELECT id FROM usuario WHERE email = 'cliente@prueba.huellavet'),
   'VACUNA', 'WEB',
   'Aviso de prueba: a Firulais le toca la vacuna antirrábica esta semana',
   @ahora - INTERVAL 1 HOUR, NULL, 0, 'semilla-vacuna-901', @ahora - INTERVAL 1 HOUR)
ON DUPLICATE KEY UPDATE
  usuario_id = VALUES(usuario_id),
  tipo = VALUES(tipo),
  canal = VALUES(canal),
  mensaje = VALUES(mensaje),
  fecha_programada = VALUES(fecha_programada),
  enviada_en = VALUES(enviada_en),
  leida = VALUES(leida),
  creada_en = VALUES(creada_en);