# shellcheck shell=bash
# Casos de mascotas y turnos (rol 3). Usan las mascotas y turnos de las semillas 004:
# mascotas 101 y 102 de cliente@, 103 y 104 de cliente2@; turnos 101 y 102 de hoy, 103 de mañana.
# Cancela el turno 103 (mañana): no lo usa nadie más, y volver a sembrar lo deja PROGRAMADO.
es_entorno_de_prueba || return 0

# --- Sin sesión ---
cerrar_sesion
pedir GET /api/pacientes/turnos
esperar "La agenda sin sesión da 401" 401

# --- Veterinaria: agenda y cambio de estado ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

pedir GET /api/pacientes/turnos
esperar "La agenda de hoy trae el turno 101 con su mascota" 200 '"nombre":"Firulais"'

pedir GET '/api/pacientes/turnos?fecha=2026-02-30'
esperar "Una fecha que no existe da 400" 400

pedir GET '/api/pacientes/mascotas?buscar=luna'
esperar "La veterinaria busca mascotas por nombre" 200 '"nombre":"Luna"'

pedir POST /api/pacientes/turnos/103/ausente
esperar "No se puede marcar ausente un turno de mañana (409)" 409

CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir POST /api/pacientes/turnos/103/cancelar
esperar "Cancelar sin el token CSRF correcto da 403" 403
CSRF=$CSRF_REAL

pedir POST /api/pacientes/turnos/103/cancelar
esperar "La veterinaria cancela el turno de mañana" 200 '"estado":"CANCELADO"'

pedir POST /api/pacientes/turnos/103/cancelar
esperar "Un turno ya cancelado no se vuelve a cancelar (409)" 409

pedir POST /api/pacientes/turnos/999999/cancelar
esperar "Cancelar un turno que no existe da 404" 404

# --- Cliente: solo lo suyo ---
cerrar_sesion
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'

pedir GET /api/pacientes/mascotas
esperar "El cliente ve sus mascotas" 200 '"nombre":"Tom"'

pedir GET /api/pacientes/mascotas/103
esperar "El cliente ve la ficha de su mascota" 200 '"nombre":"Luna"'

pedir GET /api/pacientes/mascotas/101
esperar "La mascota de otro cliente da 404" 404

pedir GET /api/pacientes/turnos
esperar "El cliente ve los turnos de sus mascotas" 200 '"nombre":"Luna"'

pedir POST /api/pacientes/turnos/102/cancelar
esperar "Un cliente no puede cancelar turnos (403)" 403

cerrar_sesion

# --- Etapa 3: alta de turnos (veterinaria) ---
# Se pueden repetir contra dev: el turno de prueba se cancela al final y libera su horario.
MANIANA=$(date -u -d '-3 hours +1 day' +%Y-%m-%d)   # mañana en Argentina (UTC-3)
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

pedir POST /api/pacientes/turnos '{"mascota_id":101,"fecha":"2020-01-01","hora":"25:00","motivo":"PELUQUERIA"}'
esperar "Un turno con datos inválidos da 400 con el error de cada campo" 400 '"motivo"'

pedir POST /api/pacientes/turnos "{\"mascota_id\":101,\"fecha\":\"$MANIANA\",\"hora\":\"19:45\",\"motivo\":\"CONSULTA\"}"
esperar "La veterinaria carga un turno para mañana" 201 '"estado":"PROGRAMADO"'
TURNO_NUEVO=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

pedir POST /api/pacientes/turnos "{\"mascota_id\":102,\"fecha\":\"$MANIANA\",\"hora\":\"19:45\",\"motivo\":\"CONSULTA\"}"
esperar "Otro turno a la misma hora da 409" 409

pedir POST /api/pacientes/turnos "{\"mascota_id\":999999,\"fecha\":\"$MANIANA\",\"hora\":\"19:50\",\"motivo\":\"CONSULTA\"}"
esperar "Un turno para una mascota que no existe da 404" 404

pedir POST "/api/pacientes/turnos/${TURNO_NUEVO:-0}/cancelar"
esperar "Cancelar el turno nuevo libera el horario" 200 '"estado":"CANCELADO"'

# --- Etapa 3: alta, edición y baja de mascotas (cliente) ---
cerrar_sesion
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'

pedir POST /api/pacientes/turnos "{\"mascota_id\":103,\"fecha\":\"$MANIANA\",\"hora\":\"19:55\",\"motivo\":\"CONSULTA\"}"
esperar "Un cliente no puede cargar turnos (403)" 403

pedir POST /api/pacientes/mascotas '{"nombre":"","especie":"PEZ","peso_kg":"-1"}'
esperar "Una mascota con datos inválidos da 400 con el error de cada campo" 400 '"especie"'

NACIMIENTO=$(date -u -d '-3 hours -3 weeks' +%Y-%m-%d)
pedir POST /api/pacientes/mascotas "{\"nombre\":\"Cachorro de humo\",\"especie\":\"PERRO\",\"fecha_nacimiento\":\"$NACIMIENTO\"}"
esperar "El cliente da de alta una mascota suya" 201 '"nombre":"Cachorro de humo"'
MASCOTA_NUEVA=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

pedir GET "/api/pacientes/mascotas/${MASCOTA_NUEVA:-0}/calendario-sanitario"
esperar "Al darla de alta se le arma el calendario sanitario" 200 '"nombre":"Séxtuple (1.ª dosis)"'

pedir PUT "/api/pacientes/mascotas/${MASCOTA_NUEVA:-0}" "{\"nombre\":\"Cachorro editado\",\"especie\":\"PERRO\",\"fecha_nacimiento\":\"$NACIMIENTO\",\"peso_kg\":4.5}"
esperar "El cliente edita su mascota" 200 '"peso_kg":"4.50"'

pedir PUT /api/pacientes/mascotas/101 '{"nombre":"Ajena","especie":"PERRO"}'
esperar "Editar la mascota de otro cliente da 404" 404

pedir DELETE /api/pacientes/mascotas/103
esperar "No se puede dar de baja una mascota con turnos programados (409)" 409

pedir DELETE "/api/pacientes/mascotas/${MASCOTA_NUEVA:-0}"
esperar "El cliente da de baja su mascota" 204

pedir PUT "/api/pacientes/mascotas/${MASCOTA_NUEVA:-0}" '{"nombre":"Otra vez","especie":"PERRO"}'
esperar "Una mascota dada de baja ya no se edita (409)" 409

cerrar_sesion
