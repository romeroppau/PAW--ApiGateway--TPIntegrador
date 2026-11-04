-- Semilla 004 · mascotas y turnos de prueba
-- Ids fijos desde 101. Correr las semillas de nuevo vuelve los turnos a su estado inicial
-- (por ejemplo, un turno atendido vuelve a PROGRAMADO).

-- "Hoy" en Argentina (UTC-3, sin horario de verano). CURDATE() usa la hora del servidor,
-- que en Aiven y en Docker es UTC: después de las 21 h ya sería mañana.
SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);

-- Mascotas de los clientes 102 (cliente@prueba.huellavet) y 103 (cliente2@prueba.huellavet).
-- La 103 es una cachorra: su calendario sanitario tiene vacunas pendientes.
INSERT INTO mascota
  (id, duenio_id, nombre, especie, raza, fecha_nacimiento, peso_kg, foto, foto_tipo, activo)
VALUES
  (101, 102, 'Firulais', 'PERRO', 'Mestizo',          @hoy - INTERVAL 3 YEAR,  18.50, NULL, NULL, 1),
  (102, 102, 'Michi',    'GATO',  'Europeo común',    @hoy - INTERVAL 5 YEAR,   4.20, NULL, NULL, 1),
  (103, 103, 'Luna',     'PERRO', 'Labrador',         @hoy - INTERVAL 10 WEEK,  6.30, NULL, NULL, 1),
  (104, 103, 'Tom',      'GATO',  NULL,               @hoy - INTERVAL 2 YEAR,   3.80, NULL, NULL, 1)
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

-- Turnos con la veterinaria 101 (vet@prueba.huellavet).
-- 101 y 102 son de hoy y están PROGRAMADO: los usa la consulta (rol 4).
-- Los horarios son de las 8, para no chocar con los turnos que se carguen a mano en dev
-- (un veterinario no puede tener dos turnos a la misma hora).
INSERT INTO turno
  (id, mascota_id, veterinario_id, fecha, hora, motivo, estado)
VALUES
  (101, 101, 101, @hoy,                    '08:00', 'CONSULTA',   'PROGRAMADO'),
  (102, 103, 101, @hoy,                    '08:30', 'VACUNACION', 'PROGRAMADO'),
  (103, 102, 101, @hoy + INTERVAL 1 DAY,   '08:00', 'CONSULTA',   'PROGRAMADO'),
  (104, 104, 101, @hoy - INTERVAL 1 DAY,   '08:00', 'CONSULTA',   'ATENDIDO')
ON DUPLICATE KEY UPDATE
  mascota_id = VALUES(mascota_id),
  veterinario_id = VALUES(veterinario_id),
  fecha = VALUES(fecha),
  hora = VALUES(hora),
  motivo = VALUES(motivo),
  estado = VALUES(estado);
