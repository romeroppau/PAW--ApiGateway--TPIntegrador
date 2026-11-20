-- Volumen 001 · usuarios y mascotas en cantidad
-- (juego aparte: ver base/semillas-volumen/README.md; se carga después de las semillas comunes)
--
--   2001         Veterinario Dos (vet2@volumen.huellavet): atiende todos los turnos del volumen, así
--                no chocan con los que se cargan a mano con la veterinaria 101.
--   2002 a 2041  40 clientes (cliente01 a cliente40 @volumen.huellavet).
--   2042 a 2046  5 rescatistas aprobados (rescatista1 a rescatista5 @volumen.huellavet).
--   Contraseñas: las mismas que las cuentas de prueba del mismo rol (base/semillas/README.md).
--   Sin teléfono: así los avisos del motor quedan en la web y nunca salen por WhatsApp a un número
--   inventado.
--
--   Mascotas 20001 a 20080: dos por cliente. 20081 y 20082: dos más del cliente de prueba 102
--   (para que "Mis turnos" tenga movimiento). 20101 a 20140: a cargo de los rescatistas (adopciones,
--   volumen 004).
-- Correr de nuevo deja todo como estaba (los ids son fijos).

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);

INSERT INTO usuario
  (id, nombre, email, password_hash, telefono, rol, organizacion, estado_validacion,
   intentos_fallidos, primer_fallo_en, bloqueado_hasta)
VALUES
  (2001, 'Veterinario Dos', 'vet2@volumen.huellavet', '$2y$12$P0qM4XMeAxr61M0jUxL8kOuEoGSxgnDck0AqIHKo5/Cy/j7ZNO.VW',
   NULL, 'VETERINARIO', NULL, NULL, 0, NULL, NULL)
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre), password_hash = VALUES(password_hash), telefono = VALUES(telefono), rol = VALUES(rol),
  intentos_fallidos = 0, primer_fallo_en = NULL, bloqueado_hasta = NULL;

INSERT INTO usuario
  (id, nombre, email, password_hash, telefono, rol, organizacion, estado_validacion,
   intentos_fallidos, primer_fallo_en, bloqueado_hasta)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 40)
SELECT 2001 + i,
       CONCAT(ELT(1 + (i % 20), 'Ana', 'Bruno', 'Carla', 'Diego', 'Elena', 'Facundo', 'Gabriela', 'Hernán',
                  'Inés', 'Julián', 'Karina', 'Lucas', 'Martina', 'Nicolás', 'Olivia', 'Pablo', 'Rocío',
                  'Santiago', 'Tamara', 'Valentín'),
              ' ',
              ELT(1 + ((i * 7) % 15), 'Gómez', 'Fernández', 'López', 'Díaz', 'Martínez', 'Pérez', 'Romero',
                  'Sosa', 'Álvarez', 'Torres', 'Ruiz', 'Ramírez', 'Flores', 'Benítez', 'Acosta')),
       CONCAT('cliente', LPAD(i, 2, '0'), '@volumen.huellavet'),
       '$2y$12$MwkMnatrstZyTHhy9L0eHeOLX/hJzQ8i.Cz1x1LVCaLy1uE9eSNbK',
       NULL, 'CLIENTE', NULL, NULL, 0, NULL, NULL
FROM n
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre), password_hash = VALUES(password_hash), telefono = VALUES(telefono), rol = VALUES(rol),
  intentos_fallidos = 0, primer_fallo_en = NULL, bloqueado_hasta = NULL;

INSERT INTO usuario
  (id, nombre, email, password_hash, telefono, rol, organizacion, estado_validacion,
   intentos_fallidos, primer_fallo_en, bloqueado_hasta)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 5)
