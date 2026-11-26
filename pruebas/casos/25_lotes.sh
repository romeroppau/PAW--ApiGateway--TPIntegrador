# shellcheck shell=bash
# 26/11 (migración 028): lotes de productos. Cada producto tiene lotes con su vencimiento y su stock.
#   - La veterinaria carga stock en un lote que ya existe o en uno nuevo, y retira de un lote.
#   - Se vende primero el lote que vence antes; una compra cancelada devuelve cada unidad a su lote.
#   - Una promoción es de un lote: el descuento vale para las unidades que le quedan; las demás, a
#     precio normal (dos líneas en la compra).
#   - "Qué liquidar" de Reportes es por lote, y avisa los lotes vencidos con stock.
# Contratos: Inventario docs/api/contrato.md ("Lotes") y contrato-tienda.md; Reportes contrato-reportes.md.
# Usa la pipeta Frontline (107) de las semillas: 8 unidades del lote FL-2612 (vence en 20 días) y 10
# del FL-0627 (vence en 200), a $ 6.500.
es_entorno_de_prueba || return 0

EN_300_LOT=$(date -u -d '-3 hours +300 day' +%Y-%m-%d)
EN_30_LOT=$(date -u -d '-3 hours +30 day' +%Y-%m-%d)
HACE_10_LOT=$(date -u -d '-3 hours -10 day' +%Y-%m-%d)
# El id del lote con ese número, en la última respuesta.
lote_id() { printf '%s' "$RESPUESTA" | grep -o "\"id\":[0-9]*,\"codigo\":\"$1\"" | head -1 | cut -d: -f2 | cut -d, -f1; }
# El stock del lote con ese número, en la última respuesta.
stock_lote() { printf '%s' "$RESPUESTA" | grep -o "\"codigo\":\"$1\",\"vencimiento\":[^,]*,\"stock\":[0-9]*" | head -1 | sed 's/.*"stock"://'; }
esperar_stock_lote() { # DESCRIPCIÓN CÓDIGO STOCK
  TOTAL=$((TOTAL + 1))
  if [ "$(stock_lote "$2")" = "$3" ]; then echo "  ok     $1"; else
    FALLAS=$((FALLAS + 1)); echo "  FALLA  $1"; echo "         esperaba $3 en el lote $2, hay $(stock_lote "$2")"; fi
}

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/inventario/productos/107
esperar "El producto trae sus lotes, el que vence primero arriba" 200 '"lotes":[{"id":'
esperar "  con lo que se puede vender" 200 '"stock":18,"stock_vendible":18'
esperar_stock_lote "  el FL-2612 tiene 8" FL-2612 8
esperar_stock_lote "  y el FL-0627, 10" FL-0627 10
LOTE_A=$(lote_id FL-2612)
LOTE_B=$(lote_id FL-0627)

# --- Cargar stock ---
pedir POST /api/inventario/productos/107/stock "{\"cantidad\":5,\"lote\":{\"codigo\":\"HUMO-1\",\"vencimiento\":\"$EN_300_LOT\"}}"
esperar "Se carga stock en un lote nuevo" 200 "\"stock\":23,\"lote\":{\"id\":"
esperar "  con su número y vencimiento" 200 "\"codigo\":\"HUMO-1\",\"vencimiento\":\"$EN_300_LOT\",\"stock\":5"
LOTE_H=$(lote_id HUMO-1)
pedir POST /api/inventario/productos/107/stock "{\"cantidad\":2,\"lote_id\":${LOTE_H:-0}}"
esperar "  y en uno que ya existe" 200 "\"codigo\":\"HUMO-1\",\"vencimiento\":\"$EN_300_LOT\",\"stock\":7"
pedir POST /api/inventario/productos/107/stock '{"cantidad":1,"lote_id":999999999}'
esperar "Un lote de otro producto da 400" 400 '"lote_id":"Ese lote no es de este producto"'
pedir POST /api/inventario/productos/107/stock "{\"cantidad\":1,\"lote\":{\"vencimiento\":\"$HACE_10_LOT\"}}"
esperar "Un lote nuevo vencido da 400" 400 '"lote.vencimiento":"La fecha de vencimiento no puede ser anterior a hoy"'
pedir POST /api/inventario/productos/107/retiro "{\"cantidad\":2,\"lote_id\":${LOTE_H:-0}}"
esperar "Se retira de un lote" 200 '"stock":23'
pedir POST /api/inventario/productos/107/retiro "{\"cantidad\":99,\"lote_id\":${LOTE_H:-0}}"
esperar "  más de lo que tiene da 409 con lo que hay en ese lote" 409 '"stock":5'

