-- Semilla 011 · reseñas de prueba (usuarios de la semilla 001)
-- Cinco reseñas de los clientes y la rescatista de prueba, con fechas relativas a hoy, y una ya
-- respondida por la veterinaria. Para que la página "Reseñas" y la portada no arranquen vacías y las
-- pruebas tengan datos fijos. Correr las semillas de nuevo las deja como estaban.
--
--   101  cliente 102     5★  hace 20 días  (respondida por la veterinaria 101)
--   102  cliente 103     4★  hace 12 días
--   103  rescatista 104  5★  hace 7 días
--   104  cliente 102     3★  hace 3 días
--   105  cliente 103     5★  ayer
--
-- Ids desde 101: las reseñas que escriben las pruebas o la gente en dev se numeran después.

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;   -- hora de Argentina (Aiven trabaja en UTC)

INSERT INTO resena (id, autor_id, estrellas, texto, creada_en, respuesta, respondida_en, respondida_por) VALUES
  (101, 102, 5, 'Atendieron a Firulais con mucha paciencia y nos explicaron todo. ¡Muy recomendables!',
        @ahora - INTERVAL 20 DAY, '¡Gracias por tu reseña! Los esperamos en el próximo control de Firulais.', @ahora - INTERVAL 19 DAY, 101),
  (102, 103, 4, 'Buena atención y precios justos. A veces hay que esperar un poco, pero vale la pena.',
        @ahora - INTERVAL 12 DAY, NULL, NULL, NULL),
  (103, 104, 5, 'Siempre nos ayudan con los animales rescatados. Gracias por el compromiso.',
        @ahora - INTERVAL 7 DAY, NULL, NULL, NULL),
  (104, 102, 3, 'El turno se atrasó media hora, pero la atención fue buena.',
        @ahora - INTERVAL 3 DAY, NULL, NULL, NULL),
  (105, 103, 5, 'Compré en la tienda y lo retiré en el local en el día. Excelente.',
        @ahora - INTERVAL 1 DAY, NULL, NULL, NULL)
ON DUPLICATE KEY UPDATE
  autor_id = VALUES(autor_id), estrellas = VALUES(estrellas), texto = VALUES(texto), creada_en = VALUES(creada_en),
  respuesta = VALUES(respuesta), respondida_en = VALUES(respondida_en), respondida_por = VALUES(respondida_por);
