-- Producción 001 · clientes, rescatistas y mascotas
-- (juego para producción: ver base/semillas-produccion/README.md; lo carga cargar.sh, que define
--  @vet, @cliente1, @cliente2 y @rescatista: los ids de las cuentas de la demo, ya creadas desde la web)
--
--   3001 a 3040  40 clientes "de fondo" (nombres reales, emails inventados).
--   3041 a 3045  5 rescatistas aprobados de la zona, con su organización.
--   Ninguno puede iniciar sesión (contraseña inutilizable) ni tiene teléfono: aparecen en las listas,
--   la agenda, las ventas y las reseñas, pero nunca se les manda un WhatsApp.
--
--   Mascotas 30001 a 30080: dos por cliente de fondo.
--   30081 a 30083: las del cliente de la demo 1 (Rocco, Mishi y Coco). 30084: la del cliente 2 (Lola).
--   30101 a 30140: a cargo de los rescatistas de fondo (adopciones, 004).
--   30141 a 30144: a cargo del rescatista de la demo.
-- Correr de nuevo deja todo como estaba (los ids son fijos).

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);
-- Un hash que no es de bcrypt: password_verify siempre da falso, así nadie entra con estas cuentas.
SET @sin_acceso = '!sin-acceso-cuenta-de-fondo';

INSERT INTO usuario
  (id, nombre, email, password_hash, telefono, rol, organizacion, estado_validacion,
   intentos_fallidos, primer_fallo_en, bloqueado_hasta)
SELECT 3000 + n.i, n.nombre,
       CONCAT(LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(n.nombre, ' ', '.'), 'á', 'a'), 'é', 'e'),
              'í', 'i'), 'ó', 'o'), 'ú', 'u'), 'ñ', 'n')), n.i + 60, '@gmail.com'),
       @sin_acceso, NULL, 'CLIENTE', NULL, NULL, 0, NULL, NULL
FROM (
            SELECT  1 AS i, 'Agustina Ferreyra' AS nombre
  UNION ALL SELECT  2, 'Bruno Cabral'         UNION ALL SELECT  3, 'Camila Ledesma'
  UNION ALL SELECT  4, 'Daniel Ojeda'         UNION ALL SELECT  5, 'Eugenia Paz'
  UNION ALL SELECT  6, 'Federico Godoy'       UNION ALL SELECT  7, 'Gisela Moreno'
  UNION ALL SELECT  8, 'Hernán Villalba'      UNION ALL SELECT  9, 'Ivana Correa'
  UNION ALL SELECT 10, 'Joaquín Rivero'       UNION ALL SELECT 11, 'Karina Luna'
  UNION ALL SELECT 12, 'Leandro Domínguez'    UNION ALL SELECT 13, 'Micaela Suárez'
  UNION ALL SELECT 14, 'Nahuel Ponce'         UNION ALL SELECT 15, 'Oriana Gutiérrez'
  UNION ALL SELECT 16, 'Pablo Navarro'        UNION ALL SELECT 17, 'Rocío Peralta'
  UNION ALL SELECT 18, 'Sebastián Aguilar'    UNION ALL SELECT 19, 'Tamara Figueroa'
  UNION ALL SELECT 20, 'Ulises Ramos'         UNION ALL SELECT 21, 'Valeria Herrera'
  UNION ALL SELECT 22, 'Walter Giménez'       UNION ALL SELECT 23, 'Ximena Rojas'
  UNION ALL SELECT 24, 'Yamila Castro'        UNION ALL SELECT 25, 'Zoe Molina'
  UNION ALL SELECT 26, 'Andrés Vázquez'       UNION ALL SELECT 27, 'Belén Silva'
  UNION ALL SELECT 28, 'Cristian Medina'      UNION ALL SELECT 29, 'Daniela Acosta'
  UNION ALL SELECT 30, 'Emiliano Torres'      UNION ALL SELECT 31, 'Florencia Ríos'
  UNION ALL SELECT 32, 'Gonzalo Sánchez'      UNION ALL SELECT 33, 'Julieta Romero'
  UNION ALL SELECT 34, 'Lautaro Benítez'      UNION ALL SELECT 35, 'Marcela Ibáñez'
  UNION ALL SELECT 36, 'Nicolás Quiroga'      UNION ALL SELECT 37, 'Paula Cardozo'
  UNION ALL SELECT 38, 'Ramiro Ayala'         UNION ALL SELECT 39, 'Sofía Montenegro'
  UNION ALL SELECT 40, 'Tomás Funes'
) n
-- Si ese email ya es de otra cuenta, no se carga (y nunca se le cambia nada a esa cuenta).
WHERE NOT EXISTS (SELECT 1 FROM usuario o
                  WHERE o.id <> 3000 + n.i
                    AND o.email = CONCAT(LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(n.nombre, ' ', '.'), 'á', 'a'),
                                  'é', 'e'), 'í', 'i'), 'ó', 'o'), 'ú', 'u'), 'ñ', 'n')), n.i + 60, '@gmail.com'))
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre), email = VALUES(email), password_hash = VALUES(password_hash),
  telefono = VALUES(telefono), rol = VALUES(rol);

