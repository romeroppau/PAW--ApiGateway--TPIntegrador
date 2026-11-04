# shellcheck shell=bash
# Casos de sesión y roles (necesitan las cuentas de los datos semilla).
es_entorno_de_prueba || return 0

# --- Catálogo (público): búsqueda, filtros y paginado, con los productos de las semillas ---
pedir GET '/api/tienda/productos?buscar=cachorro'
esperar "La búsqueda encuentra productos por nombre" 200 '"Alimento cachorro 3 kg"'

pedir GET '/api/tienda/productos?categoria=MEDICAMENTO'
esperar "El filtro por categoría trae medicamentos" 200 '"categoria":"MEDICAMENTO"'

pedir GET '/api/tienda/productos?especie=GATO'
esperar "El filtro por especie trae productos para gatos" 200 '"especie":"GATO"'

pedir GET '/api/tienda/productos?pagina=2'
esperar "El paginado devuelve la página 2" 200 '"pagina":2'

# --- Registro ---
pedir POST /api/auth/registro/cliente '{"nombre":"A","email":"no-es-un-mail","password":"corta","telefono":"123"}'
esperar "Un registro con datos inválidos da 400 con el detalle por campo" 400 '"campos"'

pedir POST /api/auth/registro/cliente '{"nombre":"Cliente Repetido","email":"cliente@prueba.huellavet","password":"Otra-Clave-2026","telefono":"1155550199"}'
esperar "Registrarse con un email que ya existe da 409" 409

# --- Sesión y roles ---
pedir POST /api/auth/login '{"email":"vet@prueba.huellavet","password":"incorrecta123"}'
esperar "Login con contraseña incorrecta da 401" 401

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/auth/yo
esperar "El veterinario inicia sesión" 200 '"rol":"VETERINARIO"'

pedir GET /api/inventario/productos
esperar "El veterinario ve el panel de productos" 200 '"datos"'

CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir POST /api/inventario/productos '{"nombre":"Sin CSRF"}'
esperar "Un POST sin el token CSRF correcto da 403" 403
CSRF=$CSRF_REAL

pedir POST /api/inventario/productos '{"nombre":"Producto de humo","categoria":"ACCESORIO","especie":"TODAS","precio":100,"stock":1}'
esperar "Con el token CSRF correcto, el veterinario crea un producto" 201 '"Producto de humo"'

cerrar_sesion
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/inventario/productos
esperar "Un cliente no puede usar el panel del veterinario (403)" 403
