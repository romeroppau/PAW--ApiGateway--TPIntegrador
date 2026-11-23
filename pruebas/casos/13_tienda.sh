# shellcheck shell=bash
# Casos de la tienda: carrito, compra, retiro y vencimientos (usan las cuentas, productos y compras
# de los datos semilla: 002_productos y 010_tienda).
es_entorno_de_prueba || return 0

# --- La foto de un producto (la usan el catálogo y el carrito) ---
pedir GET /api/tienda/productos/104/imagen
esperar "Un producto sin foto: la imagen da 404" 404 '"Imagen no encontrada"'
pedir GET /api/tienda/carrito
esperar "El carrito sin sesión da 401 (y la foto es pública)" 401

# --- Carrito: quién puede usarlo ---
pedir GET /api/tienda/carrito
esperar "El carrito sin sesión da 401" 401

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/tienda/carrito
esperar "La veterinaria no tiene carrito (403)" 403
cerrar_sesion

# --- Carrito del cliente 102 (no tiene uno abierto en las semillas) ---
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/tienda/carrito
esperar "Sin carrito abierto, se ve uno vacío" 200 '"items":[]'

CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir POST /api/tienda/carrito/items '{"producto_id":101,"cantidad":1}'
esperar "Agregar sin el token CSRF correcto da 403" 403
CSRF=$CSRF_REAL

pedir POST /api/tienda/carrito/items '{"producto_id":101,"cantidad":2}'
esperar "Agrega 2 alimentos al carrito" 200 '"cantidad":2'
esperar "El total se calcula en el servidor" 200 '"total":31999.8'

pedir POST /api/tienda/carrito/items '{"producto_id":101,"cantidad":1}'
esperar "Agregar el mismo producto suma la cantidad" 200 '"cantidad":3'

pedir POST /api/tienda/carrito/items '{"producto_id":101,"cantidad":50}'
esperar "No se puede agregar más de lo que hay en stock (409)" 409 '"Stock insuficiente"'

pedir POST /api/tienda/carrito/items '{"producto_id":104,"cantidad":1}'
esperar "Un producto sin stock no se agrega (409)" 409 '"Stock insuficiente"'

pedir POST /api/tienda/carrito/items '{"producto_id":999999,"cantidad":1}'
esperar "Un producto que no existe da 404" 404

pedir POST /api/tienda/carrito/items '{"producto_id":101,"cantidad":0}'
esperar "Una cantidad de 0 da 400" 400 '"cantidad"'

pedir PUT /api/tienda/carrito/items/101 '{"cantidad":5}'
esperar "Cambia la cantidad a 5" 200 '"cantidad":5'

pedir PUT /api/tienda/carrito/items/101 '{"cantidad":21}'
esperar "Cambiar a más que el stock da 409" 409

pedir PUT /api/tienda/carrito/items/110 '{"cantidad":1}'
esperar "Cambiar un producto que no está en el carrito da 404" 404

pedir POST /api/tienda/carrito/items '{"producto_id":110,"cantidad":1}'
pedir DELETE /api/tienda/carrito/items/110
esperar "Quita el collar del carrito" 200 '"producto_id":101'
printf '%s' "$RESPUESTA" | grep -q '"producto_id":110' && echo "  FALLA  el collar sigue en el carrito" || echo "  ok     el collar ya no está"

pedir DELETE /api/tienda/carrito/items/110
esperar "Quitar algo que no está da 404" 404
cerrar_sesion

# --- El rescatista también compra ---
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST /api/tienda/carrito/items '{"producto_id":112,"cantidad":1}'
esperar "Un rescatista puede agregar al carrito" 200 '"producto_id":112'
cerrar_sesion

# --- Un producto dado de baja no se puede agregar ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir POST /api/inventario/productos '{"nombre":"Producto que se da de baja","categoria":"ACCESORIO","especie":"TODAS","precio":100,"stock":5}'
BAJA=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
pedir DELETE "/api/inventario/productos/$BAJA"
cerrar_sesion
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/tienda/carrito/items "{\"producto_id\":$BAJA,\"cantidad\":1}"
esperar "Un producto dado de baja no se agrega (404)" 404
pedir GET /api/tienda/carrito
esperar "El cliente 103 ve su carrito de las semillas (el comedero)" 200 '"producto_id":112'
cerrar_sesion