INSERT INTO usuario
  (id, nombre, email, password_hash, telefono, rol, organizacion, estado_validacion,
   intentos_fallidos, primer_fallo_en, bloqueado_hasta)
SELECT * FROM (
  SELECT 3041, 'Marta Quiroga',  'refugiosanroque.lujan@gmail.com', '!sin-acceso-cuenta-de-fondo', NULL, 'RESCATISTA', 'Refugio San Roque',  'APROBADO', 0, NULL, NULL
  UNION ALL SELECT 3042, 'Sergio Molina',  'cuatropatas.lujan@gmail.com',    '!sin-acceso-cuenta-de-fondo', NULL, 'RESCATISTA', 'Cuatro Patas Luján', 'APROBADO', 0, NULL, NULL
  UNION ALL SELECT 3043, 'Laura Vega',     'hogarpeludo.mercedes@gmail.com', '!sin-acceso-cuenta-de-fondo', NULL, 'RESCATISTA', 'Hogar Peludo',       'APROBADO', 0, NULL, NULL
  UNION ALL SELECT 3044, 'Ramiro Castro',  'rescateoeste.gral.rodriguez@gmail.com', '!sin-acceso-cuenta-de-fondo', NULL, 'RESCATISTA', 'Rescate Oeste', 'APROBADO', 0, NULL, NULL
  UNION ALL SELECT 3045, 'Paula Medina',   'amigosdelbarrio.open@gmail.com', '!sin-acceso-cuenta-de-fondo', NULL, 'RESCATISTA', 'Amigos del Barrio',  'APROBADO', 0, NULL, NULL
) r (id, nombre, email, password_hash, telefono, rol, organizacion, estado_validacion, intentos_fallidos, primer_fallo_en, bloqueado_hasta)
WHERE NOT EXISTS (SELECT 1 FROM usuario o WHERE o.email = r.email AND o.id <> r.id)
ON DUPLICATE KEY UPDATE
  nombre = VALUES(nombre), email = VALUES(email), password_hash = VALUES(password_hash),
  telefono = VALUES(telefono), rol = VALUES(rol), organizacion = VALUES(organizacion),
  estado_validacion = VALUES(estado_validacion);

-- Mascotas de los clientes de fondo: dos cada uno. Nombre, especie y raza salen de listas reales;
-- la edad va de cachorro a senior.
INSERT INTO mascota
  (id, duenio_id, nombre, especie, raza, fecha_nacimiento, peso_kg, foto, foto_tipo, activo)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 80)
SELECT 30000 + i,
       3001 + (i - 1) DIV 2,
       ELT(i, 'Toby', 'Mora', 'Coco', 'Lola', 'Rocky', 'Nala', 'Bobby', 'Kira', 'Max', 'Mía',
              'Thor', 'Frida', 'Bruno', 'Olivia', 'Zeus', 'Pelusa', 'Tango', 'Uma', 'Ramón', 'Chispa',
              'Oreo', 'Manchita', 'Pancho', 'Luz', 'Duque', 'Canela', 'Milo', 'Sasha', 'Pipo', 'Greta',
              'Simón', 'Brisa', 'Fermín', 'Nina', 'Tobías', 'Lila', 'Felipe', 'Matilda', 'Benito', 'Bella',
              'Jazmín', 'Roco', 'Kiara', 'Lucho', 'Malena', 'Dante', 'Pupi', 'Ciro', 'Maya', 'Hércules',
              'Luna', 'Rufo', 'Clara', 'Gordo', 'Paloma', 'Indio', 'Lupe', 'Moro', 'Tita', 'Bambi',
              'Sultán', 'Copito', 'Rita', 'Panchito', 'Fiona', 'Negro', 'Cleo', 'Bigote', 'Nube', 'Teo',
              'Frodo', 'Melón', 'Juana', 'Atilio', 'Pochi', 'Vito', 'Cachi', 'Rubia', 'Salvador', 'Cuca'),
       IF(i % 3 = 0, 'GATO', 'PERRO'),
       IF(i % 3 = 0,
          ELT(1 + (i % 5), 'Europeo común', 'Siamés', 'Persa', 'Maine coon', 'Angora'),
          ELT(1 + (i % 9), 'Mestizo', 'Caniche toy', 'Labrador retriever', 'Ovejero alemán', 'Beagle',
              'Golden retriever', 'Bulldog francés', 'Border collie', 'Dachshund')),
       @hoy - INTERVAL (5 + (i * 17) % 150) MONTH - INTERVAL (i * 7) % 28 DAY,
       IF(i % 3 = 0, 3.20 + (i % 5) * 0.6, ELT(1 + (i % 9), 14.5, 4.2, 31.0, 34.5, 12.8, 30.2, 11.6, 19.4, 8.9)),
       NULL, NULL, 1
