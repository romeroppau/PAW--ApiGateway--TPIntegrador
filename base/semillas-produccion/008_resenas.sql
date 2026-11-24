-- Producción 008 · 22 reseñas de clientes de fondo (ids 30001 a 30022), de los últimos 4 meses
--   La mayoría de 4 y 5 estrellas, algunas de 3 y una de 2, como pasa en cualquier veterinaria.
--   La mitad tiene respuesta de la veterinaria de la demo. Las más nuevas de 4 o 5 estrellas salen
--   en la portada.
-- Correr de nuevo las deja así (también las respuestas).

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

INSERT INTO resena (id, autor_id, estrellas, texto, creada_en, respuesta, respondida_en, respondida_por)
SELECT 30000 + r.i, 3000 + r.autor, r.estrellas, r.texto,
       @ahora - INTERVAL r.dias DAY - INTERVAL (r.i * 5) % 9 HOUR,
       r.respuesta,
       IF(r.respuesta IS NULL, NULL, @ahora - INTERVAL r.dias DAY + INTERVAL 20 HOUR),
       IF(r.respuesta IS NULL, NULL, @vet)
FROM (
            SELECT  1 AS i,  3 AS autor, 5 AS estrellas, 2 AS dias,
                    'Llevé a mi gata por una conjuntivitis y en dos días estaba bien. Muy buena atención y me explicaron todo.' AS texto,
                    '¡Gracias, Camila! Nos alegra que Nala se haya recuperado tan rápido.' AS respuesta
  UNION ALL SELECT  2, 12, 5, 5,  'Saqué el turno por WhatsApp y me atendieron en el horario. Puntuales y muy amables.', NULL
  UNION ALL SELECT  3, 21, 4, 8,  'Buena atención y precios razonables. A veces hay que esperar un poco en la sala.',
                    'Gracias por el comentario, Valeria. Estamos ajustando los turnos para que la espera sea menor.'
  UNION ALL SELECT  4, 7,  5, 11, 'Me encanta poder ver las vacunas de mis perros desde el celular. Ya no me olvido ninguna.', NULL
  UNION ALL SELECT  5, 30, 5, 15, 'Compré el alimento por la página y lo retiré al día siguiente. Súper práctico.',
                    '¡Gracias, Emiliano! Te esperamos en la próxima compra.'
  UNION ALL SELECT  6, 17, 3, 19, 'La atención está bien, pero el día que fui se demoraron casi media hora con el turno.',
                    'Rocío, perdón por la demora: ese día tuvimos una urgencia. Gracias por avisarnos.'
  UNION ALL SELECT  7, 25, 5, 23, 'Adoptamos a nuestro perro gracias a un refugio que publica acá. Nos acompañaron en todo el proceso.', NULL
  UNION ALL SELECT  8, 9,  4, 27, 'Muy buena la doctora, se nota que quiere a los animales. Le pondría 5 si hubiera más turnos a la tarde.', NULL
  UNION ALL SELECT  9, 34, 5, 31, 'Castraron a mi perro y el seguimiento fue excelente. Me escribieron para ver cómo seguía.',
                    'Gracias, Lautaro. Que Bigote siga muy bien.'
  UNION ALL SELECT 10, 2,  2, 36, 'El producto que quería no tenía stock y tuve que volver otro día.',
                    'Bruno, gracias por avisar. Ahora la página muestra el stock de cada producto antes de comprar.'
  UNION ALL SELECT 11, 39, 5, 40, 'Excelente atención. Mi gato es muy arisco y lo trataron con muchísima paciencia.', NULL
  UNION ALL SELECT 12, 14, 4, 46, 'Buenos precios en la tienda y te avisan cuando el pedido está listo.', NULL
  UNION ALL SELECT 13, 27, 5, 52, 'Atendieron a mi perra de urgencia un sábado. Les estoy muy agradecida.',
                    'Gracias, Belén. Para eso estamos.'
  UNION ALL SELECT 14, 5,  3, 58, 'Bien en general. Me hubiera gustado que me expliquen un poco más el tratamiento.', NULL
  UNION ALL SELECT 15, 36, 5, 64, 'La mejor veterinaria de Luján. Hace años que llevo a mis mascotas.',
                    '¡Gracias, Nicolás! Es un gusto atenderlos.'
  UNION ALL SELECT 16, 19, 4, 70, 'Muy prolijo todo: la factura llega al instante y queda guardada en la cuenta.', NULL
  UNION ALL SELECT 17, 31, 5, 77, 'Me recordaron la vacuna antirrábica por WhatsApp. Un golazo.', NULL
  UNION ALL SELECT 18, 10, 5, 85, 'Atención cálida y profesional. Mi perro sale contento, que ya es mucho decir.',
                    'Gracias, Joaquín. ¡Saludos a Ramón!'
  UNION ALL SELECT 19, 23, 4, 93, 'Buena experiencia. El lugar es chico pero está muy limpio.', NULL
  UNION ALL SELECT 20, 6,  5, 101, 'Me ayudaron a elegir el alimento correcto para mi cachorro. Muy recomendables.',
                    '¡Gracias, Federico! Cualquier duda con la alimentación, consultanos.'
  UNION ALL SELECT 21, 28, 4, 110, 'Buena atención. El estacionamiento en la zona es complicado.', NULL
  UNION ALL SELECT 22, 15, 5, 118, 'Siempre atentos. Se nota que les importan los animales.', NULL
) r
ON DUPLICATE KEY UPDATE
  autor_id = VALUES(autor_id), estrellas = VALUES(estrellas), texto = VALUES(texto), creada_en = VALUES(creada_en),
  respuesta = VALUES(respuesta), respondida_en = VALUES(respondida_en), respondida_por = VALUES(respondida_por);
