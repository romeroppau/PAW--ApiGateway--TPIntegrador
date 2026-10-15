-- Permisos de cada usuario de MySQL sobre las tablas, según la tabla de permisos del DER.
--
-- No es una migración numerada: el script de migraciones lo corre completo cada vez,
-- después de aplicar las migraciones. Repetir un GRANT no rompe nada.
-- Cada módulo agrega acá los permisos de sus tablas, en su propia sección.
-- Solo se dan permisos a usuarios que ya existen (un GRANT a un usuario inexistente da error):
-- los de Pacientes, Adopciones y Reportes se agregan cuando se sumen esos módulos.

-- backend puede leer, insertar y modificar; inventario solo leer.

-- Tabla usuario (módulo Backend)
GRANT SELECT, INSERT, UPDATE ON huellavet.usuario TO 'backend'@'%';
GRANT SELECT                 ON huellavet.usuario TO 'inventario'@'%';
