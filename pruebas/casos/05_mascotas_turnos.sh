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
