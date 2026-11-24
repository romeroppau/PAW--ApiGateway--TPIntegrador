# shellcheck shell=bash
# Casos de las promociones ("Publicitar" desde las sugerencias de Reportes, migración 016): quién
# puede publicarlas, las reglas del descuento y de las fechas, cómo se ven en la tienda y el precio
# que cobran el carrito y la compra. Usan los productos de las semillas (002_productos):
# 110 (collar, $5200, no vence) y 107 (pipeta, vence en 20 días). Al final no queda ninguna vigente.
es_entorno_de_prueba || return 0

dia() { date -d "$1 days" +%F; }   # dia 5 → la fecha de dentro de 5 días (YYYY-MM-DD)
id_de() { printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

# --- Quién puede ---
pedir GET /api/inventario/promociones
esperar "Las promociones del panel sin sesión dan 401" 401
pedir GET /api/tienda/promociones
esperar "La sección de promociones de la tienda es pública (y empieza vacía)" 200 '"datos":[]'

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/inventario/promociones "{\"producto_id\":110,\"porcentaje\":20,\"hasta\":\"$(dia 5)\"}"
esperar "Un cliente no puede publicitar (403)" 403
cerrar_sesion

# --- Reglas ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir POST /api/inventario/promociones "{\"producto_id\":110,\"porcentaje\":20,\"hasta\":\"$(dia 5)\"}"
esperar "Publicitar sin el token CSRF correcto da 403" 403
CSRF=$CSRF_REAL

pedir POST /api/inventario/promociones "{\"producto_id\":110,\"porcentaje\":95,\"hasta\":\"$(dia -2)\"}"
esperar "Un descuento de 95 % da 400" 400 '"porcentaje":"El descuento tiene que ser un número entero entre 5 y 90'
esperar "  y una fecha pasada también" 400 '"hasta":"La promoción no puede terminar antes de hoy"'
pedir POST /api/inventario/promociones "{\"producto_id\":110,\"porcentaje\":20,\"hasta\":\"$(dia 120)\"}"
esperar "Más de 90 días da 400" 400 'como mucho 90 días'
pedir POST /api/inventario/promociones "{\"producto_id\":107,\"porcentaje\":30,\"hasta\":\"$(dia 25)\"}"
esperar "No puede durar más que el vencimiento del producto" 400 'la promoción no puede durar más que eso'
pedir POST /api/inventario/promociones "{\"producto_id\":99999,\"porcentaje\":20,\"hasta\":\"$(dia 5)\"}"
esperar "Un producto que no existe da 404" 404 '"Producto no encontrado"'

# --- Publicitar ---
pedir POST /api/inventario/promociones "{\"producto_id\":110,\"porcentaje\":20,\"hasta\":\"$(dia 5)\"}"
esperar "Publicita el collar con 20 % (201)" 201 '"porcentaje":20,"precio_promocion":4160'
PROMO_COLLAR=$(id_de)
pedir POST /api/inventario/promociones "{\"producto_id\":110,\"porcentaje\":30,\"hasta\":\"$(dia 5)\"}"
esperar "Un producto con una promoción vigente no puede tener otra (409)" 409 '"Este producto ya tiene una promoción del 20 %'
pedir POST /api/inventario/promociones "{\"producto_id\":107,\"porcentaje\":30,\"hasta\":\"$(dia 20)\"}"
esperar "Publicita la pipeta hasta el día que vence" 201 '"porcentaje":30'
PROMO_PIPETA=$(id_de)
pedir GET /api/inventario/promociones
esperar "El panel lista las vigentes, la que termina antes primero" 200 "\"id\":$PROMO_COLLAR,\"producto_id\":110"
cerrar_sesion

# --- La tienda ---
pedir GET /api/tienda/promociones
esperar "La sección de promociones: el descuento más grande primero" 200 '"datos":[{"id":107,'
esperar "  con el precio rebajado" 200 '"promocion":{"porcentaje":20,"precio":4160,'
pedir GET '/api/tienda/productos?buscar=Collar%20de%20nylon'
esperar "El catálogo muestra la promoción del producto" 200 '"precio":5200,"vencimiento":null,"disponible":true,"promocion":{"porcentaje":20,"precio":4160'
pedir GET /api/tienda/productos/112
esperar "Un producto sin promoción tiene promocion: null" 200 '"promocion":null'

# --- El carrito y la compra cobran el precio con descuento ---
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/tienda/carrito
esperar "El cliente empieza sin carrito abierto" 200 '"items":[]'
pedir POST /api/tienda/carrito/items '{"producto_id":110,"cantidad":2}'
esperar "El carrito cobra el precio con descuento" 200 '"precio_unitario":4160,"precio_sin_descuento":5200,"descuento":20'
esperar "  y el total también" 200 '"total":8320'
pedir POST /api/tienda/carrito/confirmar
esperar "La compra se confirma con el precio de la promoción" 201 '"total":8320'
COMPRA_PROMO=$(printf '%s' "$RESPUESTA" | grep -o '"numero":"V-[0-9]*"' | cut -d'"' -f4)
cerrar_sesion

# --- Terminar ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir DELETE "/api/inventario/promociones/$PROMO_COLLAR"
esperar "La veterinaria termina la promoción del collar (204)" 204
pedir DELETE "/api/inventario/promociones/$PROMO_COLLAR"
esperar "Una promoción ya terminada da 404" 404 '"No hay una promoción vigente con ese número"'
cerrar_sesion

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET "/api/tienda/compras/$COMPRA_PROMO"
esperar "La compra ya hecha conserva el precio con descuento" 200 '"precio_unitario":4160'
pedir POST "/api/tienda/compras/$COMPRA_PROMO/cancelar"
esperar "  (se cancela para devolver el stock)" 200
pedir POST /api/tienda/carrito/items '{"producto_id":110,"cantidad":1}'
esperar "Terminada la promoción, el carrito vuelve al precio de siempre" 200 '"precio_unitario":5200,"precio_sin_descuento":null,"descuento":null'
pedir DELETE /api/tienda/carrito/items/110
cerrar_sesion

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir DELETE "/api/inventario/promociones/$PROMO_PIPETA"
esperar "Termina la de la pipeta" 204
cerrar_sesion
pedir GET /api/tienda/promociones
esperar "No queda ninguna promoción en la tienda" 200 '"datos":[]'