# --- Compra: confirmar, mis compras y arrepentimiento ---
# Stock actual de un producto (lo mira la veterinaria): deja el número en STOCK.
stock_de() {
  local sesion=$SESION csrf=$CSRF
  iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
  pedir GET "/api/inventario/productos/$1"
  STOCK=$(printf '%s' "$RESPUESTA" | grep -o '"stock":[0-9]*' | head -1 | cut -d: -f2)
  SESION=$sesion; CSRF=$csrf
}

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
stock_de 101; ANTES=$STOCK
pedir POST /api/tienda/carrito/confirmar
esperar "Confirmar crea la factura V-… pendiente de pago" 201 '"estado":"PENDIENTE_PAGO"'
esperar "La compra trae hasta cuándo pagar" 201 '"pagar_antes_de":"'
esperar "  y los segundos que faltan, contados por el servidor (15 minutos)" 201 '"segundos_para_pagar":9'
NUMERO=$(printf '%s' "$RESPUESTA" | grep -o '"numero":"V-[0-9]*"' | cut -d'"' -f4)
stock_de 101
[ "$STOCK" -eq $((ANTES - 5)) ] && echo "  ok     Confirmar reserva el stock ($ANTES -> $STOCK)" || { echo "  FALLA  el stock no bajó 5 ($ANTES -> $STOCK)"; FALLAS=$((FALLAS+1)); }
TOTAL=$((TOTAL+1))

pedir GET /api/tienda/carrito
esperar "Después de confirmar, el carrito vuelve a estar vacío" 200 '"items":[]'
pedir POST /api/tienda/carrito/confirmar
esperar "Confirmar un carrito vacío da 409" 409 '"El carrito está vacío"'

pedir GET /api/tienda/compras
esperar "La compra aparece en Mis compras" 200 "\"$NUMERO\""
esperar "  de a 20, con si hay más" 200 '"por_pagina":20,"hay_mas":false'
esperar "  y la que todavía no se pagó no tiene factura" 200 '"tiene_factura":false'
pedir GET /api/tienda/compras
esperar "Sin fechas, se ven los últimos 30 días (V-000103 es de hace 12)" 200 '"V-000103"'
pedir GET '/api/tienda/compras?desde=2020-01-01&hasta=2020-01-31'
esperar "Entre dos fechas sin compras, la lista está vacía" 200 '"datos":[]'
esperar "  y devuelve las fechas que usó" 200 '"desde":"2020-01-01","hasta":"2020-01-31"'
pedir GET '/api/tienda/compras?hasta=2020-01-31'
esperar "Con solo hasta, son los 30 días que terminan ese día" 200 '"desde":"2020-01-02","hasta":"2020-01-31"'
pedir GET '/api/tienda/compras?desde=2020-02-30'
esperar "Una fecha que no existe da 400" 400 '"desde"'
pedir GET '/api/tienda/compras?desde=2020-02-01&hasta=2020-01-01'
esperar "Desde después de hasta da 400" 400 '"desde"'
pedir GET '/api/tienda/compras?pagina=0'
esperar "Una página 0 da 400" 400 '"pagina"'
pedir GET '/api/tienda/compras?pagina=2'
esperar "Una página después de la última está vacía" 200 '"datos":[],"pagina":2'
pedir GET "/api/tienda/compras/$NUMERO"
esperar "Se ve la compra con sus productos" 200 '"items":[{"producto_id":101'
cerrar_sesion

iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET "/api/tienda/compras/$NUMERO"
esperar "Un comprador no ve la compra de otro (404)" 404
pedir POST "/api/tienda/compras/$NUMERO/cancelar"
esperar "Ni la puede cancelar (404)" 404
cerrar_sesion

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST "/api/tienda/compras/$NUMERO/cancelar"
esperar "Arrepentirse antes de pagar cancela la compra" 200 '"estado":"CANCELADA"'
esperar "  con el motivo: la canceló el comprador" 200 '"motivo_cancelacion":"COMPRADOR"'
stock_de 101
[ "$STOCK" -eq "$ANTES" ] && echo "  ok     Al cancelar, el stock vuelve ($STOCK)" || { echo "  FALLA  el stock no volvió ($STOCK, esperaba $ANTES)"; FALLAS=$((FALLAS+1)); }
TOTAL=$((TOTAL+1))
pedir POST "/api/tienda/compras/$NUMERO/cancelar"
esperar "Una compra cancelada no se vuelve a cancelar (409)" 409 '"La compra ya está cancelada"'
cerrar_sesion

