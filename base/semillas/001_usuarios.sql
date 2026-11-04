-- Semilla 001 · usuarios de prueba (las contraseñas están en base/semillas/README.md)
-- Ids fijos desde 101. Si ya existen, se vuelven a dejar como estaban
-- (también se desbloquean, por si una prueba hizo intentos fallidos).

INSERT INTO usuario
  (id, nombre, email, password_hash, telefono, rol, organizacion, estado_validacion,
   intentos_fallidos, primer_fallo_en, bloqueado_hasta)
VALUES
  (101, 'Veterinaria de Prueba', 'vet@prueba.huellavet',         '$2y$12$P0qM4XMeAxr61M0jUxL8kOuEoGSxgnDck0AqIHKo5/Cy/j7ZNO.VW',        '1155550101', 'VETERINARIO', NULL,                 NULL,        0, NULL, NULL),
  (102, 'Cliente de Prueba',     'cliente@prueba.huellavet',     '$2y$12$MwkMnatrstZyTHhy9L0eHeOLX/hJzQ8i.Cz1x1LVCaLy1uE9eSNbK',    '1155550102', 'CLIENTE',     NULL,                 NULL,        0, NULL, NULL),
  (103, 'Cliente Dos',           'cliente2@prueba.huellavet',    '$2y$12$MwkMnatrstZyTHhy9L0eHeOLX/hJzQ8i.Cz1x1LVCaLy1uE9eSNbK',    '1155550103', 'CLIENTE',     NULL,                 NULL,        0, NULL, NULL),
  (104, 'Rescatista Aprobada',   'rescatista@prueba.huellavet',  '$2y$12$cFW9NGh.9iwKcGbO3XA.4umj7KqzT1MOhaDmpFNVUEUnvwmoygVcK', '1155550104', 'RESCATISTA',  'Refugio Huellitas',  'APROBADO',  0, NULL, NULL),
  (105, 'Rescatista Pendiente',  'rescatista2@prueba.huellavet', '$2y$12$cFW9NGh.9iwKcGbO3XA.4umj7KqzT1MOhaDmpFNVUEUnvwmoygVcK', '1155550105', 'RESCATISTA',  'Patitas al Rescate', 'PENDIENTE', 0, NULL, NULL)
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre),
  password_hash = VALUES(password_hash),
  telefono = VALUES(telefono),
  rol = VALUES(rol),
  organizacion = VALUES(organizacion),
  estado_validacion = VALUES(estado_validacion),
  intentos_fallidos = 0,
  primer_fallo_en = NULL,
  bloqueado_hasta = NULL;
