-- Volumen 004 · adopciones en todos los estados (publicaciones y adopciones 20001 a 20040, de las
-- mascotas 20101 a 20140 del volumen 001; "i" es el número del 1 al 40)
--
--   i  1 a  4   publicada, sin postulantes
--   i  5 a 12   con postulantes (2 a 4 cada una; el cliente de prueba 102 se postuló a las 5 a 8)
--   i 13 a 16   publicación esperando la moderación (sin adopción todavía)
--   i 17 a 18   publicación rechazada
--   i 19 a 22   adoptante elegido
--   i 23 a 25   chequeo pendiente (turno de chequeo en los próximos días, 19:30)
--   i 26 a 37   finalizada: dos hace exactamente 30 días y dos hace 90 (el motor manda los
--               controles de esos días), el resto entre 5 y 150 días; la mascota pasa al adoptante
--   i 38 a 40   cancelada
--   Turnos de chequeo: 20801 a 20840 (Veterinario Dos, 19:00 o 19:30: no chocan con los demás).
--   Postulaciones: 20000 + i * 10 + k.
-- Correr de nuevo deja todo como estaba, con las fechas corridas a hoy.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);
SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;
SET @foto = FROM_BASE64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

-- 1. Lo que se hizo al probar sobre las mascotas del volumen, en orden (por las claves foráneas).
--    Las consultas de los chequeos del volumen (por ejemplo, atender uno pendiente): se borran
--    para que el chequeo se pueda atender de nuevo.
DELETE f FROM factura_consulta f JOIN consulta c ON c.id = f.consulta_id WHERE c.turno_id BETWEEN 20801 AND 20840;
DELETE i FROM item_insumo_consulta i JOIN consulta c ON c.id = i.consulta_id WHERE c.turno_id BETWEEN 20801 AND 20840;
DELETE i FROM item_producto_consulta i JOIN consulta c ON c.id = i.consulta_id WHERE c.turno_id BETWEEN 20801 AND 20840;
UPDATE evento_sanitario e JOIN consulta c ON c.id = e.consulta_id
  SET e.consulta_id = NULL, e.fecha_aplicada = NULL WHERE c.turno_id BETWEEN 20801 AND 20840;
DELETE FROM consulta WHERE turno_id BETWEEN 20801 AND 20840;
UPDATE turno SET estado = 'CANCELADO'
  WHERE mascota_id BETWEEN 20101 AND 20140 AND motivo = 'CHEQUEO_ADOPCION'
    AND estado IN ('PROGRAMADO', 'EN_ATENCION') AND id NOT BETWEEN 20801 AND 20840;
DELETE po FROM postulacion po
  JOIN adopcion a ON a.id = po.adopcion_id
  JOIN publicacion pu ON pu.id = a.publicacion_id
  WHERE pu.mascota_id BETWEEN 20101 AND 20140 AND po.id NOT BETWEEN 20011 AND 20403;
DELETE a FROM adopcion a
  JOIN publicacion pu ON pu.id = a.publicacion_id
  WHERE pu.mascota_id BETWEEN 20101 AND 20140 AND a.id NOT BETWEEN 20001 AND 20040;
-- El historial de rechazos (migración 023) de estas mascotas: se vuelve a cargar abajo.
DELETE pr FROM publicacion_rechazo pr
  JOIN publicacion pu ON pu.id = pr.publicacion_id
  WHERE pu.mascota_id BETWEEN 20101 AND 20140;
DELETE FROM publicacion
  WHERE mascota_id BETWEEN 20101 AND 20140 AND id NOT BETWEEN 20001 AND 20040;
-- Las postulaciones de la carga anterior: se cargan de nuevo abajo.
DELETE FROM postulacion WHERE adopcion_id BETWEEN 20001 AND 20040;

