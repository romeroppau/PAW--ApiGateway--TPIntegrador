# shellcheck shell=bash
# Casos generales: salud de los módulos y respuestas de error.

pedir GET /api/gateway/salud
esperar "El Gateway responde" 200 '"funciona"'

pedir GET /api/backend/salud
esperar "Backend responde y llega a la base" 200 '"funciona"'

pedir GET /api/inventario/salud
esperar "Inventario responde y llega a la base" 200 '"funciona"'

pedir GET /api/tienda/productos/999999
esperar "Un producto inexistente da 404 en JSON" 404 '"error"'

pedir GET /api/inventario/productos
esperar "El panel del veterinario sin sesión da 401" 401

# Las cabeceras no tienen que mostrar la versión de nginx ni de PHP.
CABECERAS=$(curl --silent --max-time 60 -D - -o /dev/null "$BASE_URL/api/gateway/salud" | tr -d '\r')
CODIGO=200
RESPUESTA="sin versión"
if printf '%s' "$CABECERAS" | grep -qiE '^server: nginx/|^x-powered-by:'; then
  RESPUESTA=$(printf '%s' "$CABECERAS" | grep -iE '^server:|^x-powered-by:' | tr '\n' ' ')
fi
esperar "Las cabeceras no muestran la versión de nginx ni de PHP" 200 "sin versión"