# --- Dos compradores quieren lo último: el segundo no puede confirmar ---
stock_de 107; HAY=$STOCK
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST /api/tienda/carrito/items "{\"producto_id\":107,\"cantidad\":$HAY}"
cerrar_sesion
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/tienda/carrito/items "{\"producto_id\":107,\"cantidad\":$HAY}"
esperar "Los dos pueden tener todo el stock en el carrito" 200 '"producto_id":107'
cerrar_sesion
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST /api/tienda/carrito/confirmar
esperar "El primero confirma y se lleva todo" 201 '"PENDIENTE_PAGO"'
OTRA=$(printf '%s' "$RESPUESTA" | grep -o '"numero":"V-[0-9]*"' | cut -d'"' -f4)
cerrar_sesion
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/tienda/carrito/confirmar
esperar "El segundo no puede confirmar: stock insuficiente (409)" 409 '"producto_id":107'
cerrar_sesion
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST "/api/tienda/compras/$OTRA/cancelar"
cerrar_sesion

# --- Veterinaria: pedidos para retirar y entrega ---
pedir GET /api/inventario/compras
esperar "Los pedidos para retirar piden sesión (401)" 401
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/inventario/compras
esperar "Un cliente no ve los pedidos de la veterinaria (403)" 403
pedir POST /api/tienda/compras/V-000101/entregada
esperar "Un cliente no puede marcar una entrega (403)" 403
cerrar_sesion

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/inventario/compras
esperar "Por defecto se ven los pedidos pagados, con el comprador" 200 '"numero":"V-000101","estado":"PAGADA"'
esperar "  y con sus productos" 200 '"items":[{"nombre":'
pedir GET '/api/inventario/compras?estado=ENTREGADA'
esperar "Se pueden ver los ya entregados" 200 '"V-000102"'
pedir GET '/api/inventario/compras?estado=CUALQUIERA'
esperar "Un estado desconocido se ignora (muestra los pagados)" 200 '"V-000101"'
pedir GET '/api/inventario/compras?estado=PENDIENTE_PAGO'
esperar "Los que esperan el pago no tienen pestaña (muestra los pagados)" 200 '"estado":"PAGADA"'
pedir GET '/api/inventario/compras?buscar=101'
esperar "Buscar por los últimos dígitos del número encuentra el pedido" 200 '"V-000101"'
pedir GET '/api/inventario/compras?buscar=V-000101'
esperar "Buscar por el número completo también" 200 '"V-000101"'
pedir GET '/api/inventario/compras?buscar=sof%C3%ADa%20ben%C3%ADtez'
esperar "Buscar por el nombre del comprador (sin importar mayúsculas)" 200 '"comprador":"Sofía Benítez"'
pedir GET '/api/inventario/compras?buscar=V-000102'
esperar "El buscador busca dentro de la pestaña (V-000102 está entregado)" 200 '"datos":[]'
pedir GET '/api/inventario/compras?buscar=%25'
esperar "Un % se busca como letra, no trae todo" 200 '"datos":[]'
pedir GET '/api/inventario/compras?buscar=0'
esperar "Buscar 0 no trae todo" 200 '"datos":[]'
CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir POST /api/tienda/compras/V-000101/entregada
CSRF=$CSRF_REAL
esperar "Marcar la entrega sin el token CSRF da 403" 403
pedir POST /api/tienda/compras/V-000101/entregada
esperar "La veterinaria constata el retiro" 200 '"estado":"ENTREGADA"'
esperar "  y queda cuándo se entregó" 200 '"entregada_en":"20'
pedir POST /api/tienda/compras/V-000101/entregada
esperar "Una compra ya entregada no se entrega dos veces (409)" 409 'no está lista para retirar'
pedir POST /api/tienda/compras/V-000103/entregada
esperar "Una compra cancelada no se entrega (409)" 409
pedir POST /api/tienda/compras/V-999999/entregada
esperar "Una compra que no existe da 404" 404
pedir GET '/api/inventario/compras?estado=ENTREGADA'
esperar "En Entregados aparece primero la más reciente" 200 '"datos":[{"numero":"V-000101"'
esperar "  con qué veterinaria la entregó" 200 '"entregada_por":"Dra. Laura Martínez"'
pedir GET /api/inventario/compras
if printf '%s' "$RESPUESTA" | grep -q '"V-000101"'; then echo "  FALLA  la entregada sigue en pedidos para retirar"; FALLAS=$((FALLAS+1)); else echo "  ok     La entregada ya no está en pedidos para retirar"; fi
TOTAL=$((TOTAL+1))
pedir GET '/api/inventario/compras?estado=ENTREGADA&desde=2020-01-01&hasta=2020-01-31'
esperar "Los entregados se filtran por fecha de entrega" 200 '"datos":[]'
pedir GET '/api/inventario/compras?estado=ENTREGADA&desde=2020-13-01'
esperar "  y una fecha inválida da 400" 400 '"desde"'
pedir GET '/api/inventario/compras?desde=2020-01-01&hasta=2020-01-31'
esperar "Los pedidos para retirar no se filtran por fecha (están todos vigentes)" 200 '"desde":null'
pedir GET '/api/inventario/compras?vence=hoy'
esperar "Se pueden pedir solo los que tienen hoy su último día" 200 '"datos":['
pedir GET /api/inventario/compras/resumen
esperar "El resumen cuenta los pedidos para retirar y los que vencen hoy" 200 '"para_retirar":'
esperar "  (y los de hoy)" 200 '"vencen_hoy":'
cerrar_sesion
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/inventario/compras/resumen
esperar "Un cliente no ve el resumen de la veterinaria (403)" 403
cerrar_sesion

