# shellcheck shell=bash
# Casos del stock interno y de los pendientes de inventario de la Entrega 4.
#
# El descuento de stock (POST /internal/stock/descontar) es de proceso a proceso: desde afuera
# tiene que estar bloqueado. Lo que hace por dentro (reintentos, cantidad cambiada entre intentos,
# ítem inexistente, hora de Argentina) lo prueban las PHPUnit de Inventario contra MySQL
# (tests/StockInternoRepositorioTest.php) y, de punta a punta, 07_consultas.sh y 08_correcciones.sh.

# --- /internal/ bloqueado desde afuera (también en producción) ---
cerrar_sesion
pedir POST /internal/stock/descontar '{"usuario_id":101,"items":[{"tipo":"INSUMO","id":101,"cantidad":1,"id_operacion":"humo-afuera"}]}'
esperar "El descuento interno no se puede llamar desde afuera (404)" 404

# Aunque alguien adivine el nombre del header del token, Nginx corta antes de llegar al módulo.
CODIGO=$(curl --silent --max-time 60 -o /dev/null -w '%{http_code}' -X POST \
  -H 'X-Servicio-Token: cualquiera' -H 'Content-Type: application/json' --data '{}' \
  "$BASE_URL/internal/stock/descontar")
RESPUESTA=""
esperar "Con un X-Servicio-Token inventado también da 404" 404

es_entorno_de_prueba || return 0

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

# --- "Ya pedido": el 108 tiene stock bajo (3), el 101 tiene stock de sobra ---
pedir POST /api/inventario/insumos/108/pedido
esperar "Un insumo con stock bajo se marca Ya pedido" 200 '"estado":"YA_PEDIDO"'

pedir GET /api/inventario/insumos
esperar "El listado muestra el insumo Ya pedido" 200 '"estado":"YA_PEDIDO"'

pedir POST /api/inventario/insumos/101/pedido
esperar "Un insumo con stock suficiente no se marca pedido (409)" 409 'stock bajo'

pedir POST /api/inventario/insumos/109/pedido
esperar "Un insumo dado de baja no se marca pedido (409)" 409 'dado de baja'

pedir DELETE /api/inventario/insumos/108/pedido
esperar "Se desmarca el Ya pedido y vuelve a DISPONIBLE" 200 '"estado":"DISPONIBLE"'

pedir POST /api/inventario/insumos/108/pedido
pedir POST /api/inventario/insumos/108/stock '{"cantidad":20}'
esperar "Al cargar stock (llegó el pedido) deja de estar Ya pedido" 200 '"estado":"DISPONIBLE"'
pedir POST /api/inventario/insumos/108/retiro '{"cantidad":20}'

# --- Reactivar un insumo dado de baja (el 109) ---
pedir POST /api/inventario/insumos/109/reactivar
esperar "Se reactiva un insumo dado de baja" 200 '"activo":true'

pedir POST /api/inventario/insumos/109/stock '{"cantidad":1}'
esperar "El insumo reactivado vuelve a aceptar stock" 200 '"id":109'
pedir POST /api/inventario/insumos/109/retiro '{"cantidad":1}'

pedir DELETE /api/inventario/insumos/109
esperar "Se vuelve a dar de baja (como en las semillas)" 204

pedir POST /api/inventario/insumos/999999/reactivar
esperar "Reactivar un insumo que no existe da 404" 404

# --- Reactivar un producto (el 115): sale de la tienda y vuelve ---
pedir DELETE /api/inventario/productos/115
esperar "Se da de baja la cama acolchada" 204

pedir GET /api/tienda/productos/115
esperar "Un producto dado de baja no se ve en la tienda" 404

pedir POST /api/inventario/productos/115/reactivar
esperar "Se reactiva el producto" 200 '"activo":true'

pedir GET /api/tienda/productos/115
esperar "El producto reactivado vuelve a la tienda" 200 '"Cama acolchada mediana"'

pedir POST /api/inventario/productos/999999/reactivar
esperar "Reactivar un producto que no existe da 404" 404

cerrar_sesion
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/inventario/productos/115/reactivar
esperar "Un cliente no puede reactivar productos (403)" 403
pedir POST /api/inventario/insumos/108/pedido
esperar "Un cliente no puede marcar insumos (403)" 403
cerrar_sesion
