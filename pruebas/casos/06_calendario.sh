# shellcheck shell=bash
# Casos del calendario sanitario (rol 3). Usan los eventos de la semilla 005:
# Firulais (101, de cliente@) tiene una vacuna vencida; Michi (102, de cliente@) está al día;
# Luna (103, de cliente2@) tiene la 2.ª dosis vencida y la 1.ª aplicada. Solo lee, no cambia datos.
es_entorno_de_prueba || return 0

cerrar_sesion
pedir GET /api/pacientes/mascotas/101/calendario-sanitario
esperar "El calendario sin sesión da 401" 401

# --- Cliente: solo sus mascotas ---
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'

pedir GET /api/pacientes/mascotas/102/calendario-sanitario
esperar "Michi tiene las vacunas al día" 200 '"vacunas_al_dia":true'

pedir GET /api/pacientes/mascotas/101/calendario-sanitario
esperar "Firulais no tiene las vacunas al día (refuerzo vencido)" 200 '"vacunas_al_dia":false'

pedir GET /api/pacientes/mascotas/103/calendario-sanitario
esperar "El calendario de la mascota de otro cliente da 404" 404

cerrar_sesion
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'

pedir GET /api/pacientes/mascotas/103/calendario-sanitario
esperar "El calendario de Luna marca la 1.ª dosis aplicada" 200 '"estado":"APLICADO"'
esperar "y la 2.ª dosis vencida" 200 '"estado":"VENCIDO"'

# --- Veterinaria: cualquier mascota ---
cerrar_sesion
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

pedir GET /api/pacientes/mascotas/104/calendario-sanitario
esperar "La veterinaria ve el calendario de cualquier mascota" 200 '"nombre":"Tom"'

pedir GET /api/pacientes/mascotas/999999/calendario-sanitario
esperar "El calendario de una mascota que no existe da 404" 404

cerrar_sesion
