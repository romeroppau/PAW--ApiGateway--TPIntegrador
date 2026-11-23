# shellcheck shell=bash
# Mis datos (cada usuario, su cuenta) y Clientes (la veterinaria): Backend, a través del Gateway.
# Registra una cuenta nueva para cambiarle los datos y la contraseña, así no toca las cuentas de
# prueba que usan los demás casos. Solo en entornos de prueba (no llena dev de cuentas).
es_entorno_de_prueba || return 0

EMAIL_NUEVO="mis-datos-$(date +%s)-$RANDOM@prueba.huellavet"
# Teléfono distinto en cada corrida: la verificación del WhatsApp limita los códigos por número.
TEL_MD="11555$(printf '%05d' $((RANDOM % 100000)))"

# --- Mis datos: sin sesión ---
pedir GET /api/cuenta
esperar "Mis datos piden sesión (401)" 401

# --- Una cuenta nueva de cliente (con el código del WhatsApp: en local y en el CI la respuesta lo trae) ---
pedir POST /api/auth/registro/codigo "{\"telefono\":\"$TEL_MD\"}"
COD_MD=$(printf '%s' "$RESPUESTA" | grep -o '"codigo":"[0-9]*"' | cut -d'"' -f4)
pedir POST /api/auth/registro/cliente "{\"nombre\":\"Cuenta Mis Datos\",\"email\":\"$EMAIL_NUEVO\",\"password\":\"Clave-Vieja-2026\",\"telefono\":\"$TEL_MD\",\"codigo\":\"$COD_MD\"}"
esperar "Se registra una cuenta para probar Mis datos" 201
iniciar_sesion "$EMAIL_NUEVO" 'Clave-Vieja-2026'

pedir GET /api/cuenta
esperar "Mis datos muestra el nombre, el email y el teléfono" 200 '"nombre":"Cuenta Mis Datos","email":"'"$EMAIL_NUEVO"'","telefono":"'"$TEL_MD"'","rol":"CLIENTE"'

CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir PUT /api/cuenta '{"nombre":"Otro Nombre","telefono":"1155550101"}'
esperar "Cambiar los datos sin el token CSRF da 403" 403
CSRF=$CSRF_REAL

pedir PUT /api/cuenta '{"nombre":"Cuenta Cambiada","telefono":"+54 9 11 5555-0102","email":"otro@prueba.huellavet"}'
esperar "Cambia el nombre; el email y el teléfono no (el teléfono, solo verificándolo por WhatsApp)" 200 '"nombre":"Cuenta Cambiada","email":"'"$EMAIL_NUEVO"'","telefono":"'"$TEL_MD"'"'
pedir GET /api/auth/yo
esperar "  el nombre nuevo se ve enseguida en la sesión" 200 '"nombre":"Cuenta Cambiada"'
pedir PUT /api/cuenta '{"nombre":"A","telefono":""}'
esperar "Datos inválidos: un mensaje por campo (400)" 400 '"nombre":"El nombre debe tener entre 2 y 100 caracteres"'

# --- Cambiar la contraseña ---
pedir PUT /api/cuenta/contrasena '{"actual":"no-es-la-mia","nueva":"Clave-Nueva-2026","repetir":"Clave-Nueva-2026"}'
esperar "Con la contraseña actual equivocada no se cambia (400, sin cerrar la sesión)" 400 '"actual":"La contraseña actual no es correcta"'
pedir PUT /api/cuenta/contrasena '{"actual":"Clave-Vieja-2026","nueva":"Clave-Nueva-2026","repetir":"Otra-Distinta-2026"}'
esperar "Las dos nuevas tienen que coincidir (400)" 400 '"repetir"'
pedir PUT /api/cuenta/contrasena '{"actual":"Clave-Vieja-2026","nueva":"Clave-Nueva-2026","repetir":"Clave-Nueva-2026"}'
esperar "Cambia la contraseña" 200 '"mensaje":"Tu contraseña se cambió"'
pedir GET /api/cuenta
esperar "  la sesión sigue abierta" 200 '"nombre":"Cuenta Cambiada"'
cerrar_sesion
pedir POST /api/auth/login "{\"email\":\"$EMAIL_NUEVO\",\"password\":\"Clave-Vieja-2026\"}"
esperar "Con la contraseña vieja ya no se entra (401)" 401
pedir POST /api/auth/login "{\"email\":\"$EMAIL_NUEVO\",\"password\":\"Clave-Nueva-2026\"}"
esperar "Con la nueva sí" 200 '"nombre":"Cuenta Cambiada"'

# --- El rescatista también cambia su organización; la veterinaria no cambia el teléfono con "Guardar" ---
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/cuenta
ORIGINAL=$(printf '%s' "$RESPUESTA")
NOMBRE_R=$(printf '%s' "$ORIGINAL" | grep -o '"nombre":"[^"]*"' | cut -d'"' -f4)
TEL_R=$(printf '%s' "$ORIGINAL" | grep -o '"telefono":"[^"]*"' | cut -d'"' -f4)
ORG_R=$(printf '%s' "$ORIGINAL" | grep -o '"organizacion":"[^"]*"' | cut -d'"' -f4)
pedir PUT /api/cuenta "{\"nombre\":\"$NOMBRE_R\",\"telefono\":\"$TEL_R\",\"organizacion\":\"Organización de prueba\"}"
esperar "El rescatista cambia su organización" 200 '"organizacion":"Organización de prueba"'
pedir PUT /api/cuenta "{\"nombre\":\"$NOMBRE_R\",\"telefono\":\"$TEL_R\",\"organizacion\":\"$ORG_R\"}"
cerrar_sesion
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/cuenta
NOMBRE_V=$(printf '%s' "$RESPUESTA" | grep -o '"nombre":"[^"]*"' | cut -d'"' -f4)
TEL_V=$(printf '%s' "$RESPUESTA" | grep -o '"telefono":"[^"]*"' | cut -d'"' -f4)
pedir PUT /api/cuenta "{\"nombre\":\"$NOMBRE_V\",\"telefono\":\"\"}"
esperar "La veterinaria tampoco cambia el teléfono con Guardar" 200 "\"telefono\":$([ -n "$TEL_V" ] && echo "\"$TEL_V\"" || echo null),\"rol\":\"VETERINARIO\""

# --- Clientes (veterinaria) ---
pedir GET /api/clientes
esperar "La veterinaria ve la lista de clientes, de a 20" 200 '"por_pagina":20'
esperar "  con nombre, email y teléfono" 200 '"email":"cliente@prueba.huellavet"'
pedir GET '/api/clientes?buscar=cliente2'
esperar "Busca por email" 200 '"email":"cliente2@prueba.huellavet"'
pedir GET '/api/clientes?buscar=%25'
esperar "Un % se busca como letra, no trae todo" 200 '"datos":[]'
pedir GET '/api/clientes?pagina=0'
esperar "Una página 0 da 400" 400 '"pagina"'
pedir GET /api/clientes/102
esperar "La ficha de un cliente" 200 '"id":102'
pedir GET /api/clientes/104
esperar "La ficha de un rescatista (también tiene mascotas)" 200 '"rol":"RESCATISTA"'
pedir GET /api/clientes/101
esperar "La de una veterinaria no es una ficha de cliente (404)" 404 '"Cliente no encontrado"'
pedir GET /api/clientes/999999
esperar "Un id que no existe da 404" 404
cerrar_sesion

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/clientes
esperar "Un cliente no ve la lista de clientes (403)" 403
pedir GET /api/clientes/103
esperar "  ni la ficha de otro (403)" 403
cerrar_sesion
