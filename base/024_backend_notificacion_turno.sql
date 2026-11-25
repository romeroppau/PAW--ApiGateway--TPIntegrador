-- Migración 024 · módulo Backend (notificaciones)
-- Avisos de turnos (25/11): cuando la veterinaria da, reprograma o cancela un turno, al dueño le llega
-- un aviso por la campana y por WhatsApp (los manda Pacientes por /internal/notificaciones).
ALTER TABLE notificacion
  MODIFY tipo ENUM('VACUNA','CONTROL_ADOPCION','STOCK_BAJO','PROMOCION','CUENTA','POSTULACION','COMPRA','RESENA','TURNO') NOT NULL;
