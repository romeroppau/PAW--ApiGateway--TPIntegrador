# shellcheck shell=bash
# Casos de las correcciones que pidió el profesor en la Entrega 4: límites de los turnos, ítems dados
# de baja y total de la factura. Corre después de 07_consultas.sh y usa el turno 102, que queda libre.
es_entorno_de_prueba || return 0

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

# --- Turnos: fecha razonable y horario de atención ---
MANIANA=$(date -u -d '-3 hours +1 day' +%Y-%m-%d)

pedir POST /api/pacientes/turnos '{"mascota_id":101,"fecha":"2999-01-01","hora":"10:00","motivo":"CONSULTA"}'
esperar "Un turno a más de un año da 400" 400 '"fecha"'

pedir POST /api/pacientes/turnos "{\"mascota_id\":101,\"fecha\":\"$MANIANA\",\"hora\":\"03:00\",\"motivo\":\"CONSULTA\"}"
esperar "Un turno a las 3 de la mañana da 400" 400 '"hora"'

pedir POST /api/pacientes/turnos "{\"mascota_id\":101,\"fecha\":\"$MANIANA\",\"hora\":\"20:00\",\"motivo\":\"CONSULTA\"}"
esperar "Un turno a la hora de cierre da 400" 400 '"hora"'

# --- Un insumo dado de baja no se descuenta ---
pedir POST /api/inventario/insumos '{"nombre":"Insumo que se da de baja","costo":10,"stock":10}'
esperar "Se crea un insumo para la prueba" 201 '"stock":10'
INSUMO=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

pedir POST /api/pacientes/turnos/102/atencion
esperar "Se atiende el turno 102" 201 '"estado":"ABIERTA"'
CONSULTA=$(printf '%s' "$RESPUESTA" | sed -n 's/^{"consulta":{"id":\([0-9]*\).*/\1/p')

pedir PUT "/api/pacientes/consultas/$CONSULTA" '{"diagnostico":"Vacunacion de rutina","valor_base":9000}'
esperar "Se guarda el diagnóstico" 200 '"valor_base":"9000.00"'

pedir POST "/api/pacientes/consultas/$CONSULTA/insumos" "{\"insumo_id\":$INSUMO,\"cantidad\":2}"
esperar "Se agrega el insumo a la consulta" 201 '"cantidad":2'
ITEM=$(printf '%s' "$RESPUESTA" | sed -n 's/.*"insumos":\[{"id":\([0-9]*\).*/\1/p')

pedir DELETE "/api/inventario/insumos/$INSUMO"
esperar "Se da de baja el insumo" 204

pedir POST "/api/pacientes/consultas/$CONSULTA/finalizar"
esperar "Con un insumo dado de baja no se finaliza (409)" 409 '"DADO_DE_BAJA"'

pedir GET "/api/inventario/insumos/$INSUMO"
esperar "El stock del insumo dado de baja no cambió" 200 '"stock":10'

pedir DELETE "/api/pacientes/consultas/$CONSULTA/insumos/$ITEM"
esperar "Se quita el insumo de la consulta" 200 '"insumos":[]'

# --- El total de la factura tiene que entrar en la columna, y se valida antes de descontar ---
pedir PUT "/api/pacientes/consultas/$CONSULTA" '{"valor_base":99999999.99}'
esperar "El valor base máximo se acepta" 200 '"valor_base":"99999999.99"'

pedir GET /api/inventario/insumos/101
STOCK=$(printf '%s' "$RESPUESTA" | grep -o '"stock":[0-9]*' | head -1)

pedir POST "/api/pacientes/consultas/$CONSULTA/insumos" '{"insumo_id":101,"cantidad":1}'
esperar "Se agrega una jeringa" 201 '"insumo_id":101'

pedir POST "/api/pacientes/consultas/$CONSULTA/finalizar"
esperar "Si el total no entra en la factura da 400, no 500" 400 'El total de la consulta'

pedir GET /api/inventario/insumos/101
esperar "El stock de la jeringa no cambió" 200 "$STOCK"

pedir PUT "/api/pacientes/consultas/$CONSULTA" '{"valor_base":9000}'
esperar "Se corrige el valor base" 200 '"valor_base":"9000.00"'

pedir POST "/api/pacientes/consultas/$CONSULTA/finalizar"
esperar "Con el total corregido, finaliza" 200 '"numero":"C-'

# --- Pendientes de la Entrega 4 ---
# La salida de stock por la consulta queda con la hora de Argentina (el profesor la vio en UTC).
AHORA=$(date -u -d '-3 hours' '+%Y-%m-%d %H')
pedir GET /api/inventario/insumos/101/movimientos
FECHA_SALIDA=$(printf '%s' "$RESPUESTA" | grep -o '"fecha":"[^"]*","tipo":"SALIDA","motivo":"CONSULTA"' | head -n1 | cut -d'"' -f4)
RESPUESTA="salida de la consulta: $FECHA_SALIDA"
esperar "La salida por la consulta tiene la hora de Argentina ($AHORA h)" 200 "$AHORA"

# La factura con su detalle: la veterinaria ve todas; el cliente, solo las de sus mascotas.
pedir GET "/api/pacientes/consultas/$CONSULTA/factura"
esperar "La factura trae la mascota y los ítems para mostrarla" 200 '"mascota":{"id":103,"nombre":"Luna"}'
esperar "y el detalle de la consulta con la jeringa" 200 '"insumo_id":101'

cerrar_sesion
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET "/api/pacientes/consultas/$CONSULTA/factura"
esperar "La dueña de Luna ve su factura" 200 '"numero":"C-'
pedir GET /api/pacientes/consultas/101/factura
esperar "y la de Tom, de las semillas" 200 '"nombre":"Tom"'
cerrar_sesion

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET "/api/pacientes/consultas/$CONSULTA/factura"
esperar "La factura de la mascota de otro cliente da 404" 404

cerrar_sesion
