-- Migración 021 · módulo Adopciones
-- El cliente puede cancelar su postulación mientras la rescatista todavía no eligió (PENDIENTE).
-- Queda CANCELADA ("cancelada por el postulante"), distinta de RECHAZADA (la rescatista eligió a otra
-- persona, o la publicación o la adopción se cerraron: "cancelada por la rescatista").
-- No se borra: el cliente no se puede volver a postular por el mismo animal (índice único de 007).
ALTER TABLE postulacion
  MODIFY estado ENUM('PENDIENTE','ELEGIDA','RECHAZADA','CANCELADA') NOT NULL DEFAULT 'PENDIENTE';
