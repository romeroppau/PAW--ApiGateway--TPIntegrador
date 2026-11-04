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
