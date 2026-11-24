# shellcheck shell=bash
# Casos de los reportes y sugerencias (Entrega 5, rol 4). Contrato: docs/api/contrato-reportes.md
# del repo Reportes. Usan las semillas 002 (productos), 003 (insumos), 006 (consulta 101 de Tom)
# y 009 (turnos de las últimas 4 semanas y producto 101 por vencer en 7 días). Solo lectura.

# --- Salud y permisos (también corre contra producción, solo lectura) ---
cerrar_sesion
pedir GET /api/reportes/salud
esperar "Reportes responde en /api/reportes/salud" 200 '"modulo":"Reportes"'

pedir GET /api/reportes/sugerencias
esperar "Las sugerencias sin sesión dan 401" 401
pedir GET /api/reportes/turnos-atendidos
esperar "Los turnos atendidos sin sesión dan 401" 401
pedir GET /api/reportes/stock
esperar "El reporte de stock sin sesión da 401" 401

es_entorno_de_prueba || return 0

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/reportes/sugerencias
esperar "Un cliente no ve las sugerencias (403)" 403
pedir GET /api/reportes/turnos-atendidos
esperar "Un cliente no ve los turnos atendidos (403)" 403
pedir GET /api/reportes/stock
esperar "Un cliente no ve el reporte de stock (403)" 403

iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/reportes/sugerencias
esperar "Una rescatista tampoco ve los reportes (403)" 403
cerrar_sesion

# --- Veterinaria: sugerencias (Qué promocionar y Qué liquidar) ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

pedir GET /api/reportes/sugerencias
esperar "La veterinaria ve las sugerencias con la franja de menor ocupación" 200 '"franja_sugerida":{'
esperar "  con las 4 semanas analizadas" 200 '"semanas_analizadas":4'
esperar "  con el texto de qué promocionar" 200 'turnos en 4 semanas: conviene promocionarlos'
# Lunes a la mañana: las semillas cargan 2 turnos. Se pide "2 o más" y no exactamente 2: un lunes,
# otros casos de esta misma prueba atienden turnos ese día a la mañana y también entran en la cuenta.
LUNES_MANIANA=$(printf '%s' "$RESPUESTA" | grep -o '"dia_semana":"Lunes","franja":"mañana","cantidad_turnos":[0-9]*' | grep -o '[0-9]*$')
TOTAL=$((TOTAL + 1))
if [ "${LUNES_MANIANA:-0}" -ge 2 ]; then
  echo "  ok       con el listado de franjas de lunes a sábado (lunes a la mañana: $LUNES_MANIANA turnos)"
else
  FALLAS=$((FALLAS + 1))
  echo "  FALLA    con el listado de franjas de lunes a sábado: lunes a la mañana tiene ${LUNES_MANIANA:-ninguno}, esperaba 2 o más"
fi
esperar "  con el producto 101 por vencer en 7 días (30 % sugerido)" 200 '"producto_id":101,'
esperar "    y su descuento sugerido de 30 %" 200 '"descuento_sugerido":30'
esperar "  con el producto 107 por vencer en 20 días (15 % sugerido)" 200 '"producto_id":107,'
esperar "    y su descuento sugerido de 15 %" 200 '"descuento_sugerido":15'

# --- Turnos atendidos con su consulta y su factura ---
pedir GET '/api/reportes/turnos-atendidos?desde=18-11-2026'
esperar "Turnos atendidos con fecha mal escrita da 400" 400
pedir GET '/api/reportes/turnos-atendidos?desde=2026-11-20&hasta=2026-11-01'
esperar "Turnos atendidos con desde posterior a hasta da 400" 400

pedir GET /api/reportes/turnos-atendidos
esperar "El reporte de turnos atendidos trae el resumen y la lista" 200 '"resumen":{"cantidad_turnos":'
esperar "  con la consulta finalizada de Tom (semilla 006) y su factura C-000101" 200 '"factura_numero":"C-000101"'
esperar "  con el nombre de la mascota y el diagnóstico" 200 '"mascota_nombre":"Tom"'

AYER=$(date -u -d '-3 hours -1 day' +%F)
pedir GET "/api/reportes/turnos-atendidos?desde=$AYER&hasta=$AYER"
esperar "Filtrando por la fecha de ayer encuentra el turno de Tom" 200 '"factura_numero":"C-000101"'

pedir GET '/api/reportes/turnos-atendidos?desde=2000-01-01&hasta=2000-01-02'
esperar "Un rango sin turnos atendidos devuelve 0 turnos y total 0" 200 '"resumen":{"cantidad_turnos":0,"total_facturado":0}'

# --- Stock y movimientos de inventario ---
pedir GET '/api/reportes/stock?hasta=fecha-invalida'
esperar "El reporte de stock con fecha inválida da 400" 400
pedir GET '/api/reportes/stock?desde=2026-11-20&hasta=2026-11-01'
esperar "El reporte de stock con desde posterior a hasta da 400" 400

pedir GET /api/reportes/stock
esperar "El reporte de stock trae el resumen con el límite de stock bajo" 200 '"limite_stock_bajo":10'
esperar "  con los productos activos y su stock" 200 '"Alimento Royal Canin Medium Puppy para cachorros 3 kg"'
esperar "  con los insumos activos y su estado" 200 '"Solución fisiológica 500 ml"'
esperar "  y los movimientos de inventario" 200 '"movimientos":['

cerrar_sesion