-- 2. Datos de cada adopción, en una tabla temporal (la usan varios INSERT de abajo).
--    dias_fin: hace cuántos días terminó (finalizadas y canceladas).
--    Lleva clave primaria: Aiven tiene sql_require_primary_key=ON y no deja crear una tabla sin
--    ella (tampoco una temporal), por eso se crea primero y se llena después.
DROP TEMPORARY TABLE IF EXISTS vol_adopcion;
CREATE TEMPORARY TABLE vol_adopcion (
  i         INT          NOT NULL,
  estado    VARCHAR(20)  NULL,
  adoptante INT UNSIGNED NOT NULL,
  dias_fin  INT          NULL,
  creada    DATETIME     NOT NULL,
  PRIMARY KEY (i)
);
INSERT INTO vol_adopcion (i, estado, adoptante, dias_fin, creada)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 40)
SELECT i,
       CASE
         WHEN i <= 4 THEN 'PUBLICADA'
         WHEN i <= 12 THEN 'CON_POSTULANTES'
         WHEN i <= 18 THEN NULL
         WHEN i <= 22 THEN 'ADOPTANTE_ELEGIDO'
         WHEN i <= 25 THEN 'CHEQUEO_PENDIENTE'
         WHEN i <= 37 THEN 'FINALIZADA'
         ELSE 'CANCELADA'
       END AS estado,
       2002 + ((i * 7) % 40) AS adoptante,
       CASE
         WHEN i BETWEEN 26 AND 37 THEN ELT(i - 25, 30, 30, 90, 90, 5, 12, 20, 45, 60, 75, 120, 150)
         WHEN i >= 38 THEN i - 30
         ELSE NULL
       END AS dias_fin,
       @ahora - INTERVAL (5 + i * 4) DAY AS creada
FROM n;

-- 3. Las mascotas: a cargo del rescatista, o del adoptante si la adopción terminó.
UPDATE mascota m JOIN vol_adopcion v ON m.id = 20100 + v.i
  SET m.duenio_id = IF(v.estado = 'FINALIZADA', v.adoptante, 2042 + (v.i % 5));

-- 4. Los turnos de chequeo (cancelados primero: al correr las fechas no tienen que chocar).
UPDATE turno SET estado = 'CANCELADO' WHERE id BETWEEN 20801 AND 20840;
INSERT INTO turno (id, mascota_id, veterinario_id, fecha, hora, motivo, estado)
SELECT 20800 + i, 20100 + i, 2001,
       IF(estado = 'FINALIZADA', DATE(@hoy - INTERVAL dias_fin DAY) - INTERVAL 1 DAY, @hoy + INTERVAL (i - 21) DAY),
       IF(estado = 'FINALIZADA' AND i % 2 = 0, '19:00:00', '19:30:00'),
       'CHEQUEO_ADOPCION',
       IF(estado = 'FINALIZADA', 'ATENDIDO', 'PROGRAMADO')
FROM vol_adopcion
WHERE estado IN ('CHEQUEO_PENDIENTE', 'FINALIZADA')
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id), veterinario_id = VALUES(veterinario_id), fecha = VALUES(fecha),
  hora = VALUES(hora), motivo = VALUES(motivo), estado = VALUES(estado);

-- 5. Las publicaciones.
INSERT INTO publicacion
  (id, rescatista_id, mascota_id, titulo, descripcion, foto, foto_tipo, estado_moderacion,
   motivo_rechazo, activa, creada_en)
SELECT 20000 + v.i, 2042 + (v.i % 5), 20100 + v.i,
       CONCAT(m.nombre, ' busca familia'),
       CONCAT(IF(m.especie = 'GATO', 'Gato', 'Perro'), ' rescatado, sociable y con las vacunas al día. ',
              'Publicación de prueba del juego de datos en cantidad.'),
       @foto, 'image/png',
       CASE WHEN v.i BETWEEN 13 AND 16 THEN 'PENDIENTE' WHEN v.i BETWEEN 17 AND 18 THEN 'RECHAZADA' ELSE 'APROBADA' END,
       IF(v.i BETWEEN 17 AND 18, 'Las fotos no muestran bien a la mascota.', NULL),
       IF(v.estado IN ('FINALIZADA', 'CANCELADA'), 0, 1),
       v.creada
