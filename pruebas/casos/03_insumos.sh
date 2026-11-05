# shellcheck shell=bash
# Casos de insumos (necesitan la cuenta de la veterinaria y los insumos de los datos semilla).
es_entorno_de_prueba || return 0

pedir GET /api/inventario/insumos
esperar "El listado de insumos sin sesión da 401" 401

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/inventario/insumos
esperar "Un cliente no puede ver los insumos (403)" 403
cerrar_sesion

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

pedir GET /api/inventario/insumos
esperar "El veterinario ve el listado de insumos" 200 '"Jeringa descartable 3 ml"'
esperar "El listado incluye los dados de baja" 200 '"Venda elástica 5 cm"'
esperar "El insumo en falta figura EN_FALTA" 200 '"estado":"EN_FALTA"'

pedir GET /api/inventario/insumos/108
esperar "El detalle trae stock_bajo (108 tiene 3)" 200 '"stock_bajo":true'

pedir GET /api/inventario/insumos/999999
esperar "Un insumo inexistente da 404" 404 '"Insumo no encontrado"'

pedir GET /api/inventario/insumos/abc
esperar "Un id que no es número da 404" 404

pedir POST /api/inventario/insumos '{"nombre":"A","costo":-5,"stock":"diez"}'
esperar "Un alta con datos inválidos da 400 por campo" 400 '"campos"'

pedir POST /api/inventario/insumos '{"nombre":"Insumo de humo","costo":0,"stock":0}'
esperar "Alta con costo 0 y stock 0: queda EN_FALTA" 201 '"estado":"EN_FALTA"'
NUEVO=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

pedir PUT "/api/inventario/insumos/$NUEVO" '{"nombre":"Insumo de humo editado","costo":12.5,"stock":999}'
esperar "La edición cambia nombre y costo" 200 '"costo":12.5'
esperar "La edición no cambia el stock" 200 '"stock":0'

pedir POST "/api/inventario/insumos/$NUEVO/stock" '{"cantidad":0}'
esperar "Cargar una cantidad inválida da 400" 400 '"cantidad"'

pedir POST "/api/inventario/insumos/$NUEVO/stock" '{"cantidad":5}'
esperar "Cargar stock lo suma y pasa a DISPONIBLE" 200 '"estado":"DISPONIBLE"'

pedir POST "/api/inventario/insumos/$NUEVO/retiro" '{"cantidad":9}'
esperar "Retirar más de lo que hay da 409" 409 '"Stock insuficiente"'

pedir POST "/api/inventario/insumos/$NUEVO/retiro" '{"cantidad":5}'
esperar "Retirar todo deja el insumo EN_FALTA" 200 '"stock":0'

pedir GET "/api/inventario/insumos/$NUEVO/movimientos"
esperar "Los movimientos muestran la salida por retiro (AJUSTE)" 200 '"motivo":"AJUSTE"'
esperar "Los movimientos muestran la carga" 200 '"motivo":"CARGA_VETERINARIO"'

CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir DELETE "/api/inventario/insumos/$NUEVO"
esperar "Dar de baja sin el token CSRF da 403" 403
CSRF=$CSRF_REAL

pedir DELETE "/api/inventario/insumos/$NUEVO"
esperar "Dar de baja responde 204" 204

pedir POST "/api/inventario/insumos/$NUEVO/stock" '{"cantidad":1}'
esperar "No se puede cargar stock a un insumo dado de baja (409)" 409 '"El insumo está dado de baja"'
