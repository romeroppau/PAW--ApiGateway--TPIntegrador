-- Migración 022 · módulo Backend
-- Cuándo y por qué la veterinaria aprobó o rechazó a un rescatista, para las listas de
-- "Aprobados" y "Rechazados" y el perfil del rescatista (panel de Adopciones).
--   - validado_en / validado_por: la fecha y hora (de Argentina) y la veterinaria que lo decidió.
--     Los rescatistas validados antes de esta migración quedan sin fecha (NULL).
--   - motivo_rechazo: lo que escribió la veterinaria al rechazarlo. Solo en los RECHAZADO (los de
--     antes de esta migración, sin motivo).
ALTER TABLE usuario
  ADD COLUMN motivo_rechazo VARCHAR(255) NULL AFTER estado_validacion,
  ADD COLUMN validado_en    DATETIME     NULL AFTER motivo_rechazo,
  ADD COLUMN validado_por   INT UNSIGNED NULL AFTER validado_en,
  ADD CONSTRAINT fk_usuario_validado_por FOREIGN KEY (validado_por) REFERENCES usuario (id),
  ADD CONSTRAINT ck_usuario_motivo_rechazo CHECK (motivo_rechazo IS NULL OR estado_validacion = 'RECHAZADO');
