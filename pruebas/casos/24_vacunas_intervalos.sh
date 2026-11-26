# shellcheck shell=bash
# 26/11: días mínimos entre dosis (Configuración → Vacunas) y "Marcar como dada" sin dosis repetidas.
#   - Dar una dosis ya no agrega sola la siguiente: el evento dado trae la próxima sugerida.
#   - Entre dos dosis de la misma vacuna tienen que pasar los días de Configuración → Vacunas
#     (antirrábica: 330 por defecto): al agregar, marcar como dada, cambiar la fecha, sacar y
#     reprogramar un turno.
#   - El plan dice desde qué fecha se puede cargar cada ítem (fecha_minima).
# Contratos: Pacientes docs/api/contrato-calendario.md; Backend docs/api/contrato.md (Configuración).
# Usa a Tom (104, gato de cliente2@) y su antirrábica (evento 109 de la semilla 005, plan 10).
es_entorno_de_prueba || return 0

HOY_VAC=$(date -u -d '-3 hours' +%Y-%m-%d)
MANIANA_VAC=$(date -u -d '-3 hours +1 day' +%Y-%m-%d)
PASADO_VAC=$(date -u -d '-3 hours +2 day' +%Y-%m-%d)
EN_330_VAC=$(date -u -d '-3 hours +330 day' +%Y-%m-%d)
EN_UN_ANIO_VAC=$(date -u -d '-3 hours +1 year' +%Y-%m-%d)
CAL_TOM=/api/pacientes/mascotas/104/calendario-sanitario
# Cuántos eventos de la antirrábica hay en el calendario de la última respuesta.
antirrabicas() { printf '%s' "$RESPUESTA" | grep -o '"nombre":"Antirrábica","plan_sanitario_id":10' | wc -l | tr -d ' '; }
una_sola_antirrabica() { # DESCRIPCIÓN
  TOTAL=$((TOTAL + 1))
  if [ "$(antirrabicas)" = 1 ]; then echo "  ok     $1"; else
    FALLAS=$((FALLAS + 1)); echo "  FALLA  $1"; echo "         esperaba 1 antirrábica, hay $(antirrabicas)"; fi
}

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir PUT /api/configuracion '{"valores":{"dias_vacuna_antirrabica":330}}'
esperar "Configuración → Vacunas: los días de la antirrábica (330 por defecto)" 200 '"clave":"dias_vacuna_antirrabica","grupo":"VACUNAS","nombre_grupo":"Vacunas"'

# --- Marcar como dada no agrega otra dosis ---
pedir POST "$CAL_TOM/109/dada" "{\"fecha_aplicada\":\"$HOY_VAC\"}"
esperar "Se marca como dada la antirrábica de Tom" 200 "\"id\":109,\"tipo\":\"VACUNA\",\"nombre\":\"Antirrábica\",\"plan_sanitario_id\":10,\"aplicacion\":\"ANTIRRABICA\",\"fecha_programada\":\""
esperar "  y sugiere la próxima en un año" 200 "\"proxima_sugerida\":\"$EN_UN_ANIO_VAC\""
una_sola_antirrabica "  y no agrega otra sola (antes se repetía con cada clic)"
pedir POST "$CAL_TOM/109/dada" "{\"fecha_aplicada\":\"$HOY_VAC\"}"
esperar "Un segundo clic en una dada da 409 y no agrega nada" 409 'ya está dada'
pedir GET "$CAL_TOM"
una_sola_antirrabica "Sigue habiendo una sola antirrábica"
esperar "El plan dice desde cuándo se puede cargar la próxima" 200 "\"aplicacion\":\"ANTIRRABICA\""
esperar "  (fecha_minima: hoy + 330 días)" 200 "\"fecha_minima\":\"$EN_330_VAC\""

# --- Los días mínimos al agregar y al cambiar la fecha ---
pedir POST "$CAL_TOM" "{\"plan_sanitario_id\":10,\"fecha_programada\":\"$MANIANA_VAC\"}"
esperar "Agregar otra antirrábica para mañana da 409" 409 'Entre dos dosis tienen que pasar al menos 330 días'
esperar "  y dice desde cuándo se puede y dónde se cambia" 409 'Los días se cambian en Configuración → Vacunas.'
pedir POST "$CAL_TOM" "{\"plan_sanitario_id\":10,\"fecha_programada\":\"$EN_330_VAC\"}"
esperar "A los 330 días sí se agrega" 200 "\"fecha_programada\":\"$EN_330_VAC\""
PROXIMA=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*,"tipo":"VACUNA","nombre":"Antirrábica",[^}]*"fecha_aplicada":null' | head -1 | cut -d: -f2 | cut -d, -f1)
pedir PUT "$CAL_TOM/${PROXIMA:-0}" "{\"fecha_programada\":\"$MANIANA_VAC\"}"
esperar "Cambiarle la fecha a mañana da 409" 409 '"fecha_programada":"Entre dos dosis'
pedir POST "$CAL_TOM/${PROXIMA:-0}/dada" "{\"fecha_aplicada\":\"$HOY_VAC\"}"
esperar "Marcarla como dada el mismo día que la otra da 409" 409 '"fecha_aplicada":"Entre dos dosis'

# --- Los turnos ---
pedir POST /api/pacientes/turnos "{\"mascota_id\":104,\"fecha\":\"$MANIANA_VAC\",\"hora\":\"17:40\",\"motivo\":\"VACUNACION\",\"plan_sanitario_id\":10}"
esperar "Un turno para darla mañana da 409" 409 'Entre dos dosis tienen que pasar al menos 330 días'
pedir PUT /api/configuracion '{"valores":{"dias_vacuna_antirrabica":1}}'
esperar "La veterinaria baja los días de la antirrábica a 1" 200 '"clave":"dias_vacuna_antirrabica"'
pedir POST /api/pacientes/turnos "{\"mascota_id\":104,\"fecha\":\"$PASADO_VAC\",\"hora\":\"17:40\",\"motivo\":\"VACUNACION\",\"plan_sanitario_id\":10}"
esperar "  y ahora sí se saca el turno (Pacientes lee la configuración)" 201 '"motivo":"VACUNACION"'
TURNO_TOM=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
pedir PUT /api/configuracion '{"valores":{"dias_vacuna_antirrabica":330}}'
esperar "Vuelve a 330" 200
pedir POST "/api/pacientes/turnos/${TURNO_TOM:-0}/reprogramar" "{\"fecha\":\"$MANIANA_VAC\",\"hora\":\"17:40\"}"
esperar "Reprogramar el turno sin los días mínimos da 409" 409 '"fecha":"Entre dos dosis'
pedir POST "/api/pacientes/turnos/${TURNO_TOM:-0}/cancelar"
esperar "Se cancela el turno de prueba" 200
cerrar_sesion
