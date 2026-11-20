-- Migración 014 · módulo Backend (configuración de la veterinaria)
-- Crea la tabla configuracion: los parámetros que la veterinaria cambia desde su panel (horario de
-- los turnos, días de los avisos del motor, stock bajo…). La escribe Backend (PUT /api/configuracion),
-- que también valida cada valor; los demás módulos solo la leen (comun/configuracion.php).
-- Sus permisos están en base/permisos/014_backend_configuracion.sql.
-- Decisiones:
--   - Solo se guarda lo que la veterinaria cambió. Si una clave no está, cada módulo usa su valor
--     por defecto (el de siempre): por eso la tabla arranca vacía y "volver al valor por defecto"
--     borra la fila.
--   - Qué claves existen, su tipo, su rango y su valor por defecto están en el catálogo de Backend
--     (src/CatalogoConfiguracion.php), no acá: así sumar un parámetro no necesita otra migración.
--   - valor es texto: hay horas ("09:00") y números ("7"). Lo interpreta quien lo lee.

CREATE TABLE configuracion (
  clave            VARCHAR(60)  NOT NULL,
  valor            VARCHAR(255) NOT NULL,
  actualizado_en   DATETIME     NOT NULL,
  actualizado_por  INT UNSIGNED NOT NULL,
  PRIMARY KEY (clave),
  CONSTRAINT fk_configuracion_usuario FOREIGN KEY (actualizado_por) REFERENCES usuario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
