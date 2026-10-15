-- Migración 001 · módulo Backend
-- Crea la tabla usuario: cuentas de clientes, veterinarios y rescatistas.

CREATE TABLE usuario (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre            VARCHAR(100) NOT NULL,
  email             VARCHAR(150) NOT NULL,
  password_hash     VARCHAR(255) NOT NULL,
  telefono          VARCHAR(30)  NULL,
  rol               ENUM('CLIENTE','VETERINARIO','RESCATISTA') NOT NULL,
  organizacion      VARCHAR(100) NULL,
  estado_validacion ENUM('PENDIENTE','APROBADO','RECHAZADO') NULL,
  intentos_fallidos TINYINT UNSIGNED NOT NULL DEFAULT 0,
  primer_fallo_en   DATETIME NULL,
  bloqueado_hasta   DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_usuario_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
