# shellcheck shell=bash
# El cliente cancela su postulación (24/11): POST /api/adopciones/postulaciones/{id}/cancelar.
# Después puede volver a postularse (la misma postulación vuelve a PENDIENTE).
# Contrato: docs/api/contrato-adopciones.md de Adopciones ("Cancelar mi postulación"). Migración 021.
# Arma su propia adopción (una mascota nueva de la rescatista 104, publicada y aprobada), así no
# depende de lo que hizo 09_adopciones.sh con Pipa y Canela. Al final la da de baja.
es_entorno_de_prueba || return 0

PNG_CANCELAR='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
id_de_respuesta() { printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

# --- Una adopción nueva ---
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST /api/pacientes/mascotas '{"nombre":"Gato para cancelar","especie":"GATO"}'
esperar "La rescatista carga un gato para la prueba de cancelar" 201
MASCOTA_CANCELAR=$(id_de_respuesta)
pedir POST /api/adopciones/publicaciones "{\"mascota_id\":${MASCOTA_CANCELAR:-0},\"titulo\":\"Gato para cancelar\",\"descripcion\":\"Gato de la prueba de cancelar.\",\"foto\":\"$PNG_CANCELAR\"}"
esperar "  y lo publica" 201
PUBLICACION_CANCELAR=$(id_de_respuesta)

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir POST "/api/adopciones/publicaciones/${PUBLICACION_CANCELAR:-0}/aprobar"
esperar "  y la veterinaria la aprueba" 200 '"estado":"PUBLICADA"'
ADOPCION_CANCELAR=$(printf '%s' "$RESPUESTA" | grep -o '"adopcion":{"id":[0-9]*' | grep -o '[0-9]*$')

# --- Postularse y cancelar ---
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST "/api/adopciones/${ADOPCION_CANCELAR:-0}/postulaciones" '{"tipo_vivienda":"Casa","otras_mascotas":"Ninguna","tiempo_disponible":"Toda la tarde"}'
esperar "El cliente 103 se postula" 201 '"estado":"PENDIENTE"'
POSTULACION_CANCELAR=$(id_de_respuesta)

cerrar_sesion
pedir POST "/api/adopciones/postulaciones/${POSTULACION_CANCELAR:-0}/cancelar"
esperar "Sin sesión no se cancela (401)" 401
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST "/api/adopciones/postulaciones/${POSTULACION_CANCELAR:-0}/cancelar"
esperar "Otro cliente no cancela una postulación ajena (404)" 404
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir POST "/api/adopciones/postulaciones/${POSTULACION_CANCELAR:-0}/cancelar"
esperar "La rescatista no cancela postulaciones (403)" 403

iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST "/api/adopciones/postulaciones/${POSTULACION_CANCELAR:-0}/cancelar"
esperar "El cliente cancela su postulación pendiente" 200 '"estado":"CANCELADA"'
esperar "  y la adopción, sin otras pendientes, vuelve a publicada" 200 '"adopcion":{"id":'"${ADOPCION_CANCELAR:-0}"',"estado":"PUBLICADA"'
pedir POST "/api/adopciones/postulaciones/${POSTULACION_CANCELAR:-0}/cancelar"
esperar "No se cancela dos veces (409)" 409
pedir GET /api/adopciones/mis-postulaciones
esperar "En Mis postulaciones figura cancelada" 200 '"estado":"CANCELADA"'

# Puede volver a postularse (24/11): la misma postulación vuelve a PENDIENTE con los datos nuevos.
pedir POST "/api/adopciones/${ADOPCION_CANCELAR:-0}/postulaciones" '{"tipo_vivienda":"Departamento","otras_mascotas":"Un gato","tiempo_disponible":"Las tardes"}'
esperar "Después de cancelar, el cliente vuelve a postularse" 201 '"id":'"${POSTULACION_CANCELAR:-0}"',"estado":"PENDIENTE"'
esperar "  con los datos nuevos" 201 '"tipo_vivienda":"Departamento"'
esperar "  y la adopción vuelve a tener postulantes" 201 '"estado":"CON_POSTULANTES"'
pedir POST "/api/adopciones/${ADOPCION_CANCELAR:-0}/postulaciones" '{"tipo_vivienda":"Casa","otras_mascotas":"Ninguna","tiempo_disponible":"Toda la tarde"}'
esperar "Pero no dos veces seguidas (409)" 409 'Ya te postulaste'
pedir POST /api/adopciones/postulaciones/101/cancelar
esperar "Una postulación de otro cliente (la 101, de cliente@) da 404" 404

# --- La rescatista se entera ---
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/notificaciones
esperar "A la rescatista le llega el aviso de la cancelación" 200 'su postulación para adoptar a Gato para cancelar'
esperar "  y el de la nueva postulación" 200 'se postuló para adoptar a Gato para cancelar'
pedir GET "/api/adopciones/${ADOPCION_CANCELAR:-0}/postulaciones"
esperar "  y ve la postulación otra vez pendiente" 200 '"estado":"PENDIENTE"'
pedir DELETE "/api/adopciones/publicaciones/${PUBLICACION_CANCELAR:-0}"
esperar "Limpieza: la rescatista da de baja la publicación" 204
cerrar_sesion
