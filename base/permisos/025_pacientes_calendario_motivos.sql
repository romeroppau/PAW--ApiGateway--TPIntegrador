-- Permisos de la migración 025 (base/025_pacientes_calendario_motivos.sql).

-- evento_sanitario: el veterinario ahora puede quitar del calendario una vacuna que todavía no se dio.
GRANT SELECT, INSERT, UPDATE, DELETE ON {{DB_NAME}}.evento_sanitario TO 'pacientes'@'%';
