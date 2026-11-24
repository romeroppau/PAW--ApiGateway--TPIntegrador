-- Migración 018 · módulo Backend (notificaciones)
-- Seguimiento del envío por WhatsApp en la tabla notificacion (migración 008).
-- Decisiones:
--   - intentos: cuántas veces la tarea intentó mandar el aviso. Después de 5 (o de un error que no
--     se arregla reintentando, como un número que no está verificado en la cuenta de prueba de Meta)
--     el aviso deja de tomarse: queda solo en la web. Antes, un aviso que fallaba siempre se volvía a
--     tomar cada 15 minutos y, con 20 así, tapaba a los nuevos.
--   - ultimo_error: el motivo, sin datos sensibles (p. ej. META_131030_HTTP_400, SIN_TELEFONO).
--     Sirve para ver en la base por qué no llegó un WhatsApp.
-- No cambia los permisos: Backend ya tiene SELECT, INSERT y UPDATE sobre la tabla.

ALTER TABLE notificacion
  ADD COLUMN intentos     TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER enviada_en,
  ADD COLUMN ultimo_error VARCHAR(100) NULL AFTER intentos;
