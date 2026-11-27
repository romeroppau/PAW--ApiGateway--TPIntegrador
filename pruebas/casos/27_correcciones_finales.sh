# shellcheck shell=bash
# 27/11, correcciones de la devolución del profesor:
#   - La veterinaria marca la factura de una consulta como pagada, con el medio de pago (migración 030).
#     Usa la última consulta que finalizó un caso anterior ($CONSULTA, con la factura pendiente).
#   - Hoy no se puede dar un turno en una hora que ya pasó (Pacientes).
#   - La tarea diaria da de baja los lotes vencidos de productos e insumos: movimiento VENCIMIENTO
#     (migración 031) y aviso a la veterinaria. Usa la vacuna séxtuple (104, vence).
# Contratos: Pacientes contrato-consultas.md ("Marcar la factura como pagada") y
# contrato-mascotas-turnos.md; Inventario contrato.md ("POST /api/inventario/tareas/vencer-lotes").

# --- La tarea de los lotes vencidos exige el token (también en solo lectura) ---
cerrar_sesion
pedir POST /api/inventario/tareas/vencer-lotes
esperar "La baja de los lotes vencidos sin X-Tarea-Token da 401" 401

es_entorno_de_prueba || return 0

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

# --- Factura de la consulta pagada ---
if [ -n "${CONSULTA:-}" ]; then
  pedir POST "/api/pacientes/consultas/$CONSULTA/factura/pago" '{}'
  esperar "Marcar la factura pagada sin el medio de pago da 400" 400 '"medio_pago":"Elegí el medio de pago: efectivo, transferencia o tarjeta"'
  pedir POST "/api/pacientes/consultas/$CONSULTA/factura/pago" '{"medio_pago":"CHEQUE"}'
  esperar "  y con un medio que no existe, también" 400 '"medio_pago"'
  pedir POST "/api/pacientes/consultas/$CONSULTA/factura/pago" '{"medio_pago":"TRANSFERENCIA"}'
  esperar "La veterinaria marca la factura como pagada por transferencia" 200 '"medio_pago":"TRANSFERENCIA","pagada_en":"'
  esperar "  y queda PAGADA" 200 '"estado":"PAGADA"'
  pedir POST "/api/pacientes/consultas/$CONSULTA/factura/pago" '{"medio_pago":"EFECTIVO"}'
  esperar "  dos veces da 409" 409 '"La factura ya está pagada"'
  pedir POST /api/pacientes/consultas/999999/factura/pago '{"medio_pago":"EFECTIVO"}'
  esperar "La factura de una consulta que no existe da 404" 404

  pedir GET "/api/pacientes/consultas/$CONSULTA/factura"
  esperar "La factura dice cómo se pagó" 200 '"medio_pago":"TRANSFERENCIA"'

  cerrar_sesion
  iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
  pedir POST "/api/pacientes/consultas/$CONSULTA/factura/pago" '{"medio_pago":"EFECTIVO"}'
  esperar "El cliente no puede marcarla pagada (403)" 403
  cerrar_sesion
  iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
else
  echo "  (sin la consulta de 07_consultas: no se prueba el pago de la factura)"
fi

# --- Turno de hoy en una hora que ya pasó (desde las 9 de Argentina: las 08:00 ya pasaron) ---
if [ "$(date -u -d '-3 hours' +%H)" -ge 9 ]; then
  HOY_T=$(date -u -d '-3 hours' +%Y-%m-%d)
  pedir POST /api/pacientes/turnos "{\"mascota_id\":101,\"fecha\":\"$HOY_T\",\"hora\":\"08:00\",\"motivos\":[{\"motivo\":\"CONSULTA\"}]}"
  esperar "Hoy no se puede dar un turno en una hora que ya pasó" 400 '"hora":"Esa hora ya pasó: hoy el turno tiene que ser a las '
else
  echo "  (antes de las 9 de Argentina: no se prueba el turno en una hora que ya pasó)"
fi

# --- Baja de los lotes vencidos ---
EN_100_B=$(date -u -d '-3 hours +100 day' +%Y-%m-%d)
HACE_3_B=$(date -u -d '-3 hours -3 day' +%Y-%m-%d)
pedir POST /api/inventario/insumos/104/stock "{\"cantidad\":3,\"lote\":{\"codigo\":\"VENCE-HUMO\",\"vencimiento\":\"$EN_100_B\"}}"
esperar "Se carga un lote de la vacuna séxtuple para la prueba" 200 '"codigo":"VENCE-HUMO"'
LOTE_B=$(printf '%s' "$RESPUESTA" | grep -o '"lote":{"id":[0-9]*' | head -1 | cut -d: -f3)
pedir PUT "/api/inventario/insumos/104/lotes/${LOTE_B:-0}" "{\"codigo\":\"VENCE-HUMO\",\"vencimiento\":\"$HACE_3_B\"}"
esperar "  y se corrige a una fecha pasada: queda vencido" 200 '"vencido":true'

if [ -n "${TAREAS_TOKEN:-}" ]; then
  CODIGO=$(curl --silent --max-time 60 -o /dev/null -w '%{http_code}' -X POST \
    -H 'X-Tarea-Token: token-incorrecto' "$BASE_URL/api/inventario/tareas/vencer-lotes")
  RESPUESTA=""
  esperar "La baja de los lotes vencidos con un token inválido da 401" 401

  SALIDA=$(curl --silent --max-time 60 -w '\n%{http_code}' -X POST \
    -H "X-Tarea-Token: $TAREAS_TOKEN" "$BASE_URL/api/inventario/tareas/vencer-lotes")
  CODIGO=$(printf '%s' "$SALIDA" | tail -n1)
  RESPUESTA=$(printf '%s' "$SALIDA" | sed '$d')
  # Al menos el lote de la prueba (puede haber otros vencidos de casos anteriores).
  TOTAL=$((TOTAL + 1))
  if [ "$CODIGO" = 200 ] && printf '%s' "$RESPUESTA" | grep -qE '"lotes_insumos":[1-9]'; then
    echo "  ok     La tarea da de baja los lotes vencidos (al menos uno de insumos)"
  else
    FALLAS=$((FALLAS + 1))
    echo "  FALLA  La tarea da de baja los lotes vencidos (al menos uno de insumos)"
    echo "         esperaba 200 con lotes_insumos > 0, llegó $CODIGO: $(printf '%s' "$RESPUESTA" | head -c 200)"
  fi

  SALIDA=$(curl --silent --max-time 60 -w '\n%{http_code}' -X POST \
    -H "X-Tarea-Token: $TAREAS_TOKEN" "$BASE_URL/api/inventario/tareas/vencer-lotes")
  CODIGO=$(printf '%s' "$SALIDA" | tail -n1)
  RESPUESTA=$(printf '%s' "$SALIDA" | sed '$d')
  esperar "Una segunda corrida no da de baja nada más" 200 '"lotes_productos":0,"lotes_insumos":0,"unidades":0'

  pedir GET "/api/inventario/insumos/movimientos?insumo=104"
  esperar "En Movimientos queda la baja por vencimiento, con su lote y sin usuario" 200 '"motivo":"VENCIMIENTO","cantidad":3,"insumo_id":104,"insumo":"'
  esperar "  del lote vencido" 200 'VENCE-HUMO'
  pedir GET /api/notificaciones
  esperar "A la veterinaria le llega el aviso de la baja" 200 'Dimos de baja el lote L'
else
  echo "  (sin TAREAS_TOKEN: no se prueba la baja de los lotes vencidos)"
fi
cerrar_sesion
