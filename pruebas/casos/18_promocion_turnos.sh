# shellcheck shell=bash
# Precio de la consulta y franjas promocionadas (migración 020): el precio base de la configuración,
# la sugerencia del motor (las 5 franjas con menos turnos), publicitar y terminar una franja, y el
# precio que guarda cada turno al sacarse (y que la consulta toma sin poder cambiarlo).
# Contratos: Pacientes contrato-mascotas-turnos.md ("Precio del turno y franjas promocionadas") y
# Reportes contrato-reportes.md (a_promocionar). Al final no queda ninguna promoción ni precio cambiado.
es_entorno_de_prueba || return 0

# El próximo martes (desde mañana) en hora de Argentina: la franja que se promociona es "martes a la tarde".
MARTES=""
for i in 1 2 3 4 5 6 7; do
  d=$(date -u -d "-3 hours +$i day" +%Y-%m-%d)
  [ "$(date -u -d "$d" +%u)" = 2 ] && MARTES=$d && break
done
HASTA=$(date -u -d "-3 hours +30 day" +%Y-%m-%d)
id_de() { printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
turno_id() { printf '%s' "$RESPUESTA" | sed -n 's/^{"turno":{"id":\([0-9]*\).*/\1/p'; }

# --- Público ---
pedir GET /api/pacientes/promociones-turnos
esperar "Las franjas en promoción se ven sin sesión, con el precio base" 200 '"precio_consulta":15000,"datos":[]'

# --- El precio base se cambia desde la configuración ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir PUT /api/configuracion '{"valores":{"precio_consulta":20000}}'
esperar "La veterinaria cambia el precio de la consulta" 200 '"clave":"precio_consulta"'
pedir GET /api/pacientes/promociones-turnos
esperar "  y Pacientes lo usa" 200 '"precio_consulta":20000'

# --- La sugerencia del motor ---
pedir GET /api/reportes/sugerencias
esperar "El motor sugiere las franjas a promocionar con su descuento" 200 '"a_promocionar":[{"dia_semana":'
esperar "  y el precio con el descuento sugerido" 200 '"precio_consulta":20000'

# --- Publicitar una franja ---
pedir POST /api/pacientes/promociones-turnos "{\"dia_semana\":7,\"franja\":\"NOCHE\",\"porcentaje\":95,\"hasta\":\"$HASTA\"}"
esperar "Datos inválidos: un mensaje por campo (400)" 400 '"dia_semana":"Elegí un día de lunes a sábado"'
pedir POST /api/pacientes/promociones-turnos "{\"dia_semana\":2,\"franja\":\"TARDE\",\"porcentaje\":20,\"hasta\":\"$HASTA\"}"
esperar "Publicita los martes a la tarde con 20 % (201)" 201 '"nombre":"Martes a la tarde","precio":20000,"precio_promocion":16000'
PROMO=$(id_de)
pedir POST /api/pacientes/promociones-turnos "{\"dia_semana\":2,\"franja\":\"TARDE\",\"porcentaje\":30,\"hasta\":\"$HASTA\"}"
esperar "Una franja con promoción no puede tener otra (409)" 409 'Martes a la tarde ya tiene una promoción del 20 %'
cerrar_sesion

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/pacientes/promociones-turnos "{\"dia_semana\":3,\"franja\":\"TARDE\",\"porcentaje\":20,\"hasta\":\"$HASTA\"}"
esperar "Un cliente no puede publicitar (403)" 403
cerrar_sesion
pedir GET /api/pacientes/promociones-turnos
esperar "Los clientes ven la franja en promoción" 200 '"franja":"TARDE","porcentaje":20'

# --- El turno guarda su precio al sacarse ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir POST /api/pacientes/turnos "{\"mascota_id\":101,\"fecha\":\"$MARTES\",\"hora\":\"15:40\",\"motivo\":\"CONSULTA\"}"
esperar "Un turno el martes a la tarde guarda el descuento" 201 '"precio":{"base":20000,"descuento":20,"final":16000}'
T_PROMO=$(turno_id)
pedir POST /api/pacientes/turnos "{\"mascota_id\":101,\"fecha\":\"$MARTES\",\"hora\":\"10:40\",\"motivo\":\"CONSULTA\"}"
esperar "Uno el martes a la mañana, no" 201 '"precio":{"base":20000,"descuento":null,"final":20000}'
T_MANIANA=$(turno_id)

# --- Terminar: los turnos que ya se sacaron conservan el descuento ---
pedir DELETE "/api/pacientes/promociones-turnos/$PROMO"
esperar "La veterinaria termina la promoción (204)" 204
pedir POST /api/pacientes/turnos "{\"mascota_id\":101,\"fecha\":\"$MARTES\",\"hora\":\"16:40\",\"motivo\":\"CONSULTA\"}"
esperar "Un turno nuevo en esa franja ya no tiene descuento" 201 '"descuento":null'
T_NUEVO=$(turno_id)
pedir GET "/api/pacientes/turnos?fecha=$MARTES"
esperar "El turno que se sacó con la promoción la conserva" 200 "\"id\":$T_PROMO,\"fecha\":\"$MARTES\",\"hora\":\"15:40\",\"motivo\":\"CONSULTA\",\"estado\":\"PROGRAMADO\""
esperar "  (con su 20 %)" 200 '"precio":{"base":20000,"descuento":20,"final":16000}'

# --- La consulta toma el precio del turno y no se cambia ---
pedir POST "/api/pacientes/turnos/$T_PROMO/atencion"
esperar "La consulta arranca con el precio del turno con descuento" 201 '"valor_base":"16000.00"'
esperar "  y dice el precio sin descuento y el porcentaje" 201 '"precio_lista":"20000.00","descuento":20'
CONSULTA_PROMO=$(printf '%s' "$RESPUESTA" | sed -n 's/^{"consulta":{"id":\([0-9]*\).*/\1/p')
pedir PUT "/api/pacientes/consultas/$CONSULTA_PROMO" '{"valor_base":1}'
esperar "El valor de la consulta no se cambia a mano (400)" 400 'sale del precio del turno'

# --- Reprogramar es como sacarlo de nuevo ---
pedir POST "/api/pacientes/turnos/$T_MANIANA/reprogramar" "{\"fecha\":\"$MARTES\",\"hora\":\"17:40\"}"
esperar "Reprogramado a la tarde (sin promoción ya), toma el precio de la franja nueva" 200 '"hora":"17:40"'
esperar "  sin descuento" 200 '"descuento":null'

# --- Limpieza: los turnos de la prueba se cancelan y el precio vuelve al de siempre ---
pedir POST "/api/pacientes/consultas/$CONSULTA_PROMO/finalizar"
pedir POST "/api/pacientes/turnos/$T_MANIANA/cancelar"
pedir POST "/api/pacientes/turnos/$T_NUEVO/cancelar"
pedir PUT /api/configuracion '{"valores":{"precio_consulta":15000}}'
esperar "El precio de la consulta vuelve al de siempre" 200
cerrar_sesion
pedir GET /api/pacientes/promociones-turnos
esperar "No queda ninguna franja en promoción" 200 '"precio_consulta":15000,"datos":[]'