# --- Se vende primero el que vence antes; cancelar devuelve a cada lote ---
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir DELETE /api/tienda/carrito/items/107
pedir POST /api/tienda/carrito/items '{"producto_id":107,"cantidad":9}'
esperar "El cliente lleva 9 pipetas" 200 '"cantidad":9'
pedir POST /api/tienda/carrito/confirmar
esperar "Confirma la compra" 201 '"numero":"V-'
COMPRA_LOT=$(printf '%s' "$RESPUESTA" | grep -o '"numero":"V-[0-9]*"' | head -1 | cut -d'"' -f4)
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/inventario/productos/107
esperar_stock_lote "Salen 8 del lote que vence primero (FL-2612 queda en 0)" FL-2612 0
esperar_stock_lote "  y 1 del siguiente (FL-0627 queda en 9)" FL-0627 9
pedir GET "/api/inventario/productos/movimientos?producto=107"
esperar "Cada lote tiene su movimiento de la venta" 200 "\"lote\":{\"id\":${LOTE_A:-0},\"codigo\":\"FL-2612\""
esperar "  que enlaza a la compra" 200 "\"compra\":\"${COMPRA_LOT:-V-x}\""
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST "/api/tienda/compras/${COMPRA_LOT:-V-x}/cancelar"
esperar "El cliente cancela la compra" 200
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/inventario/productos/107
esperar_stock_lote "Cada unidad vuelve a su lote (FL-2612 otra vez en 8)" FL-2612 8
esperar_stock_lote "  (FL-0627 en 10)" FL-0627 10

# --- Una promoción es de un lote, con tope ---
pedir POST /api/inventario/promociones "{\"producto_id\":107,\"lote_id\":${LOTE_A:-0},\"porcentaje\":20,\"hasta\":\"$EN_30_LOT\"}"
esperar "La promoción no puede durar más que su lote" 400 '"hasta":"El lote vence el'
pedir POST /api/inventario/promociones "{\"producto_id\":107,\"lote_id\":${LOTE_A:-0},\"porcentaje\":20,\"hasta\":\"$(date -u -d '-3 hours +10 day' +%Y-%m-%d)\"}"
esperar "Se publicita el lote que vence primero" 201 "\"lote\":{\"id\":${LOTE_A:-0},\"codigo\":\"FL-2612\""
esperar "  con las unidades que le quedan" 201 '"quedan":8'
PROMO_LOT=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
pedir GET /api/tienda/promociones
esperar "La tienda dice cuántas quedan en promoción" 200 '"porcentaje":20,"precio":5200,'
esperar "  (las 8 del lote)" 200 '"quedan":8'

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/tienda/carrito/items '{"producto_id":107,"cantidad":10}'
esperar "Con 10 en el carrito, 8 van con descuento" 200 '"promocion_quedan":8,"cantidad_promocion":8,"cantidad":10'
esperar "  y 2 a precio normal (8 × 5.200 + 2 × 6.500)" 200 '"subtotal":54600'
pedir POST /api/tienda/carrito/confirmar
esperar "Confirma la compra con la promoción" 201 '"numero":"V-'
esperar "  y la compra tiene dos líneas: las 8 con descuento" 201 '"precio_unitario":5200,"cantidad":8,"subtotal":41600,"en_promocion":true'
esperar "  y las 2 a precio normal" 201 '"precio_unitario":6500,"cantidad":2,"subtotal":13000,"en_promocion":false'
COMPRA_PROMO=$(printf '%s' "$RESPUESTA" | grep -o '"numero":"V-[0-9]*"' | head -1 | cut -d'"' -f4)
pedir GET /api/tienda/promociones
esperar "Sin unidades en el lote, la promoción ya no se ve en la tienda" 200 '"datos":[]'
pedir POST "/api/tienda/compras/${COMPRA_PROMO:-V-x}/cancelar"
esperar "Se cancela" 200
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/inventario/productos/107
esperar_stock_lote "Las 8 con descuento vuelven a su lote" FL-2612 8
esperar_stock_lote "  y las otras 2 al suyo" FL-0627 10

# --- Reportes: qué liquidar por lote y los lotes vencidos ---
pedir GET /api/reportes/sugerencias
esperar "Qué liquidar dice el lote que vence" 200 "\"producto_id\":107,\"nombre\":\"Pipeta antipulgas Frontline Plus para gatos\",\"lote_id\":${LOTE_A:-0},\"lote\":\"FL-2612\""
esperar "  con las unidades de ese lote" 200 'lote FL-2612: vence el'
pedir PUT "/api/inventario/productos/107/lotes/${LOTE_H:-0}" "{\"codigo\":\"HUMO-1\",\"vencimiento\":\"$HACE_10_LOT\"}"
esperar "Un lote se corrige a una fecha pasada (estaba mal cargado)" 200 '"stock_vendible":18'
esperar "  y queda vencido (no se vende)" 200 '"codigo":"HUMO-1","vencimiento":"'"$HACE_10_LOT"'","stock":5,"vencido":true'
pedir GET /api/reportes/sugerencias
esperar "Reportes avisa el lote vencido para retirarlo" 200 '"lote":"HUMO-1"'
esperar "  con el texto" 200 'lote HUMO-1: venció el'
pedir POST /api/inventario/productos/107/retiro '{"cantidad":5}'
esperar "Un retiro sin lote saca primero lo vencido" 200 '"stock":18'
pedir GET /api/inventario/productos/107
esperar "  (el lote vencido queda vacío y ya no aparece)" 200 '"stock":18,"stock_vendible":18'

# Deja todo como estaba: la promoción terminada.
pedir DELETE "/api/inventario/promociones/${PROMO_LOT:-0}"
esperar "Se termina la promoción" 204
cerrar_sesion
