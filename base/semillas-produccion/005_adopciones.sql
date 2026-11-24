-- Producción 005 · adopciones en todos los estados (publicaciones y adopciones 30001 a 30044, de las
-- mascotas 30101 a 30144 de 001; "i" es el número del 1 al 44). Va después de 004: la foto de cada
-- publicación es la de su mascota.
--
--   i  1 a  4   publicada, sin postulantes
--   i  5 a 12   con postulantes (2 a 4 cada una; el cliente de la demo 1 se postuló a la 5 y a la 6)
--   i 13 a 16   esperando la moderación
--   i 17 a 18   rechazada por la veterinaria
--   i 19 a 22   adoptante elegido
--   i 23 a 25   chequeo pendiente (turno de chequeo en los próximos días, 19:30)
--   i 26 a 37   finalizada: dos hace exactamente 30 días y dos hace 90 (el motor manda los controles
--               de esos días), el resto entre 5 y 150 días; la mascota pasa al adoptante
--   i 38 a 40   cancelada
--   i 41 a 44   las del rescatista de la demo: 41 esperando la moderación, 42 con postulantes, 43
--               publicada sin postulantes (para que el cliente 2 se postule en la demo), 44 finalizada.
--   Turnos de chequeo: 30801 a 30844 (19:10 o 19:40; si ese horario ya está ocupado por un turno
--   cargado a mano, el chequeo queda cancelado y no lo pisa). Postulaciones: 30000 + i * 10 + k.
-- Correr de nuevo deja todo como estaba, con las fechas corridas a hoy.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);
SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

-- 1. Lo que se hizo en la demo sobre estas mascotas, en orden (por las claves foráneas).
DELETE f FROM factura_consulta f JOIN consulta c ON c.id = f.consulta_id WHERE c.turno_id BETWEEN 30801 AND 30844;
DELETE i FROM item_insumo_consulta i JOIN consulta c ON c.id = i.consulta_id WHERE c.turno_id BETWEEN 30801 AND 30844;
DELETE i FROM item_producto_consulta i JOIN consulta c ON c.id = i.consulta_id WHERE c.turno_id BETWEEN 30801 AND 30844;
UPDATE evento_sanitario e JOIN consulta c ON c.id = e.consulta_id
  SET e.consulta_id = NULL, e.fecha_aplicada = NULL WHERE c.turno_id BETWEEN 30801 AND 30844;
DELETE FROM consulta WHERE turno_id BETWEEN 30801 AND 30844;
UPDATE turno SET estado = 'CANCELADO'
  WHERE mascota_id BETWEEN 30101 AND 30144 AND motivo = 'CHEQUEO_ADOPCION'
    AND estado IN ('PROGRAMADO', 'EN_ATENCION') AND id NOT BETWEEN 30801 AND 30844;
DELETE po FROM postulacion po
  JOIN adopcion a ON a.id = po.adopcion_id
  JOIN publicacion pu ON pu.id = a.publicacion_id
  WHERE pu.mascota_id BETWEEN 30101 AND 30144 AND po.id NOT BETWEEN 30011 AND 30443;
DELETE a FROM adopcion a
  JOIN publicacion pu ON pu.id = a.publicacion_id
  WHERE pu.mascota_id BETWEEN 30101 AND 30144 AND a.id NOT BETWEEN 30001 AND 30044;
DELETE FROM publicacion
  WHERE mascota_id BETWEEN 30101 AND 30144 AND id NOT BETWEEN 30001 AND 30044;
DELETE FROM postulacion WHERE adopcion_id BETWEEN 30001 AND 30044;

