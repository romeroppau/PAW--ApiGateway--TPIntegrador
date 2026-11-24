-- Semilla 011 · reseñas de prueba
-- Cinco reseñas escritas por cinco clientes con nombres reales (se ven como "Lucía F.", "Martín G."…),
-- con fechas relativas a hoy, y una ya respondida por la veterinaria. Para que la página "Reseñas" y la
-- portada no arranquen vacías y las pruebas tengan datos fijos. Correr las semillas de nuevo las deja
-- como estaban.
--
--   usuario 120  Lucía Fernández   reseña 101  5★  hace 20 días  (respondida por la veterinaria 101)
--   usuario 121  Martín Gómez      reseña 102  4★  hace 12 días
--   usuario 122  Carolina Pérez    reseña 103  5★  hace 7 días
--   usuario 123  Julián Sosa       reseña 104  3★  hace 3 días
--   usuario 124  Valeria Ríos      reseña 105  5★  ayer
--
-- Los cinco clientes: email nombre@resenas.huellavet y la misma contraseña que los clientes de prueba
-- (Cliente-Prueba-2026: se copia el hash del cliente 102). Sin teléfono, así nunca se les manda un
-- WhatsApp a un número inventado. Ids 120 a 124: los usuarios que se registran se numeran después.
-- Ids de las reseñas desde 101: las que escriben las pruebas o la gente en dev se numeran aparte.

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;   -- hora de Argentina (Aiven trabaja en UTC)

INSERT INTO usuario
  (id, nombre, email, password_hash, telefono, rol, organizacion, estado_validacion,
   intentos_fallidos, primer_fallo_en, bloqueado_hasta)
SELECT n.id, n.nombre, n.email, c.password_hash, NULL, 'CLIENTE', NULL, NULL, 0, NULL, NULL
FROM (
  SELECT 120 AS id, 'Lucía Fernández' AS nombre, 'lucia@resenas.huellavet' AS email
  UNION ALL SELECT 121, 'Martín Gómez',   'martin@resenas.huellavet'
  UNION ALL SELECT 122, 'Carolina Pérez', 'carolina@resenas.huellavet'
  UNION ALL SELECT 123, 'Julián Sosa',    'julian@resenas.huellavet'
  UNION ALL SELECT 124, 'Valeria Ríos',   'valeria@resenas.huellavet'
) n
JOIN usuario c ON c.id = 102
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), email = VALUES(email), rol = VALUES(rol);

INSERT INTO resena (id, autor_id, estrellas, texto, creada_en, respuesta, respondida_en, respondida_por) VALUES
  (101, 120, 5, 'Atendieron a mi perro de urgencia y me explicaron todo con mucha paciencia. ¡Muy recomendables!',
        @ahora - INTERVAL 20 DAY, '¡Gracias por tu reseña, Lucía! Los esperamos en el próximo control.', @ahora - INTERVAL 19 DAY, 101),
  (102, 121, 4, 'Buena atención y precios justos. A veces hay que esperar un poco, pero vale la pena.',
        @ahora - INTERVAL 12 DAY, NULL, NULL, NULL),
  (103, 122, 5, 'Me encanta poder ver las vacunas de mis gatos desde el celular. Ya no me olvido ninguna.',
        @ahora - INTERVAL 7 DAY, NULL, NULL, NULL),
  (104, 123, 3, 'El turno se atrasó media hora, pero la atención fue buena.',
        @ahora - INTERVAL 3 DAY, NULL, NULL, NULL),
  (105, 124, 5, 'Compré en la tienda y lo retiré en el local en el día. Excelente.',
        @ahora - INTERVAL 1 DAY, NULL, NULL, NULL)
ON DUPLICATE KEY UPDATE
  autor_id = VALUES(autor_id), estrellas = VALUES(estrellas), texto = VALUES(texto), creada_en = VALUES(creada_en),
  respuesta = VALUES(respuesta), respondida_en = VALUES(respondida_en), respondida_por = VALUES(respondida_por);