# --- Vencimiento del plazo para pagar (V-000100 de las semillas: sin pagar desde hace 40 minutos) ---
# Ya se canceló "al pasar", con el primer pedido de un comprador a la tienda.
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/tienda/compras/V-000100
esperar "Sin pagar en 15 minutos, la compra se cancela sola" 200 '"estado":"CANCELADA"'
esperar "  con el motivo: no se pagó a tiempo" 200 '"motivo_cancelacion":"SIN_PAGO"'
cerrar_sesion
stock_de 105
[ "$STOCK" = 30 ] && echo "  ok     y el stock reservado vuelve (30)" || { echo "  FALLA  el stock de los snacks es $STOCK, esperaba 30"; FALLAS=$((FALLAS+1)); }
TOTAL=$((TOTAL+1))

# --- El comprador cancela un pedido ya pagado (V-000099 de las semillas, pagado hace 2 días) ---
# Faltan al menos 3 días para su último día de retiro: cancela con anticipación y se le devuelve el 75 %.
stock_de 113; ANTES=$STOCK
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/tienda/compras/V-000099/cancelar
esperar "El comprador cancela un pedido pagado" 200 '"estado":"CANCELADA"'
esperar "  con el motivo: la canceló el comprador" 200 '"motivo_cancelacion":"COMPRADOR"'
esperar "  y con anticipación se le devuelve el 75 % (de \$ 14.500)" 200 '"reintegro":{"porcentaje":75,"monto":10875'
esperar "  ya hecho (en pruebas, Mercado Pago es simulado)" 200 '"estado":"HECHO"}'
pedir GET /api/notificaciones
esperar "  y le llega el aviso con cuánto se le devuelve" 200 'Cancelaste tu pedido V-000099 y los productos volvieron a la tienda. Te devolvemos $ 10.875,00 (el 75 % de lo que pagaste)'
pedir GET /api/tienda/compras/V-000099/factura
esperar "  y la factura (cancelada) muestra el reintegro" 200 '"reintegro":{"porcentaje":75'
pedir POST /api/tienda/compras/V-000099/cancelar
esperar "No se cancela dos veces (409)" 409 '"La compra ya está cancelada"'
cerrar_sesion
stock_de 113
[ "$STOCK" -eq $((ANTES + 1)) ] && echo "  ok     el stock de la correa vuelve ($ANTES -> $STOCK)" || { echo "  FALLA  el stock no volvió ($ANTES -> $STOCK)"; FALLAS=$((FALLAS+1)); }
TOTAL=$((TOTAL+1))

iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST /api/tienda/compras/V-000102/cancelar
esperar "Un pedido ya entregado no se cancela (409)" 409 'ya se entregó'
cerrar_sesion

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET '/api/inventario/compras?estado=CANCELADA'
esperar "La veterinaria ve los cancelados con su motivo" 200 '"numero":"V-000099"'
esperar "  (cancelado por el comprador)" 200 '"motivo_cancelacion":"COMPRADOR"'
esperar "  (vencido)" 200 '"motivo_cancelacion":"VENCIDA"'
cerrar_sesion

# --- Pago (simulado: en GitHub y en local no hay Mercado Pago) ---
numero_de() { printf '%s' "$RESPUESTA" | grep -o '"numero":"V-[0-9]*"' | head -1 | cut -d'"' -f4; }

iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST /api/tienda/carrito/items '{"producto_id":109,"cantidad":1}'
pedir POST /api/tienda/carrito/confirmar
PAGO=$(numero_de)
pedir POST "/api/tienda/compras/$PAGO/pago"
esperar "Pagar devuelve a dónde ir (en pruebas, el pago simulado)" 200 '"url":"\/tienda\/pago-simulado.html?numero='"$PAGO"'"'
pedir POST /api/tienda/pagos/simulado "{\"numero\":\"$PAGO\",\"resultado\":\"cualquiera\"}"
esperar "Un resultado inválido da 400" 400
pedir POST /api/tienda/pagos/simulado "{\"numero\":\"$PAGO\",\"resultado\":\"rechazado\"}"
esperar "Pago rechazado: queda registrado" 200 '"resultado":"rechazado"'
esperar "  y la compra sigue esperando el pago" 200 '"estado":"PENDIENTE_PAGO"'
pedir POST /api/tienda/pagos/simulado "{\"numero\":\"$PAGO\",\"resultado\":\"aprobado\"}"
esperar "Pago aprobado: la compra queda lista para retirar" 200 '"estado":"PAGADA"'
esperar "  con el número de operación como comprobante" 200 '"operacion_mp":"simulado-'
pedir GET /api/notificaciones
esperar "  y al comprador le llega la constancia del pago" 200 "Recibimos el pago de tu pedido $PAGO"
cerrar_sesion
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/notificaciones
esperar "  y a la veterinaria, el aviso del pedido nuevo para retirar" 200 "Nuevo pedido para retirar: $PAGO"
cerrar_sesion
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST "/api/tienda/compras/$PAGO/pago"
esperar "Una compra pagada no se vuelve a pagar (409)" 409 'no está esperando el pago'
pedir POST /api/tienda/pagos/simulado "{\"numero\":\"$PAGO\",\"resultado\":\"aprobado\"}"
esperar "Un segundo pago de una compra ya pagada se devuelve" 200 '"resultado":"devolver"'

# Pago tardío con stock: la compra se canceló, pero el pago llega igual y hay stock -> se revive.
pedir POST /api/tienda/carrito/items '{"producto_id":114,"cantidad":2}'
pedir POST /api/tienda/carrito/confirmar
TARDIO=$(numero_de)
pedir POST "/api/tienda/compras/$TARDIO/cancelar"
stock_de 114; ANTES=$STOCK
pedir POST /api/tienda/pagos/simulado "{\"numero\":\"$TARDIO\",\"resultado\":\"aprobado\"}"
esperar "Pago tardío con stock: la compra revive y queda pagada" 200 '"resultado":"revivido"'
pedir GET /api/notificaciones
esperar "  y le llega el mismo aviso que a un pago a tiempo" 200 "Recibimos el pago de tu pedido $TARDIO"
stock_de 114
[ "$STOCK" -eq $((ANTES - 2)) ] && echo "  ok     el stock se vuelve a reservar ($ANTES -> $STOCK)" || { echo "  FALLA  el stock no se reservó ($ANTES -> $STOCK)"; FALLAS=$((FALLAS+1)); }
TOTAL=$((TOTAL+1))