FROM vol_adopcion v JOIN mascota m ON m.id = 20100 + v.i
ON DUPLICATE KEY UPDATE
  rescatista_id = VALUES(rescatista_id), mascota_id = VALUES(mascota_id), titulo = VALUES(titulo),
  descripcion = VALUES(descripcion), foto = VALUES(foto), foto_tipo = VALUES(foto_tipo),
  estado_moderacion = VALUES(estado_moderacion), motivo_rechazo = VALUES(motivo_rechazo),
  activa = VALUES(activa), creada_en = VALUES(creada_en);

-- 5b. El historial de rechazos (migración 023): las rechazadas, unas horas después de publicarse.
INSERT INTO publicacion_rechazo (id, publicacion_id, motivo, rechazada_en, rechazada_por)
SELECT 20000 + i, 20000 + i, 'Las fotos no muestran bien a la mascota.', creada + INTERVAL 3 HOUR, 101
FROM vol_adopcion WHERE i BETWEEN 17 AND 18
ON DUPLICATE KEY UPDATE publicacion_id = VALUES(publicacion_id), motivo = VALUES(motivo),
  rechazada_en = VALUES(rechazada_en), rechazada_por = VALUES(rechazada_por);

-- 6. Las adopciones (las publicaciones pendientes o rechazadas no tienen).
INSERT INTO adopcion (id, publicacion_id, estado, adoptante_id, turno_chequeo_id, fecha_inicio, fecha_fin)
SELECT 20000 + i, 20000 + i, estado,
       IF(estado IN ('ADOPTANTE_ELEGIDO', 'CHEQUEO_PENDIENTE', 'FINALIZADA'), adoptante, NULL),
       IF(estado IN ('CHEQUEO_PENDIENTE', 'FINALIZADA'), 20800 + i, NULL),
       creada,
       IF(dias_fin IS NULL, NULL, TIMESTAMP(@hoy - INTERVAL dias_fin DAY, '10:00:00'))
FROM vol_adopcion
WHERE estado IS NOT NULL
ON DUPLICATE KEY UPDATE
  publicacion_id = VALUES(publicacion_id), estado = VALUES(estado), adoptante_id = VALUES(adoptante_id),
  turno_chequeo_id = VALUES(turno_chequeo_id), fecha_inicio = VALUES(fecha_inicio), fecha_fin = VALUES(fecha_fin);

-- 7. Las postulaciones: k = 0 es el adoptante (ELEGIDA cuando ya se eligió; el resto, RECHAZADA).
--    Con postulantes: de 2 a 4, pendientes. El cliente de prueba 102 se postuló a las 5 a 8.
INSERT INTO postulacion
  (id, adopcion_id, cliente_id, tipo_vivienda, otras_mascotas, tiempo_disponible, estado, fecha)
WITH RECURSIVE k AS (SELECT 0 AS k UNION ALL SELECT k + 1 FROM k WHERE k < 3)
SELECT 20000 + v.i * 10 + k.k, 20000 + v.i,
       IF(k.k = 3, 102, IF(k.k = 0, v.adoptante, 2002 + ((v.i * 7 + k.k * 11) % 40))),
       ELT(1 + ((v.i + k.k) % 3), 'Casa con patio', 'Departamento', 'PH con terraza'),
       ELT(1 + ((v.i + k.k) % 3), 'Ninguna', 'Un perro', 'Dos gatos'),
       ELT(1 + ((v.i + k.k) % 3), 'Trabajo desde casa', 'Medio día', 'Toda la tarde'),
       CASE
         WHEN v.estado IN ('PUBLICADA', 'CON_POSTULANTES') THEN 'PENDIENTE'
         WHEN k.k = 0 THEN 'ELEGIDA'
         ELSE 'RECHAZADA'
       END,
       v.creada + INTERVAL (k.k + 1) DAY
FROM vol_adopcion v CROSS JOIN k
WHERE (v.estado = 'CON_POSTULANTES' AND (k.k <= 1 + (v.i % 3) OR (k.k = 3 AND v.i <= 8)))
   OR (v.estado IN ('ADOPTANTE_ELEGIDO', 'CHEQUEO_PENDIENTE', 'FINALIZADA') AND k.k <= 2);

DROP TEMPORARY TABLE IF EXISTS vol_adopcion;
