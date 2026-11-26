-- Producción 008 · 22 reseñas de clientes de fondo (ids 30001 a 30022), de los últimos 4 meses
-- (generado por base/semillas-produccion/generar.py). Cada autor fue atendido antes de escribirla, y
-- lo que cuenta pasó: la conjuntivitis de Nala, la castración de Bigote, la urgencia de Paloma un
-- sábado, la antirrábica, la adopción y la compra. La mitad tiene respuesta de la veterinaria de la
-- demo. Las más nuevas de 4 o 5 estrellas salen en la portada.
-- Correr de nuevo las deja así (también las respuestas).

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

INSERT INTO resena (id, autor_id, estrellas, texto, creada_en, respuesta, respondida_en, respondida_por)
VALUES
  (30001, 3003, 5, 'Llevé a mi gata por una conjuntivitis y en dos días estaba bien. Muy buena atención y me explicaron todo.', @ahora - INTERVAL 2 DAY - INTERVAL 5 HOUR, '¡Gracias, Camila! Nos alegra que Nala se haya recuperado tan rápido.', @ahora - INTERVAL 2 DAY + INTERVAL 20 HOUR, @vet),
  (30002, 3012, 5, 'Coordiné el turno por WhatsApp y me atendieron en el horario. Puntuales y muy amables.', @ahora - INTERVAL 5 DAY - INTERVAL 1 HOUR, NULL, NULL, NULL),
  (30003, 3021, 4, 'Buena atención y precios razonables. A veces hay que esperar un poco en la sala.', @ahora - INTERVAL 8 DAY - INTERVAL 6 HOUR, 'Gracias por el comentario, Valeria. Estamos ajustando los turnos para que la espera sea menor.', @ahora - INTERVAL 8 DAY + INTERVAL 20 HOUR, @vet),
  (30004, 3007, 5, 'Me encanta poder ver las vacunas de mis perros en el sitio. Ya no me olvido ninguna.', @ahora - INTERVAL 11 DAY - INTERVAL 2 HOUR, NULL, NULL, NULL),
  (30005, 3030, 5, 'Compré por la página y lo retiré en el local. Súper práctico.', @ahora - INTERVAL 15 DAY - INTERVAL 7 HOUR, '¡Gracias, Emiliano! Te esperamos en la próxima compra.', @ahora - INTERVAL 15 DAY + INTERVAL 20 HOUR, @vet),
  (30006, 3017, 3, 'La atención está bien, pero el día que fui se demoraron casi media hora con el turno.', @ahora - INTERVAL 19 DAY - INTERVAL 3 HOUR, 'Rocío, perdón por la demora: ese día tuvimos una urgencia. Gracias por avisarnos.', @ahora - INTERVAL 19 DAY + INTERVAL 20 HOUR, @vet),
  (30007, 3025, 5, 'Adoptamos a nuestro gato gracias a un refugio que publica acá. Nos acompañaron en todo el proceso.', @ahora - INTERVAL 10 DAY - INTERVAL 8 HOUR, NULL, NULL, NULL),
  (30008, 3009, 4, 'Muy buena la doctora, se nota que quiere a los animales. Le pondría 5 si hubiera más turnos a la tarde.', @ahora - INTERVAL 27 DAY - INTERVAL 4 HOUR, NULL, NULL, NULL),
  (30009, 3034, 5, 'Castraron a mi perro y el seguimiento fue excelente. En el control quedó todo perfecto.', @ahora - INTERVAL 31 DAY - INTERVAL 0 HOUR, 'Gracias, Lautaro. Que Bigote siga muy bien.', @ahora - INTERVAL 31 DAY + INTERVAL 20 HOUR, @vet),
  (30010, 3002, 2, 'El producto que quería no tenía stock y tuve que volver otro día.', @ahora - INTERVAL 36 DAY - INTERVAL 5 HOUR, 'Bruno, gracias por avisar. Ahora la página muestra el stock de cada producto antes de comprar.', @ahora - INTERVAL 36 DAY + INTERVAL 20 HOUR, @vet),
  (30011, 3039, 5, 'Excelente atención. Mi gato es muy arisco y lo trataron con muchísima paciencia.', @ahora - INTERVAL 40 DAY - INTERVAL 1 HOUR, NULL, NULL, NULL),
  (30012, 3014, 4, 'Buenos precios en la tienda y te avisan cuando el pedido está listo.', @ahora - INTERVAL 46 DAY - INTERVAL 6 HOUR, NULL, NULL, NULL),
  (30013, 3027, 5, 'Atendieron a mi perra de urgencia un sábado. Les estoy muy agradecida.', @ahora - INTERVAL 52 DAY - INTERVAL 2 HOUR, 'Gracias, Belén. Para eso estamos.', @ahora - INTERVAL 52 DAY + INTERVAL 20 HOUR, @vet),
  (30014, 3005, 3, 'Bien en general. Me hubiera gustado que me expliquen un poco más el tratamiento.', @ahora - INTERVAL 58 DAY - INTERVAL 7 HOUR, NULL, NULL, NULL),
  (30015, 3036, 5, 'Muy buena veterinaria. Llevo a mis dos mascotas y siempre las atienden con cariño.', @ahora - INTERVAL 64 DAY - INTERVAL 3 HOUR, '¡Gracias, Nicolás! Es un gusto atenderlos.', @ahora - INTERVAL 64 DAY + INTERVAL 20 HOUR, @vet),
  (30016, 3019, 4, 'Muy prolijo todo: la factura queda guardada en la cuenta.', @ahora - INTERVAL 70 DAY - INTERVAL 8 HOUR, NULL, NULL, NULL),
  (30017, 3031, 5, 'Me avisaron que le tocaba la antirrábica a mi mascota y fui ese mismo día. Un golazo.', @ahora - INTERVAL 77 DAY - INTERVAL 4 HOUR, NULL, NULL, NULL),
  (30018, 3010, 5, 'Atención cálida y profesional. Mi perro sale contento, que ya es mucho decir.', @ahora - INTERVAL 85 DAY - INTERVAL 0 HOUR, 'Gracias, Joaquín. ¡Saludos a Ramón!', @ahora - INTERVAL 85 DAY + INTERVAL 20 HOUR, @vet),
  (30019, 3023, 4, 'Buena experiencia. El lugar es chico pero está muy limpio.', @ahora - INTERVAL 93 DAY - INTERVAL 5 HOUR, NULL, NULL, NULL),
  (30020, 3006, 5, 'Me ayudaron a elegir el alimento correcto para mi perro. Muy recomendables.', @ahora - INTERVAL 101 DAY - INTERVAL 1 HOUR, '¡Gracias, Federico! Cualquier duda con la alimentación, consultanos.', @ahora - INTERVAL 101 DAY + INTERVAL 20 HOUR, @vet),
  (30021, 3028, 4, 'Buena atención. El estacionamiento en la zona es complicado.', @ahora - INTERVAL 110 DAY - INTERVAL 6 HOUR, NULL, NULL, NULL),
  (30022, 3015, 5, 'Siempre atentos. Se nota que les importan los animales.', @ahora - INTERVAL 118 DAY - INTERVAL 2 HOUR, NULL, NULL, NULL)
ON DUPLICATE KEY UPDATE
  autor_id = VALUES(autor_id), estrellas = VALUES(estrellas), texto = VALUES(texto), creada_en = VALUES(creada_en),
  respuesta = VALUES(respuesta), respondida_en = VALUES(respondida_en), respondida_por = VALUES(respondida_por);
