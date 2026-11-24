# shellcheck shell=bash
# Casos del circuito de adopción (rol 3). Contrato: docs/api/contrato-adopciones.md del repo
# Adopciones. Datos: base/semillas/README.md, sección "Adopciones" (rescatista@ aprobada,
# rescatista2@ pendiente). Volver a sembrar deja todo como al principio: en dev, el circuito
# completo (Pipa pasa al cliente 103) solo se puede repetir después de sembrar de nuevo.

# Foto de prueba (PNG de 1 x 1), la misma de las semillas.
PNG_PRUEBA='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='

# primer_id: el primer "id" numérico de la última respuesta (el del objeto principal).
primer_id() { printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

# --- Validación de rescatistas (Backend) ---
cerrar_sesion
pedir GET /api/rescatistas
esperar "Sin sesión no se ven los rescatistas (401)" 401

# La transferencia de la mascota al adoptante es de proceso a proceso (Adopciones -> Pacientes):
# desde afuera tiene que estar bloqueada, también con un token inventado.
CODIGO=$(curl --silent --max-time 60 -o /dev/null -w '%{http_code}' -X POST \
  -H 'X-Servicio-Token: cualquiera' -H 'Content-Type: application/json' \
  --data '{"duenio_actual_id":104,"nuevo_duenio_id":103}' "$BASE_URL/internal/mascotas/902/transferir")
RESPUESTA=""
esperar "La transferencia de la mascota no se puede llamar desde afuera (404)" 404

pedir GET /api/adopciones/publicaciones
esperar "Cualquiera ve los animales disponibles" 200 '"publicaciones":'
pedir GET '/api/adopciones/publicaciones?especie=PEZ'
esperar "Una especie que no existe da 400" 400
pedir GET /api/adopciones/moderacion
esperar "Sin sesión no se ve la moderación (401)" 401

es_entorno_de_prueba || return 0

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/rescatistas
esperar "Un cliente no ve los rescatistas (403)" 403
pedir POST /api/rescatistas/105/aprobar
esperar "Un cliente no aprueba rescatistas (403)" 403

# La sesión de la rescatista pendiente se guarda: después de aprobarla, la misma sesión ya dice APROBADO.
iniciar_sesion rescatista2@prueba.huellavet 'Rescatista-Prueba-2026'
SESION_RESCATISTA2=$SESION
CSRF_RESCATISTA2=$CSRF
pedir GET /api/auth/yo
esperar "La rescatista pendiente ve su estado en la sesión" 200 '"estado_validacion":"PENDIENTE"'
pedir POST /api/rescatistas/105/aprobar
esperar "Una rescatista no se aprueba a sí misma (403)" 403
pedir POST /api/adopciones/publicaciones "{\"mascota_id\":901,\"titulo\":\"Canela\",\"descripcion\":\"Una perra muy buena\",\"foto\":\"$PNG_PRUEBA\"}"
esperar "Una rescatista pendiente no puede publicar (403)" 403 'todavía no fue aprobada'

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/rescatistas
esperar "La veterinaria ve las rescatistas pendientes" 200 '"email":"rescatista2@prueba.huellavet"'
pedir GET '/api/rescatistas?estado=APROBADO'
esperar "Y, filtrando, las aprobadas" 200 '"email":"rescatista@prueba.huellavet"'
pedir GET '/api/rescatistas?estado=OTRO'
esperar "Un estado que no existe da 400" 400

CSRF_VET=$CSRF
CSRF=""
pedir POST /api/rescatistas/105/aprobar
esperar "Sin el token CSRF no se aprueba (403)" 403
CSRF=$CSRF_VET

pedir POST /api/rescatistas/102/aprobar
esperar "Un cliente no es un rescatista (404)" 404
pedir POST /api/rescatistas/abc/aprobar
esperar "Un id que no es un número da 404" 404
pedir POST /api/rescatistas/104/rechazar
esperar "Una rescatista ya aprobada no se rechaza (409)" 409 'ya fue aprobado'

pedir POST /api/rescatistas/105/aprobar
esperar "La veterinaria aprueba a la rescatista pendiente" 200 '"estado_validacion":"APROBADO"'
pedir POST /api/rescatistas/105/rechazar
esperar "La decisión es una sola: después no se rechaza (409)" 409

SESION=$SESION_RESCATISTA2
CSRF=$CSRF_RESCATISTA2
pedir GET /api/auth/yo
esperar "La rescatista ve que la aprobaron sin volver a iniciar sesión" 200 '"estado_validacion":"APROBADO"'
pedir GET /api/notificaciones
esperar "Y le llega el aviso de su cuenta aprobada" 200 'cuenta de rescatista fue aprobada'

# --- Mascotas a cargo de la rescatista (Pacientes) ---
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/pacientes/mascotas
esperar "La rescatista ve las mascotas que tiene a cargo" 200 '"nombre":"Canela"'
pedir GET /api/pacientes/mascotas/101
esperar "La mascota de un cliente le da 404" 404

pedir POST /api/pacientes/mascotas '{"nombre":"Rescatado de humo","especie":"GATO"}'
esperar "La rescatista carga un animal rescatado" 201 '"duenio":{"id":104'
MASCOTA_RESCATADA=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
pedir PUT "/api/pacientes/mascotas/${MASCOTA_RESCATADA:-0}" '{"nombre":"Rescatado de humo","especie":"GATO","peso_kg":3.5}'
esperar "La rescatista edita la mascota que cargó" 200 '"peso_kg":"3.50"'

pedir GET /api/pacientes/mascotas/902/historial
esperar "El historial clínico no es para la rescatista (403)" 403
pedir GET /api/pacientes/turnos
esperar "Los turnos tampoco (403)" 403

pedir DELETE "/api/pacientes/mascotas/${MASCOTA_RESCATADA:-0}"
esperar "La rescatista da de baja la mascota que cargó" 204

iniciar_sesion rescatista2@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/pacientes/mascotas/902
esperar "Otra rescatista no ve las mascotas de la primera (404)" 404
pedir GET /api/adopciones/101/postulaciones
esperar "Ni los postulantes de sus adopciones (404)" 404

# --- Publicar (Adopciones) ---
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
CANELA="{\"mascota_id\":901,\"titulo\":\"Canela busca familia\",\"descripcion\":\"Perra de un a\u00f1o, mansa y juguetona.\",\"foto\":\"$PNG_PRUEBA\"}"
pedir POST /api/adopciones/publicaciones "$CANELA"
esperar "La rescatista publica a Canela" 201 '"estado_moderacion":"PENDIENTE"'
PUBLICACION_CANELA=$(primer_id)
pedir POST /api/adopciones/publicaciones "$CANELA"
esperar "Canela no se publica dos veces (409)" 409 'ya tiene una publicación abierta'
pedir POST /api/adopciones/publicaciones "{\"mascota_id\":101,\"titulo\":\"Firulais\",\"descripcion\":\"No es de la rescatista\",\"foto\":\"$PNG_PRUEBA\"}"
esperar "No publica una mascota que no tiene a cargo (400)" 400 '"mascota_id"'
pedir POST /api/adopciones/publicaciones '{"mascota_id":901,"titulo":"Canela","descripcion":"Una perra muy buena","foto":"data:image/png;base64,AAAA"}'
esperar "Una foto que no es una imagen da 400" 400 '"foto"'
pedir GET /api/adopciones/mis-publicaciones
esperar "La rescatista ve sus publicaciones" 200 '"titulo":"Canela busca familia"'
pedir GET /api/adopciones/moderacion
esperar "La rescatista no modera (403)" 403

cerrar_sesion
pedir GET "/api/adopciones/publicaciones/${PUBLICACION_CANELA:-0}"
esperar "Una publicación sin aprobar no es pública (404)" 404
pedir GET /api/adopciones/publicaciones/101/foto
esperar "La foto de una publicación disponible es pública" 200

# --- Moderar (veterinaria) ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/adopciones/moderacion
esperar "La veterinaria ve las publicaciones por moderar" 200 '"titulo":"Canela busca familia"'
pedir GET /api/notificaciones
esperar "Y le llegó el aviso de la publicación nueva" 200 'publicó a Canela para adopción'
pedir POST /api/adopciones/publicaciones/102/rechazar '{"motivo":""}'
esperar "Rechazar sin motivo da 400" 400 '"motivo"'
pedir POST /api/adopciones/publicaciones/102/rechazar '{"motivo":"La foto no se ve bien"}'
esperar "La veterinaria rechaza la publicación de Rocco" 200 '"motivo_rechazo":"La foto no se ve bien"'
pedir POST "/api/adopciones/publicaciones/${PUBLICACION_CANELA:-0}/aprobar"
esperar "La veterinaria aprueba la de Canela: se abre la adopción" 200 '"estado":"PUBLICADA"'
ADOPCION_CANELA=$(printf '%s' "$RESPUESTA" | grep -o '"adopcion":{"id":[0-9]*' | grep -o '[0-9]*$')
pedir POST "/api/adopciones/publicaciones/${PUBLICACION_CANELA:-0}/aprobar"
esperar "La moderación es una sola (409)" 409

cerrar_sesion
pedir GET /api/adopciones/publicaciones
esperar "Canela ya aparece entre los disponibles" 200 '"nombre":"Canela"'
pedir GET '/api/adopciones/publicaciones?especie=GATO'
esperar "Filtrando por gatos aparece Pipa" 200 '"nombre":"Pipa"'
pedir GET /api/adopciones/publicaciones/102
esperar "Rocco, rechazado, no es público (404)" 404

# --- Postularse (cliente) ---
POSTULACION='{"tipo_vivienda":"Departamento","otras_mascotas":"Ninguna","tiempo_disponible":"Toda la tarde"}'
pedir POST /api/adopciones/101/postulaciones "$POSTULACION"
esperar "Sin sesión no se postula (401)" 401
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/adopciones/101/postulaciones '{"tipo_vivienda":"","otras_mascotas":"Ninguna","tiempo_disponible":"Toda la tarde"}'
esperar "Una postulación incompleta da 400" 400 '"tipo_vivienda"'
pedir POST /api/adopciones/101/postulaciones "$POSTULACION"
esperar "El cliente 103 se postula a Pipa" 201 '"estado":"PENDIENTE"'
POSTULACION_CLIENTE2=$(primer_id)
pedir POST /api/adopciones/101/postulaciones "$POSTULACION"
esperar "No se postula dos veces (409)" 409 'Ya te postulaste'
pedir GET /api/adopciones/mis-postulaciones
esperar "El cliente ve sus postulaciones" 200 '"titulo":"Pipa busca familia"'
pedir POST /api/adopciones/101/completar
esperar "Un cliente no completa adopciones (403)" 403

# --- Elegir al adoptante (rescatista) ---
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/notificaciones
esperar "A la rescatista le llega el aviso de la postulación" 200 'Cliente Dos se postuló para adoptar a Pipa'
esperar "Y el de la publicación aprobada" 200 'Aprobamos la publicación de Canela'
esperar "Y el de la rechazada, con el motivo" 200 'No aprobamos la publicación de Rocco. Motivo: La foto no se ve bien'
pedir GET /api/adopciones/101/postulaciones
esperar "La rescatista ve los postulantes de Pipa, sin su teléfono" 200 '"telefono":null'
pedir POST /api/adopciones/101/elegir '{}'
esperar "Elegir sin postulación da 400" 400
pedir POST /api/adopciones/101/elegir "{\"postulacion_id\":${POSTULACION_CLIENTE2:-0}}"
esperar "La rescatista elige al cliente 103" 200 '"estado":"ADOPTANTE_ELEGIDO"'
esperar "Y la otra postulación queda rechazada" 200 '"estado":"RECHAZADA"'
pedir POST /api/adopciones/101/elegir "{\"postulacion_id\":${POSTULACION_CLIENTE2:-0}}"
esperar "No se elige dos veces (409)" 409

# Pipa ya no está disponible, pero quien se postuló la sigue viendo (desde "Mis postulaciones").
cerrar_sesion
pedir GET /api/adopciones/publicaciones/101
esperar "Sin sesión, una publicación que ya no está disponible da 404" 404
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/adopciones/publicaciones/101
esperar "El cliente elegido sigue viendo la publicación" 200 '"titulo":"Pipa busca familia"'
pedir GET /api/adopciones/publicaciones/101/foto
esperar "  y su foto" 200
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/adopciones/publicaciones/101
esperar "El que no fue elegido también (se postuló)" 200 '"titulo":"Pipa busca familia"'

# --- Chequeo y cierre (veterinaria) ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir POST /api/adopciones/101/completar
esperar "Sin chequeo no se completa (409)" 409
pedir POST /api/adopciones/101/chequeo '{"turno_id":101}'
esperar "Un turno que no es de chequeo no sirve (400)" 400 'no es un chequeo de adopción'

# El chequeo es un turno común de hoy. Se prueba con varios horarios: en dev, las corridas
# anteriores pueden haber ocupado alguno.
HOY=$(date -u -d '3 hours ago' +%F)
for HORA in 19:50 19:40 19:30 19:20 19:10 19:00 18:50 18:40 18:30 18:20; do
  pedir POST /api/pacientes/turnos "{\"mascota_id\":902,\"fecha\":\"$HOY\",\"hora\":\"$HORA\",\"motivo\":\"CHEQUEO_ADOPCION\"}"
  [ "$CODIGO" = 201 ] && break
done
esperar "La veterinaria carga el turno de chequeo de Pipa" 201 '"CHEQUEO_ADOPCION"'
TURNO_CHEQUEO=$(primer_id)

pedir POST /api/adopciones/101/chequeo "{\"turno_id\":${TURNO_CHEQUEO:-0}}"
esperar "Y lo asocia a la adopción" 200 '"estado":"CHEQUEO_PENDIENTE"'
pedir POST /api/adopciones/101/completar
esperar "Con el chequeo sin atender no se completa (409)" 409 'todavía no se atendió'

pedir POST "/api/pacientes/turnos/${TURNO_CHEQUEO:-0}/atencion"
esperar "La veterinaria atiende el chequeo" 201
CONSULTA_CHEQUEO=$(primer_id)
pedir PUT "/api/pacientes/consultas/${CONSULTA_CHEQUEO:-0}" '{"diagnostico":"Chequeo de adopci\u00f3n: sana y lista para su familia"}'
esperar "Carga el diagnóstico" 200
pedir POST "/api/pacientes/consultas/${CONSULTA_CHEQUEO:-0}/finalizar"
esperar "Y termina la consulta" 200

pedir POST /api/adopciones/101/completar
esperar "La veterinaria completa la adopción" 200 '"estado":"FINALIZADA"'
pedir POST /api/adopciones/101/completar
esperar "No se completa dos veces (409)" 409
pedir GET '/api/adopciones?estado=FINALIZADA'
esperar "La adopción aparece entre las finalizadas" 200 '"nombre":"Pipa"'

# Listado paginado con filtros y detalle de una adopción.
pedir GET '/api/adopciones?estado=FINALIZADA&buscar=Pipa&desde=2000-01-01&hasta=2099-12-31&por_pagina=5'
esperar "Se filtra por nombre y por fechas" 200 '"nombre":"Pipa"'
esperar "Y dice el total y la página" 200 '"pagina":1,"por_pagina":5'
pedir GET '/api/adopciones?estado=FINALIZADA&buscar=NoExisteNinguna'
esperar "Una búsqueda sin resultados da la lista vacía" 200 '"adopciones":[],"total":0'
pedir GET '/api/adopciones?desde=2026-02-30'
esperar "Una fecha que no existe da 400" 400 '"desde"'
pedir GET '/api/adopciones?desde=2026-11-19&hasta=2026-11-01'
esperar "Hasta antes que desde da 400" 400 '"hasta"'
pedir GET '/api/adopciones?por_pagina=101'
esperar "Más de 100 por página da 400" 400 '"por_pagina"'
pedir GET '/api/adopciones?orden=prioridad'
esperar "Se ordena por prioridad" 200 '"adopciones":['
pedir GET '/api/adopciones?estado=FINALIZADA&orden=antiguas'
esperar "O de la más antigua a la más nueva" 200 '"nombre":"Pipa"'
pedir GET '/api/adopciones?orden=cualquiera'
esperar "Un orden que no existe da 400" 400 '"orden"'
pedir GET /api/adopciones/101/detalle
esperar "La veterinaria ve el detalle de la adopción" 200 '"postulaciones":['
esperar "Con la consulta del chequeo" 200 "\"consulta_id\":${CONSULTA_CHEQUEO:-0}"
esperar "Y el email del adoptante" 200 '"email":"cliente2@prueba.huellavet"'
pedir GET /api/adopciones/999999/detalle
esperar "Una adopción que no existe da 404" 404

# Pipa ahora es del adoptante, con su historial.
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/adopciones/101/detalle
esperar "Un cliente no ve el detalle de una adopción (403)" 403
pedir GET /api/pacientes/mascotas/902
esperar "Pipa pasó a ser del cliente 103" 200 '"nombre":"Pipa"'
pedir GET /api/pacientes/mascotas/902/historial
esperar "Con el chequeo en su historial" 200 'Chequeo de adopción'
pedir GET /api/notificaciones
esperar "Al adoptante le llegó el aviso de que lo eligieron" 200 'Te eligieron para adoptar a Pipa'
esperar "Y el del turno del chequeo" 200 'Tenés turno para el chequeo de adopción de Pipa'
esperar "Y el de la adopción completa" 200 'La adopción de Pipa está completa'
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/pacientes/mascotas/902
esperar "La rescatista ya no tiene a Pipa (404)" 404
pedir GET /api/adopciones/101/detalle
esperar "Pero ve el detalle de su adopción" 200 '"estado":"FINALIZADA"'
pedir GET /api/notificaciones
esperar "A la rescatista le llegó el aviso del turno del chequeo" 200 'tiene turno para el chequeo de adopción de Pipa'

# --- Cancelar ---
pedir POST "/api/adopciones/${ADOPCION_CANELA:-0}/cancelar"
esperar "La rescatista cancela la adopción de Canela" 200 '"estado":"CANCELADA"'
pedir POST "/api/adopciones/${ADOPCION_CANELA:-0}/cancelar"
esperar "Una adopción terminada no se cancela (409)" 409
pedir GET /api/pacientes/mascotas/901
esperar "Canela sigue a cargo de la rescatista" 200 '"nombre":"Canela"'

# --- Editar y dar de baja publicaciones ---
pedir PUT /api/adopciones/publicaciones/102 '{"titulo":"ab"}'
esperar "Editar con un título muy corto da 400" 400 '"titulo"'
pedir PUT /api/adopciones/publicaciones/102 "{\"descripcion\":\"Perro de 2 a\u00f1os, tranquilo. Ahora con una foto mejor.\",\"foto\":\"$PNG_PRUEBA\"}"
esperar "La rescatista edita la publicación rechazada de Rocco: vuelve a revisión" 200 '"estado_moderacion":"PENDIENTE"'
esperar "Y se borra el motivo del rechazo" 200 '"motivo_rechazo":null'
pedir PUT "/api/adopciones/publicaciones/${PUBLICACION_CANELA:-0}" '{"titulo":"Canela"}'
esperar "Una publicación cerrada no se edita (409)" 409

pedir POST /api/adopciones/publicaciones "$CANELA"
esperar "Canela se puede volver a publicar después de cancelar" 201
PUBLICACION_CANELA2=$(primer_id)

iniciar_sesion rescatista2@prueba.huellavet 'Rescatista-Prueba-2026'
pedir PUT /api/adopciones/publicaciones/102 '{"titulo":"Rocco"}'
esperar "Otra rescatista no edita la publicación (404)" 404
pedir DELETE /api/adopciones/publicaciones/102
esperar "Ni la da de baja (404)" 404

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir POST "/api/adopciones/publicaciones/${PUBLICACION_CANELA2:-0}/aprobar"
esperar "La veterinaria aprueba la nueva publicación de Canela" 200 '"estado":"PUBLICADA"'
ADOPCION_CANELA2=$(printf '%s' "$RESPUESTA" | grep -o '"adopcion":{"id":[0-9]*' | grep -o '[0-9]*$')
pedir DELETE /api/adopciones/publicaciones/102
esperar "La veterinaria no da de baja publicaciones (403)" 403

iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir DELETE "/api/adopciones/publicaciones/${PUBLICACION_CANELA2:-0}"
esperar "La rescatista da de baja la publicación de Canela" 204
pedir GET "/api/adopciones/${ADOPCION_CANELA2:-0}/postulaciones"
esperar "Y su adopción queda cancelada" 200 '"estado":"CANCELADA"'
pedir DELETE "/api/adopciones/publicaciones/${PUBLICACION_CANELA2:-0}"
esperar "No se da de baja dos veces (409)" 409
pedir DELETE /api/adopciones/publicaciones/102
esperar "La rescatista da de baja la de Rocco, que estaba en revisión" 204

cerrar_sesion