# Pago tardío sin stock: entre la cancelación y el pago, otro comprador se llevó todo -> se devuelve.
stock_de 111; HAY=$STOCK
pedir POST /api/tienda/carrito/items "{\"producto_id\":111,\"cantidad\":$HAY}"
pedir POST /api/tienda/carrito/confirmar
SIN_STOCK=$(numero_de)
pedir POST "/api/tienda/compras/$SIN_STOCK/cancelar"
cerrar_sesion
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/tienda/carrito/items "{\"producto_id\":111,\"cantidad\":$HAY}"
pedir POST /api/tienda/carrito/confirmar
OTRO=$(numero_de)
cerrar_sesion
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST /api/tienda/pagos/simulado "{\"numero\":\"$SIN_STOCK\",\"resultado\":\"aprobado\"}"
esperar "Pago tardío sin stock: se devuelve el importe" 200 '"resultado":"devolver"'
esperar "  y la compra sigue cancelada" 200 '"estado":"CANCELADA"'
pedir GET /api/notificaciones
esperar "  y le avisa que se le devolvió el dinero porque terminó el tiempo para pagar" 200 "Tu pago del pedido $SIN_STOCK llegó cuando ya había terminado el tiempo para pagar"
cerrar_sesion
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST "/api/tienda/compras/$OTRO/cancelar"
cerrar_sesion

# --- Factura: solo de las compras pagadas (aunque después se hayan cancelado) ---
pedir GET "/api/tienda/compras/$PAGO/factura"
esperar "La factura pide sesión (401)" 401
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET "/api/tienda/compras/$PAGO/factura"
esperar "El comprador ve la factura de su compra pagada" 200 "\"numero\":\"$PAGO\""
esperar "  con el medio de pago y el número de operación" 200 '"pago":{"medio":"Mercado Pago","operacion":"simulado-'
esperar "  y los productos" 200 '"items":[{"producto_id":109'
pedir GET /api/tienda/compras/V-000100/factura
esperar "Una compra que no se pagó no tiene factura (404)" 404 '"Factura no encontrada"'
pedir GET "/api/tienda/compras/$SIN_STOCK/factura"
esperar "Un pago tardío que se devolvió no da factura (404)" 404
pedir GET "/api/tienda/compras/$SIN_STOCK"
esperar "  y la compra dice que no tiene factura" 200 '"tiene_factura":false'
pedir GET "/api/tienda/compras/$PAGO"
esperar "Una compra pagada dice que tiene factura" 200 '"tiene_factura":true'
cerrar_sesion
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET "/api/tienda/compras/$PAGO/factura"
esperar "Un comprador no ve la factura de otro (404)" 404
pedir GET /api/tienda/compras/V-000103/factura
esperar "Una compra pagada y después cancelada tiene factura (como cancelada)" 200 '"estado":"CANCELADA"'
cerrar_sesion
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET "/api/tienda/compras/$PAGO/factura"
esperar "La veterinaria ve la factura de cualquier compra pagada" 200 '"comprador":{"nombre":'
cerrar_sesion

# El aviso de Mercado Pago sin firma válida no se acepta.
pedir POST '/api/tienda/pagos/aviso?type=payment&data.id=123' '{"type":"payment","data":{"id":"123"}}'
esperar "Un aviso de pago sin firma de Mercado Pago da 401" 401

