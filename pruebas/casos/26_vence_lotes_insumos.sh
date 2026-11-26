# shellcheck shell=bash
# 26/11 (migración 029): "vence", lotes numerados (L1, L2, L3…) y lotes de insumos.
#   - Un producto o insumo dice si vence: si vence, cada lote nuevo lleva su vencimiento; si no, ninguno.
#     Se cambia solo sin stock.
#   - Los lotes de cada producto o insumo se numeran L1, L2, L3…; el código es el número del fabricante.
#   - Los insumos tienen lotes como los productos: se cargan y retiran por lote, las consultas usan el
#     que vence primero y Reportes avisa los lotes vencidos.
# Contratos: Inventario docs/api/contrato.md y contrato-insumos.md ("Lotes"); Reportes contrato-reportes.md.
# Usa la vacuna séxtuple (104, vence: su stock en L1), los guantes (102, no vencen: 150) y la vacuna de
# leucemia felina (191), que 23_calendario_motivos carga en un lote nuevo y usa en una consulta.
es_entorno_de_prueba || return 0

EN_100_V=$(date -u -d '-3 hours +100 day' +%Y-%m-%d)
EN_400_V=$(date -u -d '-3 hours +400 day' +%Y-%m-%d)
HACE_5_V=$(date -u -d '-3 hours -5 day' +%Y-%m-%d)
# El id del lote de la última respuesta ("lote":{"id":N…) y el del producto creado.
lote_de() { printf '%s' "$RESPUESTA" | grep -o '"lote":{"id":[0-9]*' | head -1 | cut -d: -f3; }
id_creado() { printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
# Como esperar, pero con una expresión regular (grep -E).
esperar_patron() { # DESCRIPCIÓN CÓDIGO PATRÓN
  TOTAL=$((TOTAL + 1))
  if [ "$CODIGO" = "$2" ] && printf '%s' "$RESPUESTA" | grep -qE -- "$3"; then echo "  ok     $1"; else
    FALLAS=$((FALLAS + 1)); echo "  FALLA  $1"; echo "         esperaba $2 con /$3/, llegó $CODIGO: $(printf '%s' "$RESPUESTA" | head -c 200)"; fi
}

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

# --- Productos: vence o no vence ---
pedir POST /api/inventario/productos '{"nombre":"Producto que vence (humo)","categoria":"MEDICAMENTO","especie":"TODAS","precio":100,"stock":5}'
esperar "Sin decir si vence, el alta da 400" 400 '"vence":"Indicá si vence o no"'
pedir POST /api/inventario/productos '{"nombre":"Producto que vence (humo)","categoria":"MEDICAMENTO","especie":"TODAS","precio":100,"stock":5,"vence":true}'
esperar "Si vence y tiene stock, el primer lote lleva vencimiento" 400 '"vencimiento":"Este producto vence: poné la fecha de vencimiento del lote"'
pedir POST /api/inventario/productos "{\"nombre\":\"Collar (humo)\",\"categoria\":\"ACCESORIO\",\"especie\":\"TODAS\",\"precio\":100,\"stock\":5,\"vence\":false,\"vencimiento\":\"$EN_100_V\"}"
esperar "Si no vence, no lleva vencimiento" 400 '"vencimiento":"Este producto no vence: dejá el vencimiento vacío"'
pedir POST /api/inventario/productos "{\"nombre\":\"Producto que vence (humo)\",\"categoria\":\"MEDICAMENTO\",\"especie\":\"TODAS\",\"precio\":100,\"stock\":5,\"vence\":true,\"vencimiento\":\"$EN_100_V\",\"lote\":\"HV-1\"}"
esperar "Se crea con su primer lote, L1, con el número del fabricante" 201 '"numero":1,"nombre":"L1 (HV-1)","codigo":"HV-1"'
esperar "  y dice que vence" 201 '"vence":true'
PROD_V=$(id_creado)
pedir PUT "/api/inventario/productos/${PROD_V:-0}" '{"nombre":"Producto que vence (humo)","categoria":"MEDICAMENTO","especie":"TODAS","precio":100,"vence":false}'
esperar "Con stock no se cambia si vence" 400 '"vence":"Se puede cambiar solo sin stock: retirá o vendé las 5 unidades primero"'
pedir POST "/api/inventario/productos/${PROD_V:-0}/stock" "{\"cantidad\":2,\"lote\":{\"vencimiento\":\"$EN_400_V\"}}"
esperar "El lote nuevo es el L2" 200 '"numero":2,"nombre":"L2","codigo":null'
pedir POST "/api/inventario/productos/${PROD_V:-0}/retiro" '{"cantidad":7}'
esperar "Se retira todo" 200 '"stock":0'
pedir PUT "/api/inventario/productos/${PROD_V:-0}" '{"nombre":"Producto que vence (humo)","categoria":"MEDICAMENTO","especie":"TODAS","precio":100,"vence":false}'
esperar "Sin stock sí se cambia: ya no vence" 200 '"vence":false'
pedir POST "/api/inventario/productos/${PROD_V:-0}/stock" '{"cantidad":3}'
esperar "Ahora se carga sin elegir lote, en uno sin vencimiento (L3)" 200 '"numero":3,"nombre":"L3","codigo":null,"vencimiento":null,"stock":3'
pedir POST "/api/inventario/productos/${PROD_V:-0}/stock" "{\"cantidad\":1,\"lote\":{\"vencimiento\":\"$EN_100_V\"}}"
esperar "  y un lote con vencimiento da 400" 400 '"lote.vencimiento":"Este producto no vence: dejá el vencimiento vacío"'
pedir GET "/api/inventario/productos/${PROD_V:-0}"
esperar_patron "Los lotes vacíos que ya no siguen la regla no se muestran (solo L3)" 200 '"lotes":\[\{"id":[0-9]+,"numero":3,[^]]*\]'
pedir DELETE "/api/inventario/productos/${PROD_V:-0}"
esperar "Se da de baja el producto de la prueba" 204

# --- Insumos: lotes como los productos ---
pedir GET /api/inventario/insumos/104
esperar "La vacuna séxtuple vence" 200 '"vence":true,"stock_sin_vencer":'
# Lo que tiene ahora (25 en las semillas; otro caso pudo usar alguna).
S104=$(printf '%s' "$RESPUESTA" | grep -o '"stock_sin_vencer":[0-9]*' | head -1 | cut -d: -f2); S104=${S104:-0}
esperar "  y su stock está en el lote L1, con vencimiento" 200 '"numero":1,"nombre":"L1","codigo":null,"vencimiento":"'
pedir POST /api/inventario/insumos/104/stock '{"cantidad":2}'
esperar "Una vacuna se carga en un lote: sin elegir, 400" 400 '"lote_id":"Este insumo vence: elegí un lote o creá uno nuevo con su vencimiento"'
pedir POST /api/inventario/insumos/104/stock '{"cantidad":2,"lote":{"codigo":"VS-HUMO"}}'
esperar "  y un lote nuevo sin vencimiento, también" 400 '"lote.vencimiento":"Este insumo vence: poné la fecha de vencimiento del lote"'
pedir POST /api/inventario/insumos/104/stock "{\"cantidad\":4,\"lote\":{\"codigo\":\"VS-HUMO\",\"vencimiento\":\"$EN_400_V\"}}"
esperar "Se crea el lote que sigue (L2) con su vencimiento" 200 '"nombre":"L2 (VS-HUMO)","codigo":"VS-HUMO"'
esperar "  y el insumo suma el stock" 200 "\"stock\":$((S104 + 4)),"
LOTE_VS=$(lote_de)
pedir POST /api/inventario/insumos/104/stock "{\"cantidad\":1,\"lote_id\":${LOTE_VS:-0}}"
esperar "Se carga en un lote que ya existe" 200 "\"stock\":$((S104 + 5)),"
pedir POST /api/inventario/insumos/104/retiro "{\"cantidad\":3,\"lote_id\":${LOTE_VS:-0}}"
esperar "Se retira de ese lote" 200 "\"stock\":$((S104 + 2)),"
pedir POST /api/inventario/insumos/104/retiro "{\"cantidad\":9,\"lote_id\":${LOTE_VS:-0}}"
esperar "  más de lo que tiene el lote da 409 con lo que hay" 409 '"stock":2'

pedir POST /api/inventario/insumos/102/stock '{"cantidad":3}'
esperar "Los guantes no vencen: se cargan sin elegir lote" 200 '"nombre":"L1","codigo":null,"vencimiento":null'
pedir POST /api/inventario/insumos/102/retiro '{"cantidad":3}'
esperar "  y se retiran" 200 '"stock":150'
pedir PUT /api/inventario/insumos/102 '{"nombre":"Guantes de l\u00e1tex (par)","costo":220,"vence":true}'
esperar "Con stock no se cambia si vence" 400 '"vence":"Se puede cambiar solo sin stock'

# Un lote corregido a una fecha pasada queda vencido: no se usa y Reportes lo avisa.
pedir PUT "/api/inventario/insumos/104/lotes/${LOTE_VS:-0}" "{\"codigo\":\"VS-HUMO\",\"vencimiento\":\"$HACE_5_V\"}"
esperar "Un lote corregido a una fecha pasada queda vencido" 200 "\"codigo\":\"VS-HUMO\",\"vencimiento\":\"$HACE_5_V\",\"stock\":2,\"vencido\":true"
esperar "  y no cuenta como stock sin vencer" 200 "\"stock_sin_vencer\":$S104,"
pedir GET /api/reportes/sugerencias
esperar "Reportes avisa el lote vencido del insumo" 200 '"tipo":"insumo","insumo_id":104,'
esperar "  con su nombre" 200 'lote L2 (VS-HUMO): venció el'
esperar "  y que ya no se usa" 200 'Ya no se usa en las consultas: retiralo del stock.'
pedir POST /api/inventario/insumos/104/retiro '{"cantidad":2}'
esperar "Un retiro sin lote saca primero lo vencido" 200 "\"stock\":$S104,"
pedir GET "/api/inventario/insumos/movimientos?insumo=104"
esperar "Los movimientos del insumo dicen su lote" 200 '"nombre":"L2 (VS-HUMO)"'

# La consulta de 23_calendario_motivos usó la vacuna de leucemia del lote que se cargó (el L1).
pedir GET "/api/inventario/insumos/movimientos?insumo=191"
esperar_patron "Una consulta saca el insumo de su lote" 200 '"motivo":"CONSULTA","cantidad":[0-9]+,"insumo_id":191,"insumo":"[^"]*","usuario":("[^"]*"|null),"lote":\{"id":[0-9]+,"numero":1,"nombre":"L1"'
cerrar_sesion
