# shellcheck shell=bash
# Casos de la consulta, la factura y el historial clínico (rol 4). Usan las semillas:
# turno 101 (CONSULTA, Firulais, de cliente@), insumo 101 (jeringa) y producto 101 (alimento cachorro).
# Atiende y finaliza el turno 101: volver a sembrar lo deja PROGRAMADO.
es_entorno_de_prueba || return 0

# --- Sin sesión y con rol de cliente ---
cerrar_sesion
pedir POST /api/pacientes/turnos/101/atencion
esperar "Iniciar una atención sin sesión da 401" 401

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/pacientes/turnos/101/atencion
esperar "Un cliente no puede iniciar una atención (403)" 403
cerrar_sesion

# --- Veterinaria: atención del turno 101 ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

pedir POST /api/pacientes/turnos/999999/atencion
esperar "Atender un turno que no existe da 404" 404

pedir POST /api/pacientes/turnos/101/atencion
esperar "La veterinaria inicia la atención del turno 101" 201 '"estado":"ABIERTA"'
CONSULTA=$(printf '%s' "$RESPUESTA" | sed -n 's/^{"consulta":{"id":\([0-9]*\).*/\1/p')

pedir POST /api/pacientes/turnos/101/atencion
esperar "Un turno con consulta no se atiende dos veces (409)" 409

pedir POST "/api/pacientes/consultas/$CONSULTA/finalizar"
esperar "Sin diagnóstico no se puede finalizar (400)" 400

CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir PUT "/api/pacientes/consultas/$CONSULTA" '{"diagnostico":"No debería guardarse"}'
esperar "Guardar sin el token CSRF correcto da 403" 403
CSRF=$CSRF_REAL

pedir PUT "/api/pacientes/consultas/$CONSULTA" '{"valor_base":-5}'
esperar "Un valor base negativo da 400" 400

pedir PUT "/api/pacientes/consultas/$CONSULTA" '{"diagnostico":"Control general","valor_base":8000}'
esperar "La veterinaria guarda diagnóstico y valor base" 200 '"valor_base":"8000.00"'

# --- Insumos ---
pedir POST "/api/pacientes/consultas/$CONSULTA/insumos" '{"insumo_id":101,"cantidad":0}'
esperar "Una cantidad de 0 da 400" 400

pedir POST "/api/pacientes/consultas/$CONSULTA/insumos" '{"insumo_id":999999,"cantidad":1}'
esperar "Un insumo que no existe da 404" 404

pedir POST "/api/pacientes/consultas/$CONSULTA/insumos" '{"insumo_id":101,"cantidad":2}'
esperar "Agrega 2 jeringas" 201 '"cantidad":2'

pedir POST "/api/pacientes/consultas/$CONSULTA/insumos" '{"insumo_id":101,"cantidad":1}'
esperar "Agregar el mismo insumo suma la cantidad" 201 '"cantidad":3'

# --- Stock insuficiente: nada se finaliza ni se descuenta ---
pedir POST "/api/pacientes/consultas/$CONSULTA/productos" '{"producto_id":101,"cantidad":100000}'
esperar "Agrega más unidades de las que hay en stock" 201 '"producto_id":101'
ITEM=$(printf '%s' "$RESPUESTA" | sed -n 's/.*"productos":\[{"id":\([0-9]*\).*/\1/p')

pedir POST "/api/pacientes/consultas/$CONSULTA/finalizar"
esperar "Sin stock suficiente no se finaliza (409)" 409 '"Stock insuficiente"'

pedir GET "/api/pacientes/consultas/$CONSULTA"
esperar "Después del rechazo la consulta sigue abierta" 200 '"estado":"ABIERTA"'

pedir DELETE "/api/pacientes/consultas/$CONSULTA/productos/$ITEM"
esperar "La veterinaria quita el producto" 200 '"productos":[]'

# --- Finalizar: factura y estado ---
pedir POST "/api/pacientes/consultas/$CONSULTA/productos" '{"producto_id":101,"cantidad":1}'
esperar "Agrega 1 alimento" 201 '"producto_id":101'

pedir POST "/api/pacientes/consultas/$CONSULTA/finalizar"
esperar "La veterinaria finaliza la consulta" 200 '"estado":"FINALIZADA"'
esperar "y se genera la factura C-" 200 '"numero":"C-'
FACTURA=$(printf '%s' "$RESPUESTA" | sed -n 's/.*"factura":{"numero":"\(C-[0-9]*\)".*/\1/p')

pedir POST "/api/pacientes/consultas/$CONSULTA/finalizar"
esperar "El doble clic devuelve la misma factura" 200 "$FACTURA"

pedir PUT "/api/pacientes/consultas/$CONSULTA" '{"diagnostico":"Otro diagnóstico"}'
esperar "Una consulta finalizada no se modifica (409)" 409

pedir POST "/api/pacientes/consultas/$CONSULTA/insumos" '{"insumo_id":101,"cantidad":1}'
esperar "A una consulta finalizada no se le agregan ítems (409)" 409

pedir GET "/api/pacientes/consultas/$CONSULTA/factura"
esperar "La veterinaria ve la factura pendiente de pago" 200 '"estado":"PENDIENTE_PAGO"'

# --- Historial: cada cliente ve solo sus mascotas ---
cerrar_sesion
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'

pedir GET /api/pacientes/mascotas/101/historial
esperar "El dueño de Firulais ve la consulta en su historial" 200 "$FACTURA"

pedir GET /api/pacientes/mascotas/103/historial
esperar "El historial de la mascota de otro cliente da 404" 404

pedir GET "/api/pacientes/consultas/$CONSULTA"
esperar "Un cliente no puede ver la ficha de la consulta (403)" 403

cerrar_sesion