# --- Plazos configurables: valen para las compras nuevas, no para las que ya existen ---
# $PAGO es la compra pagada del rescatista (de las pruebas del pago): sigue para retirar.
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET "/api/tienda/compras/$PAGO"
RETIRO_ANTES=$(printf '%s' "$RESPUESTA" | grep -o '"retirar_hasta":"[0-9-]*"')
[ -n "$RETIRO_ANTES" ] && echo "  ok     La compra pagada tiene su fecha de retiro ($RETIRO_ANTES)" || { echo "  FALLA  la compra $PAGO no tiene fecha de retiro"; FALLAS=$((FALLAS+1)); }
TOTAL=$((TOTAL+1))
cerrar_sesion
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir PUT /api/configuracion '{"valores":{"minutos_para_pagar":20,"dias_habiles_para_retirar":10}}'
esperar "La veterinaria cambia los plazos de la tienda" 200
cerrar_sesion
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/tienda/carrito
esperar "El carrito muestra los plazos nuevos" 200 '"minutos_para_pagar":20,"dias_habiles_para_retirar":10'
esperar "  y la política de reintegro (75 % / 50 % / 48 horas)" 200 '"politica_reintegro":{"anticipado":75,"ultimo_momento":50,"horas":48}'
pedir POST /api/tienda/carrito/items '{"producto_id":109,"cantidad":1}'
pedir POST /api/tienda/carrito/confirmar
esperar "Una compra nueva tiene 20 minutos para pagar" 201 '"segundos_para_pagar":1'
esperar "  y 10 días hábiles para retirar" 201 '"dias_habiles_para_retirar":10'
NUEVA=$(numero_de)
pedir POST "/api/tienda/compras/$NUEVA/cancelar"
cerrar_sesion
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET "/api/tienda/compras/$PAGO"
esperar "A una compra que ya existía no le cambia el plazo" 200 "$RETIRO_ANTES"
cerrar_sesion
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir PUT /api/configuracion '{"valores":{"minutos_para_pagar":15,"dias_habiles_para_retirar":5}}'
esperar "Los plazos vuelven a los de siempre" 200
pedir PUT /api/configuracion '{"valores":{"porcentaje_reintegro_ultimo_momento":80}}'
esperar "El reintegro a último momento no puede ser mayor que con anticipación (400)" 400 '"porcentaje_reintegro_ultimo_momento"'

# --- Reintegro a último momento: con 3 días hábiles para retirar (a lo sumo 5 días corridos) y 168
#     horas (7 días) de anticipación exigidas, cualquier cancelación es a último momento: 50 %.
#     (3 es el mínimo con el primer recordatorio el día 1: tiene que ser 2 días antes del último.) ---
pedir PUT /api/configuracion '{"valores":{"dia_primer_recordatorio":1,"dias_habiles_para_retirar":3,"horas_anticipacion_reintegro":168}}'
esperar "La veterinaria exige 168 horas de anticipación para el reintegro mayor" 200
cerrar_sesion
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST /api/tienda/carrito/items '{"producto_id":109,"cantidad":1}'
pedir POST /api/tienda/carrito/confirmar
ULTIMO=$(numero_de)
esperar "La compra guarda su política (168 horas)" 201 '"horas":168'
pedir POST /api/tienda/pagos/simulado "{\"numero\":\"$ULTIMO\",\"resultado\":\"aprobado\"}"
pedir GET "/api/tienda/compras/$ULTIMO"
esperar "Pagada: si cancela hoy, se le devolvería el 50 %" 200 '"porcentaje_hoy":50'
pedir POST "/api/tienda/compras/$ULTIMO/cancelar"
esperar "Cancela a último momento: se le devuelve el 50 %" 200 '"reintegro":{"porcentaje":50'
cerrar_sesion
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET "/api/inventario/compras?estado=CANCELADA&buscar=$ULTIMO"
esperar "La veterinaria ve el reintegro en los cancelados" 200 '"reintegro":{"porcentaje":50'
pedir PUT /api/configuracion '{"valores":{"dias_habiles_para_retirar":5,"dia_primer_recordatorio":2,"horas_anticipacion_reintegro":48}}'
esperar "La anticipación vuelve a 48 horas (y el plazo a 5 días hábiles)" 200
cerrar_sesion

# --- Tarea de vencimientos (GitHub Actions) ---
pedir POST /api/tienda/tareas/vencer
esperar "La tarea sin su token da 401" 401
if [ -n "${TAREAS_TOKEN:-}" ]; then
  RESPUESTA=$(curl -s -w '\n%{http_code}' -X POST -H "X-Tarea-Token: $TAREAS_TOKEN" "$BASE_URL/api/tienda/tareas/vencer")
  CODIGO=$(printf '%s' "$RESPUESTA" | tail -n1); RESPUESTA=$(printf '%s' "$RESPUESTA" | sed '$d')
  esperar "La tarea con su token corre y cuenta lo que hizo" 200 '"canceladas_sin_pago":'
  esperar "  (también los reintegros pendientes)" 200 '"reintegros":'
else
  echo "  (sin TAREAS_TOKEN: no se prueba la tarea con su token)"
fi
