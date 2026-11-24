# shellcheck shell=bash
# Entrega 5 (24/11): "Productos → Movimientos" e "Insumos → Movimientos" con filtro de fechas y el
# origen de cada movimiento (la consulta o la compra), el límite de stock bajo en los listados, y el
# calendario sanitario con solo las mascotas que tienen eventos y el dueño de la mascota.
# Contratos: docs/api/contrato.md y contrato-insumos.md de Inventario; contrato-mascotas-turnos.md y
# contrato-calendario.md de Pacientes. Usa las ventas de la semilla 010 (V-000101 de producto 101) y la
# consulta de 07_consultas.sh ($CONSULTA, que usó el insumo 101).
es_entorno_de_prueba || return 0

HOY=$(date +%F)
HACE_UNA_SEMANA=$(date -d '7 days ago' +%F 2>/dev/null || date -v-7d +%F)

pedir GET /api/inventario/productos/movimientos
esperar "Los movimientos de productos piden sesión (401)" 401

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/inventario/productos/movimientos
esperar "Un cliente no ve los movimientos de productos (403)" 403
cerrar_sesion

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

# --- Productos → Movimientos ---
pedir GET /api/inventario/productos/movimientos
esperar "La veterinaria ve los movimientos de todos los productos, con su nombre" 200 '"producto":"'
pedir GET '/api/inventario/productos/movimientos?producto=101'
esperar "El filtro por producto trae los de ese producto" 200 '"producto_id":101'
esperar "  y la venta de la tienda trae el número de la compra (para enlazar la factura)" 200 '"compra":"V-000101"'
pedir GET "/api/inventario/productos/movimientos?producto=101&desde=$HACE_UNA_SEMANA&hasta=$HOY"
esperar "El filtro de fechas deja la venta de ayer" 200 '"compra":"V-000101"'
pedir GET '/api/inventario/productos/movimientos?producto=101&desde=2000-01-01&hasta=2000-01-31'
esperar "Unas fechas sin movimientos dan la lista vacía" 200 '"datos":[]'
pedir GET '/api/inventario/productos/movimientos?desde=2026-02-30'
esperar "Una fecha que no existe da 400" 400 '"desde"'
pedir GET '/api/inventario/productos/movimientos?desde=2026-12-01&hasta=2026-11-01'
esperar "Desde posterior a hasta da 400" 400 'posterior'
pedir GET /api/inventario/productos/101/movimientos
esperar "El historial de un producto sigue andando, con la referencia" 200 '"compra":"V-000101"'

# --- Insumos → Movimientos ---
pedir GET '/api/inventario/insumos/movimientos?insumo=101'
esperar "Los movimientos de insumos traen consulta_id y compra" 200 '"compra":null'
if [ -n "${CONSULTA:-}" ]; then
  esperar "  y el uso en una consulta apunta a esa consulta" 200 "\"consulta_id\":$CONSULTA"
fi
pedir GET "/api/inventario/insumos/movimientos?desde=$HOY&hasta=$HOY"
esperar "Los movimientos de insumos también filtran por fechas" 200 '"datos":['
pedir GET '/api/inventario/insumos/movimientos?hasta=30/11/2026'
esperar "Una fecha con otro formato da 400" 400 '"hasta"'

# --- Límite de stock bajo en los listados ---
pedir GET /api/inventario/productos
esperar "El listado de productos manda el límite de stock bajo" 200 '"limite_stock_bajo":'
pedir GET /api/inventario/insumos
esperar "El listado de insumos también" 200 '"limite_stock_bajo":'

# --- Calendario sanitario ---
pedir GET '/api/pacientes/mascotas?con_calendario=1'
esperar "Con con_calendario=1 vienen las mascotas con vacunas o desparasitaciones" 200 '"nombre":"Luna"'
pedir GET '/api/pacientes/mascotas?con_calendario=1&buscar=Aguirre'
esperar "  y se busca por el dueño (Tomás Aguirre, de Luna y Tom)" 200 '"nombre":"Luna"'
pedir GET '/api/pacientes/mascotas?con_calendario=1&buscar=Canela'
esperar "  y no viene una mascota sin calendario (Canela, en adopción)" 200 '"mascotas":[]'
pedir GET /api/pacientes/mascotas/103/calendario-sanitario
esperar "El calendario trae el dueño de la mascota" 200 '"duenio":{"id":103,'
cerrar_sesion

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET '/api/pacientes/mascotas?con_calendario=1'
esperar "El cliente también puede pedir solo las suyas con calendario" 200 '"mascotas":['
cerrar_sesion