-- 2. Datos de cada adopción, en una tabla temporal (con clave primaria: Aiven la exige).
DROP TEMPORARY TABLE IF EXISTS prod_adopcion;
CREATE TEMPORARY TABLE prod_adopcion (
  i          INT          NOT NULL,
  estado     VARCHAR(20)  NULL,
  moderacion VARCHAR(20)  NOT NULL,
  rescatista INT UNSIGNED NOT NULL,
  adoptante  INT UNSIGNED NOT NULL,
  dias_fin   INT          NULL,
  creada     DATETIME     NOT NULL,
  PRIMARY KEY (i)
);
INSERT INTO prod_adopcion (i, estado, moderacion, rescatista, adoptante, dias_fin, creada)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 44)
SELECT i,
       CASE
         WHEN i = 41 THEN NULL
         WHEN i = 42 THEN 'CON_POSTULANTES'
         WHEN i = 43 THEN 'PUBLICADA'
         WHEN i = 44 THEN 'FINALIZADA'
         WHEN i <= 4 THEN 'PUBLICADA'
         WHEN i <= 12 THEN 'CON_POSTULANTES'
         WHEN i <= 18 THEN NULL
         WHEN i <= 22 THEN 'ADOPTANTE_ELEGIDO'
         WHEN i <= 25 THEN 'CHEQUEO_PENDIENTE'
         WHEN i <= 37 THEN 'FINALIZADA'
         ELSE 'CANCELADA'
       END,
       CASE WHEN i IN (41) OR i BETWEEN 13 AND 16 THEN 'PENDIENTE'
            WHEN i BETWEEN 17 AND 18 THEN 'RECHAZADA'
            ELSE 'APROBADA' END,
       IF(i <= 40, 3041 + (i % 5), @rescatista),
       3001 + ((i * 7) % 40),
       CASE
         WHEN i = 44 THEN 40
         WHEN i BETWEEN 26 AND 37 THEN ELT(i - 25, 30, 30, 90, 90, 5, 12, 20, 45, 60, 75, 120, 150)
         WHEN i BETWEEN 38 AND 40 THEN i - 30
         ELSE NULL
       END,
       @ahora - INTERVAL (IF(i > 40, i - 38, 5 + i * 4)) DAY - INTERVAL (i * 3) % 10 HOUR
FROM n;

-- 3. Las mascotas: a cargo del rescatista, o del adoptante si la adopción terminó.
UPDATE mascota m JOIN prod_adopcion v ON m.id = 30100 + v.i
  SET m.duenio_id = IF(v.estado = 'FINALIZADA', v.adoptante, v.rescatista);

-- 4. Los turnos de chequeo (cancelados primero: al correr las fechas no tienen que chocar).
UPDATE turno SET estado = 'CANCELADO' WHERE id BETWEEN 30801 AND 30844;
INSERT INTO turno (id, mascota_id, veterinario_id, fecha, hora, motivo, estado, precio_consulta, descuento, promocion_franja_id)
SELECT 30800 + c.i, 30100 + c.i, @vet,
       c.fecha, c.hora, 'CHEQUEO_ADOPCION',
       IF(EXISTS (SELECT 1 FROM turno o
                  WHERE o.veterinario_id = @vet AND o.fecha = c.fecha AND o.hora = c.hora
                    AND o.estado <> 'CANCELADO' AND o.id NOT BETWEEN 30801 AND 30844),
          'CANCELADO', IF(c.estado = 'FINALIZADA', 'ATENDIDO', 'PROGRAMADO')),
       15000.00, NULL, NULL
FROM (
  SELECT i, estado,
         IF(estado = 'FINALIZADA', DATE(@hoy - INTERVAL dias_fin DAY) - INTERVAL 1 DAY, @hoy + INTERVAL (i - 21) DAY) AS fecha,
         IF(estado = 'FINALIZADA' AND i % 2 = 0, '19:10:00', '19:40:00') AS hora
  FROM prod_adopcion
  WHERE estado IN ('CHEQUEO_PENDIENTE', 'FINALIZADA')
) c
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id), veterinario_id = VALUES(veterinario_id), fecha = VALUES(fecha),
  hora = VALUES(hora), motivo = VALUES(motivo), estado = VALUES(estado), precio_consulta = VALUES(precio_consulta);

-- 5. Las publicaciones, con la foto de la mascota y una descripción armada con su carácter.
INSERT INTO publicacion
  (id, rescatista_id, mascota_id, titulo, descripcion, foto, foto_tipo, estado_moderacion,
   motivo_rechazo, activa, creada_en)
SELECT 30000 + v.i, v.rescatista, 30100 + v.i,
       CONCAT(m.nombre, ' busca familia'),
       CONCAT(
         IF(m.especie = 'GATO', 'Gato', 'Perro'), ' ',
         IF(TIMESTAMPDIFF(MONTH, m.fecha_nacimiento, @hoy) < 12, 'cachorro', 'adulto'), ' ',
         ELT(1 + (v.i % 6), 'muy cariñoso y tranquilo', 'juguetón y lleno de energía', 'un poco tímido al principio, pero muy dulce',
             'sociable con otros animales', 'ideal para departamento', 'compañero y muy obediente'),
         '. ',
         ELT(1 + (v.i % 4), 'Lo rescatamos de la calle en el barrio Ameghino.', 'Llegó al refugio después de un abandono.',
             'Lo encontramos junto a la ruta 5 y se recuperó muy bien.', 'Vivía en una obra en construcción.'),
         ' Tiene las vacunas al día', IF(v.i % 3 = 0, ', está castrado', ''),
         ' y se entrega con seguimiento. ',
         IF(m.especie = 'GATO', 'Usa el arenero sin problemas.', 'Sabe caminar con correa.')),
       m.foto, m.foto_tipo,
       v.moderacion,
       IF(v.moderacion = 'RECHAZADA', 'La foto no muestra bien a la mascota: subí una más clara.', NULL),
       IF(v.estado IN ('FINALIZADA', 'CANCELADA'), 0, 1),
       v.creada