FROM n
ON DUPLICATE KEY UPDATE
  duenio_id = VALUES(duenio_id), nombre = VALUES(nombre), especie = VALUES(especie), raza = VALUES(raza),
  fecha_nacimiento = VALUES(fecha_nacimiento), peso_kg = VALUES(peso_kg), activo = VALUES(activo);

-- Las mascotas de las cuentas de la demo.
INSERT INTO mascota
  (id, duenio_id, nombre, especie, raza, fecha_nacimiento, peso_kg, foto, foto_tipo, activo)
VALUES
  (30081, @cliente1, 'Rocco', 'PERRO', 'Labrador retriever', @hoy - INTERVAL 4 YEAR - INTERVAL 3 MONTH, 32.40, NULL, NULL, 1),
  (30082, @cliente1, 'Mishi', 'GATO',  'Europeo común',      @hoy - INTERVAL 2 YEAR - INTERVAL 7 MONTH,  4.10, NULL, NULL, 1),
  (30083, @cliente1, 'Coco',  'PERRO', 'Caniche toy',        @hoy - INTERVAL 9 YEAR - INTERVAL 1 MONTH,  5.30, NULL, NULL, 1),
  (30084, @cliente2, 'Lola',  'PERRO', 'Beagle',             @hoy - INTERVAL 14 MONTH,                 11.20, NULL, NULL, 1)
ON DUPLICATE KEY UPDATE
  duenio_id = VALUES(duenio_id), nombre = VALUES(nombre), especie = VALUES(especie), raza = VALUES(raza),
  fecha_nacimiento = VALUES(fecha_nacimiento), peso_kg = VALUES(peso_kg), activo = VALUES(activo);

-- Mascotas a cargo de los rescatistas (las de las adopciones finalizadas pasan al adoptante en 004).
INSERT INTO mascota
  (id, duenio_id, nombre, especie, raza, fecha_nacimiento, peso_kg, foto, foto_tipo, activo)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 44)
SELECT 30100 + i,
       IF(i <= 40, 3041 + (i % 5), @rescatista),
       ELT(i, 'Chocolate', 'Vainilla', 'Pirata', 'Morena', 'Tito', 'Lupita', 'Negrita', 'Ruperto',
              'Dama', 'Fito', 'Gala', 'Hugo', 'Isis', 'Jack', 'Kala', 'León', 'Mimí', 'Nilo', 'Osa',
              'Pocho', 'Quena', 'Rulo', 'Sol', 'Tirso', 'Uva', 'Vera', 'Wally', 'Yuyo', 'Zamba',
              'Arena', 'Bombón', 'Corcho', 'Dulce', 'Estrella', 'Fresco', 'Gringo', 'Honda', 'Iris',
              'Junco', 'Kika', 'Manolo', 'Pimienta', 'Bartolo', 'Nieve'),
       IF(i % 2 = 0, 'GATO', 'PERRO'),
       IF(i % 2 = 0, 'Europeo común', 'Mestizo'),
       @hoy - INTERVAL (3 + (i * 7) % 60) MONTH,
       IF(i % 2 = 0, 2.50 + (i % 3) * 0.7, 6.00 + (i % 18)),
       NULL, NULL, 1
FROM n
ON DUPLICATE KEY UPDATE
  duenio_id = VALUES(duenio_id), nombre = VALUES(nombre), especie = VALUES(especie), raza = VALUES(raza),
  fecha_nacimiento = VALUES(fecha_nacimiento), peso_kg = VALUES(peso_kg), activo = VALUES(activo);
