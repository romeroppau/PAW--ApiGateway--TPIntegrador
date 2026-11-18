-- Migración 008 · módulo Backend (notificaciones)
-- Crea la tabla notificacion (DER, Entrega 5). La escribe Backend: la llamada interna
-- POST /internal/notificaciones (la usan Adopciones y Reportes) y el envío por WhatsApp.
-- Sus permisos están en base/permisos/008_backend_notificacion.sql.
-- Decisiones:
--   - id_operacion es único: un aviso repetido (reintento, tarea que corre dos veces el mismo
--     día) lo rechaza MySQL con el error 1062 y Backend responde aplicado: false.
--   - enviada_en queda en NULL hasta que el aviso sale (canal WEB: queda para la campana;
--     canal WHATSAPP: se completa al enviarlo). El envío toma los que tienen NULL.

CREATE TABLE notificacion (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id       INT UNSIGNED NOT NULL,
  tipo             ENUM('VACUNA','CONTROL_ADOPCION','STOCK_BAJO','PROMOCION','CUENTA','POSTULACION') NOT NULL,
  canal            ENUM('WEB','WHATSAPP') NOT NULL,
  mensaje          VARCHAR(500) NOT NULL,
  fecha_programada DATETIME NOT NULL,
  enviada_en       DATETIME NULL,
  leida            BOOLEAN NOT NULL DEFAULT FALSE,
  id_operacion     VARCHAR(100) NOT NULL,
  creada_en        DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_notificacion_operacion (id_operacion),
  -- La campana: las del usuario, las no leídas primero.
  KEY ix_notificacion_usuario (usuario_id, leida, fecha_programada),
  -- La tarea de envío busca los pendientes de WhatsApp.
  KEY ix_notificacion_pendientes (canal, enviada_en, fecha_programada),
  CONSTRAINT fk_notificacion_usuario FOREIGN KEY (usuario_id) REFERENCES usuario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;