SELECT 2041 + i,
       ELT(i, 'Marta Quiroga', 'Sergio Molina', 'Laura Vega', 'Ramiro Castro', 'Paula Medina'),
       CONCAT('rescatista', i, '@volumen.huellavet'),
       '$2y$12$cFW9NGh.9iwKcGbO3XA.4umj7KqzT1MOhaDmpFNVUEUnvwmoygVcK',
       NULL, 'RESCATISTA',
       ELT(i, 'Refugio San Roque', 'Cuatro Patas Luján', 'Hogar Peludo', 'Rescate Oeste', 'Amigos del Barrio'),
       'APROBADO', 0, NULL, NULL
FROM n
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre), password_hash = VALUES(password_hash), telefono = VALUES(telefono), rol = VALUES(rol),
  organizacion = VALUES(organizacion), estado_validacion = VALUES(estado_validacion),
  intentos_fallidos = 0, primer_fallo_en = NULL, bloqueado_hasta = NULL;

-- Mascotas de los clientes (dos cada uno) y dos más del cliente de prueba 102.
INSERT INTO mascota
  (id, duenio_id, nombre, especie, raza, fecha_nacimiento, peso_kg, foto, foto_tipo, activo)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 82)
SELECT 20000 + i,
       IF(i <= 80, 2002 + (i - 1) DIV 2, 102),
       ELT(1 + (i % 30), 'Toby', 'Mora', 'Coco', 'Lola', 'Rocky', 'Nala', 'Bobby', 'Kira', 'Max', 'Mía',
           'Thor', 'Frida', 'Bruno', 'Olivia', 'Zeus', 'Pelusa', 'Tango', 'Uma', 'Ramón', 'Chispa',
           'Oreo', 'Manchita', 'Pancho', 'Luz', 'Duque', 'Canela', 'Milo', 'Sasha', 'Pipo', 'Greta'),
       IF(i % 3 = 0, 'GATO', 'PERRO'),
       IF(i % 3 = 0, ELT(1 + (i % 3), 'Europeo común', 'Siamés', 'Persa'),
                     ELT(1 + (i % 5), 'Mestizo', 'Caniche', 'Labrador', 'Ovejero alemán', 'Beagle')),
       @hoy - INTERVAL (8 + (i * 17) % 150) MONTH,
       IF(i % 3 = 0, 3.00 + (i % 4), 6.00 + (i % 25)),
       NULL, NULL, 1
FROM n
ON DUPLICATE KEY UPDATE
  duenio_id = VALUES(duenio_id), nombre = VALUES(nombre), especie = VALUES(especie), raza = VALUES(raza),
  fecha_nacimiento = VALUES(fecha_nacimiento), peso_kg = VALUES(peso_kg), activo = VALUES(activo);

-- Mascotas a cargo de los rescatistas (las de las adopciones finalizadas pasan al adoptante en el
-- volumen 004).
INSERT INTO mascota
  (id, duenio_id, nombre, especie, raza, fecha_nacimiento, peso_kg, foto, foto_tipo, activo)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 40)
SELECT 20100 + i,
       2042 + (i % 5),
       ELT(1 + (i % 20), 'Chocolate', 'Vainilla', 'Pirata', 'Morena', 'Tito', 'Lupe', 'Negro', 'Rubia',
           'Ciro', 'Dama', 'Fito', 'Gala', 'Hugo', 'Isis', 'Jack', 'Kala', 'León', 'Mimí', 'Nilo', 'Osa'),
       IF(i % 2 = 0, 'GATO', 'PERRO'),
       IF(i % 2 = 0, NULL, 'Mestizo'),
       @hoy - INTERVAL (3 + (i * 7) % 60) MONTH,
       IF(i % 2 = 0, 2.50 + (i % 3), 5.00 + (i % 18)),
       NULL, NULL, 1
FROM n
ON DUPLICATE KEY UPDATE
  duenio_id = VALUES(duenio_id), nombre = VALUES(nombre), especie = VALUES(especie), raza = VALUES(raza),
  fecha_nacimiento = VALUES(fecha_nacimiento), peso_kg = VALUES(peso_kg), activo = VALUES(activo);
