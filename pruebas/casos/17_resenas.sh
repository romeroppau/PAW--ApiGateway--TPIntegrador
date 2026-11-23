# shellcheck shell=bash
# Reseñas (Backend, a través del Gateway). Usa las reseñas de la semilla 011 (ids 101 a 105).
# Contrato: docs/api/contrato-resenas.md del repo Backend.

# --- Las ve cualquiera (también corre contra producción, solo lectura) ---
cerrar_sesion
pedir GET /api/resenas
esperar "Las reseñas se ven sin sesión" 200 '"resumen":{"total":'
esperar "  de a 3" 200 '"por_pagina":3'
pedir GET '/api/resenas?orden=cualquiera'
esperar "Un orden inválido da 400" 400 '"orden"'
pedir POST /api/resenas '{"estrellas":5,"texto":"Sin sesión"}'
esperar "Sin sesión no se escribe una reseña (401)" 401

es_entorno_de_prueba || return 0

pedir GET /api/resenas
esperar "La más nueva primero (la 105, de ayer)" 200 '"datos":[{"id":105,'
esperar "  con el autor como nombre e inicial" 200 '"autor":"Valeria R."'
pedir GET '/api/resenas?orden=peores'
esperar "Calificación más baja primero (la de 3 estrellas)" 200 '"datos":[{"id":104,"estrellas":3'
pedir GET '/api/resenas?estrellas=4'
esperar "Solo las de 4 estrellas" 200 '"datos":[{"id":102,"estrellas":4'
pedir GET '/api/resenas?minimo=4&pagina=2'
esperar "Con mínimo 4, la página 2 tiene la más vieja (101) y su respuesta" 200 '"respuesta":{"texto":"¡Gracias por tu reseña, Lucía!'

# --- Escribir y borrar (cliente 102) ---
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/resenas '{"estrellas":0,"texto":""}'
esperar "Datos inválidos: un mensaje por campo (400)" 400 '"estrellas":"Elegí de 1 a 5 estrellas"'
CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir POST /api/resenas '{"estrellas":5,"texto":"Sin token"}'
esperar "Sin el token CSRF no se escribe (403)" 403
CSRF=$CSRF_REAL
pedir POST /api/resenas '{"estrellas":4,"texto":"Reseña de las pruebas de integración."}'
esperar "El cliente escribe una reseña y se publica enseguida" 201 '"estrellas":4'
esperar "  marcada como suya" 201 '"propia":true'
NUEVA=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
pedir GET /api/resenas
esperar "  y aparece primera" 200 "\"datos\":[{\"id\":$NUEVA,"
cerrar_sesion

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/notificaciones
esperar "A la veterinaria le llega el aviso de la reseña nueva" 200 'Nueva reseña de Sofía B. (4 estrellas)'
pedir POST /api/resenas '{"estrellas":5,"texto":"Soy la veterinaria"}'
esperar "La veterinaria no escribe reseñas (403)" 403
pedir PUT "/api/resenas/$NUEVA/respuesta" '{"texto":""}'
esperar "Una respuesta vacía da 400" 400 '"texto":"Escribí la respuesta"'
pedir PUT "/api/resenas/$NUEVA/respuesta" '{"texto":"¡Gracias por tu opinión!"}'
esperar "La veterinaria la responde" 200 '"respuesta":{"texto":"¡Gracias por tu opinión!"'
pedir PUT /api/resenas/999999/respuesta '{"texto":"Hola"}'
esperar "Responder una que no existe da 404" 404
pedir DELETE "/api/resenas/$NUEVA"
esperar "La veterinaria no puede borrarla (403)" 403
cerrar_sesion

iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir DELETE "/api/resenas/$NUEVA"
esperar "Otro cliente no la puede borrar (404)" 404
cerrar_sesion

iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST /api/resenas '{"estrellas":5,"texto":"El rescatista también escribe."}'
esperar "El rescatista también escribe reseñas" 201 '"autor":"Paula H."'
DEL_RESCATISTA=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
pedir DELETE "/api/resenas/$DEL_RESCATISTA"
esperar "  y la borra" 204
cerrar_sesion

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir DELETE "/api/resenas/$NUEVA"
esperar "El autor borra su reseña (con la respuesta)" 204
pedir GET /api/resenas
if printf '%s' "$RESPUESTA" | grep -q "\"id\":$NUEVA,"; then echo "  FALLA  la reseña borrada sigue en la lista"; FALLAS=$((FALLAS + 1)); else echo "  ok     Ya no aparece"; fi
TOTAL=$((TOTAL + 1))
cerrar_sesion
