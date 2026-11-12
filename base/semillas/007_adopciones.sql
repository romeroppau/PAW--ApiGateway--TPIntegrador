-- Semilla 007 · adopciones de prueba (rescatistas 104 aprobada y 105 pendiente, de la semilla 001)
-- Correr las semillas de nuevo vuelve todo a su estado inicial: borra lo que crearon las pruebas
-- sobre estas mascotas (publicaciones, adopciones y postulaciones nuevas) y las devuelve a su dueño.
--
-- Las mascotas y el turno usan ids desde 901: en dev, los ids 105 en adelante ya los usan las
-- mascotas y los turnos que crea el humo. Las tablas de adopciones son nuevas y empiezan en 101.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);
SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

-- Foto de prueba (PNG de 1 x 1). La foto es obligatoria en una publicación.
SET @foto = FROM_BASE64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

-- Mascotas:
--   901 Canela: a cargo de la rescatista 104, sin publicar (para probar "publicar").
--   902 Pipa:   a cargo de la 104, publicación 101 aprobada y adopción 101 con una postulación.
--   903 Rocco:  a cargo de la 104, publicación 102 esperando la moderación.
--   904 Simba:  adoptado por el cliente 103 hace 30 días (adopción 103 finalizada, para el motor).
INSERT INTO mascota
  (id, duenio_id, nombre, especie, raza, fecha_nacimiento, peso_kg, foto, foto_tipo, activo)
VALUES
  (901, 104, 'Canela', 'PERRO', 'Mestiza', @hoy - INTERVAL 1 YEAR,   12.00, NULL, NULL, 1),
  (902, 104, 'Pipa',   'GATO',  NULL,      @hoy - INTERVAL 6 MONTH,   2.10, NULL, NULL, 1),
  (903, 104, 'Rocco',  'PERRO', 'Mestizo', @hoy - INTERVAL 2 YEAR,   20.00, NULL, NULL, 1),
  (904, 103, 'Simba',  'GATO',  NULL,      @hoy - INTERVAL 1 YEAR,    3.50, NULL, NULL, 1)
ON DUPLICATE KEY UPDATE
  duenio_id = VALUES(duenio_id),
  nombre = VALUES(nombre),
  especie = VALUES(especie),
  raza = VALUES(raza),
  fecha_nacimiento = VALUES(fecha_nacimiento),
  peso_kg = VALUES(peso_kg),
  foto = VALUES(foto),
  foto_tipo = VALUES(foto_tipo),
  activo = VALUES(activo);

-- Los chequeos que cargaron las pruebas sobre estas mascotas quedan cancelados: si no, ocuparían
-- su horario y la próxima corrida no podría cargarlos de nuevo.
UPDATE turno
SET estado = 'CANCELADO'
WHERE mascota_id IN (901, 902, 903, 904)
  AND motivo = 'CHEQUEO_ADOPCION'
  AND estado IN ('PROGRAMADO', 'EN_ATENCION')
  AND id <> 901;

-- El chequeo (atendido) de la adopción finalizada de Simba.
INSERT INTO turno
  (id, mascota_id, veterinario_id, fecha, hora, motivo, estado)
VALUES
  (901, 904, 101, @hoy - INTERVAL 31 DAY, '08:00', 'CHEQUEO_ADOPCION', 'ATENDIDO')
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id),
  veterinario_id = VALUES(veterinario_id),
  fecha = VALUES(fecha),
  hora = VALUES(hora),
  motivo = VALUES(motivo),
  estado = VALUES(estado);

-- Lo que crearon las pruebas sobre estas mascotas, en orden (por las claves foráneas).
DELETE po FROM postulacion po
  JOIN adopcion a ON a.id = po.adopcion_id
  JOIN publicacion pu ON pu.id = a.publicacion_id
WHERE pu.mascota_id IN (901, 902, 903, 904) AND po.id <> 101;

DELETE a FROM adopcion a
  JOIN publicacion pu ON pu.id = a.publicacion_id
WHERE pu.mascota_id IN (901, 902, 903, 904) AND a.id NOT IN (101, 103);

DELETE FROM publicacion
WHERE mascota_id IN (901, 902, 903, 904) AND id NOT IN (101, 102, 103);

INSERT INTO publicacion
  (id, rescatista_id, mascota_id, titulo, descripcion, foto, foto_tipo, estado_moderacion,
   motivo_rechazo, activa, creada_en)
VALUES
  (101, 104, 902, 'Pipa busca familia',
   'Gatita de 6 meses, muy cariñosa. Está vacunada y desparasitada. Se lleva bien con otros gatos.',
   @foto, 'image/png', 'APROBADA', NULL, 1, @ahora - INTERVAL 6 DAY),
  (102, 104, 903, 'Rocco, compañero para salir a caminar',
   'Perro de 2 años, tranquilo y juguetón. Necesita un patio o paseos diarios.',
   @foto, 'image/png', 'PENDIENTE', NULL, 1, @ahora - INTERVAL 1 DAY),
  (103, 104, 904, 'Simba en adopción',
   'Gato de un año, tranquilo. Ya encontró familia.',
   @foto, 'image/png', 'APROBADA', NULL, 0, @ahora - INTERVAL 60 DAY)
ON DUPLICATE KEY UPDATE
  rescatista_id = VALUES(rescatista_id),
  mascota_id = VALUES(mascota_id),
  titulo = VALUES(titulo),
  descripcion = VALUES(descripcion),
  foto = VALUES(foto),
  foto_tipo = VALUES(foto_tipo),
  estado_moderacion = VALUES(estado_moderacion),
  motivo_rechazo = VALUES(motivo_rechazo),
  activa = VALUES(activa),
  creada_en = VALUES(creada_en);

-- 101: Pipa, con una postulación pendiente del cliente 102 (el cliente 103 todavía puede postularse).
-- 103: Simba, finalizada hace exactamente 30 días: el motor tiene que mandar el control de los 30 días.
INSERT INTO adopcion
  (id, publicacion_id, estado, adoptante_id, turno_chequeo_id, fecha_inicio, fecha_fin)
VALUES
  (101, 101, 'CON_POSTULANTES', NULL, NULL, @ahora - INTERVAL 5 DAY,  NULL),
  (103, 103, 'FINALIZADA',      103,  901,  @ahora - INTERVAL 59 DAY, TIMESTAMP(@hoy - INTERVAL 30 DAY, '10:00:00'))
ON DUPLICATE KEY UPDATE
  publicacion_id = VALUES(publicacion_id),
  estado = VALUES(estado),
  adoptante_id = VALUES(adoptante_id),
  turno_chequeo_id = VALUES(turno_chequeo_id),
  fecha_inicio = VALUES(fecha_inicio),
  fecha_fin = VALUES(fecha_fin);

INSERT INTO postulacion
  (id, adopcion_id, cliente_id, tipo_vivienda, otras_mascotas, tiempo_disponible, estado, fecha)
VALUES
  (101, 101, 102, 'Casa con patio', 'Un perro (Firulais) y un gato (Michi)', 'Trabajo desde casa',
   'PENDIENTE', @ahora - INTERVAL 2 DAY)
ON DUPLICATE KEY UPDATE
  adopcion_id = VALUES(adopcion_id),
  cliente_id = VALUES(cliente_id),
  tipo_vivienda = VALUES(tipo_vivienda),
  otras_mascotas = VALUES(otras_mascotas),
  tiempo_disponible = VALUES(tiempo_disponible),
  estado = VALUES(estado),
  fecha = VALUES(fecha);
