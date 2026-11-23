-- Migración 019 · módulo Backend (cuentas)
-- Verificación del WhatsApp: un código de 6 números que se manda por WhatsApp al registrarse y al
-- cambiar el número en "Mis datos".
-- Decisiones:
--   - Una cuenta nueva se crea recién cuando el código es correcto, y el teléfono se cambia recién
--     cuando se confirma el del número nuevo: nunca queda un usuario con un número sin verificar.
--     Las cuentas que ya existían antes de esta migración quedan como estaban.
--   - proposito: REGISTRO (todavía no hay usuario) o CAMBIO (usuario_id es quien cambia su número).
--   - telefono: los 10 dígitos, como en usuario.telefono.
--   - codigo_hash: el código nunca se guarda tal cual (password_hash).
--   - intentos: cuántas veces se escribió mal. Con 5, hay que pedir otro código.
--   - vence_en: 10 minutos después de mandarlo. usado_en: cuando se confirmó (no sirve dos veces).
--   - Las filas no se borran: con creado_en se limitan los envíos (uno por minuto y 5 por hora por
--     número), para no gastar mensajes ni molestar a un número ajeno.

CREATE TABLE verificacion_whatsapp (
  id           INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  proposito    ENUM('REGISTRO','CAMBIO') NOT NULL,
  telefono     CHAR(10)         NOT NULL,
  usuario_id   INT UNSIGNED     NULL,
  codigo_hash  VARCHAR(255)     NOT NULL,
  intentos     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  creado_en    DATETIME         NOT NULL,
  vence_en     DATETIME         NOT NULL,
  usado_en     DATETIME         NULL,
  PRIMARY KEY (id),
  KEY ix_verificacion_telefono (telefono, proposito, creado_en),
  KEY ix_verificacion_usuario (usuario_id, proposito, creado_en),
  CONSTRAINT fk_verificacion_usuario FOREIGN KEY (usuario_id) REFERENCES usuario (id),
  CONSTRAINT ck_verificacion_usuario CHECK ((proposito = 'CAMBIO') = (usuario_id IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