FROM prod_adopcion v JOIN mascota m ON m.id = 30100 + v.i
ON DUPLICATE KEY UPDATE
  rescatista_id = VALUES(rescatista_id), mascota_id = VALUES(mascota_id), titulo = VALUES(titulo),
  descripcion = VALUES(descripcion), foto = VALUES(foto), foto_tipo = VALUES(foto_tipo),
  estado_moderacion = VALUES(estado_moderacion), motivo_rechazo = VALUES(motivo_rechazo),
  activa = VALUES(activa), creada_en = VALUES(creada_en);

-- 6. Las adopciones (las publicaciones pendientes o rechazadas no tienen).
INSERT INTO adopcion (id, publicacion_id, estado, adoptante_id, turno_chequeo_id, fecha_inicio, fecha_fin)
SELECT 30000 + i, 30000 + i, estado,
       IF(estado IN ('ADOPTANTE_ELEGIDO', 'CHEQUEO_PENDIENTE', 'FINALIZADA'), adoptante, NULL),
       IF(estado IN ('CHEQUEO_PENDIENTE', 'FINALIZADA'), 30800 + i, NULL),
       creada,
       IF(dias_fin IS NULL, NULL, TIMESTAMP(@hoy - INTERVAL dias_fin DAY, '10:00:00'))
FROM prod_adopcion
WHERE estado IS NOT NULL
ON DUPLICATE KEY UPDATE
  publicacion_id = VALUES(publicacion_id), estado = VALUES(estado), adoptante_id = VALUES(adoptante_id),
  turno_chequeo_id = VALUES(turno_chequeo_id), fecha_inicio = VALUES(fecha_inicio), fecha_fin = VALUES(fecha_fin);

-- 7. Las postulaciones: k = 0 es el adoptante (ELEGIDA cuando ya se eligió; el resto, RECHAZADA).
--    Con postulantes: de 2 a 4, pendientes. k = 3 es el cliente de la demo 1, en la 5 y la 6.
INSERT INTO postulacion
  (id, adopcion_id, cliente_id, tipo_vivienda, otras_mascotas, tiempo_disponible, estado, fecha)
WITH RECURSIVE k AS (SELECT 0 AS k UNION ALL SELECT k + 1 FROM k WHERE k < 3)
SELECT 30000 + v.i * 10 + k.k, 30000 + v.i,
       IF(k.k = 3 AND v.i IN (5, 6), @cliente1, IF(k.k = 0, v.adoptante, 3001 + ((v.i * 7 + k.k * 11) % 40))),
       ELT(1 + ((v.i + k.k) % 4), 'Casa con patio', 'Departamento con balcón', 'PH con terraza', 'Casa en barrio cerrado'),
       ELT(1 + ((v.i + k.k) % 4), 'Ninguna', 'Un perro adulto', 'Dos gatos', 'Un gato castrado'),
       ELT(1 + ((v.i + k.k) % 4), 'Trabajo desde casa', 'Medio día', 'Toda la tarde', 'Somos cuatro en casa, siempre hay alguien'),
       CASE
         WHEN v.estado IN ('PUBLICADA', 'CON_POSTULANTES') THEN 'PENDIENTE'
         WHEN k.k = 0 THEN 'ELEGIDA'
         ELSE 'RECHAZADA'
       END,
       v.creada + INTERVAL (k.k + 1) DAY
FROM prod_adopcion v CROSS JOIN k
WHERE (v.estado = 'CON_POSTULANTES' AND (k.k <= 1 + (v.i % 3) OR (k.k = 3 AND v.i IN (5, 6))))
   OR (v.estado IN ('ADOPTANTE_ELEGIDO', 'CHEQUEO_PENDIENTE', 'FINALIZADA') AND k.k <= 2);

DROP TEMPORARY TABLE IF EXISTS prod_adopcion;
