# shellcheck shell=bash
# Casos de notificaciones (rol 1). Contrato: docs/api/contrato-notificaciones.md del repo Backend.
# La lógica interna (idempotencia, 400, 401, 404) la prueban las PHPUnit de Backend.

# --- Sin sesión (también corre contra producción, solo lectura) ---
cerrar_sesion
pedir GET /api/notificaciones
esperar "Sin sesión no se ven las notificaciones (401)" 401
pedir POST /api/notificaciones/1/leida
esperar "Sin sesión no se marca una notificación (401)" 401

# /internal/ es de proceso a proceso: desde afuera tiene que estar bloqueado.
pedir POST /internal/notificaciones '{"usuario_id":1,"tipo":"VACUNA","canal":"WEB","mensaje":"x","fecha_programada":"2026-01-01 10:00:00","id_operacion":"humo-afuera"}'
esperar "El aviso interno no se puede llamar desde afuera (404)" 404

CODIGO=$(curl --silent --max-time 60 -o /dev/null -w '%{http_code}' -X POST \
  -H 'X-Servicio-Token: cualquiera' -H 'Content-Type: application/json' --data '{}' \
  "$BASE_URL/internal/notificaciones")
RESPUESTA=""
esperar "Con un X-Servicio-Token inventado también da 404" 404

es_entorno_de_prueba || return 0

# --- Ver y marcar como leída (el aviso 901 lo deja la semilla 008) ---
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/notificaciones
esperar "El cliente ve sus notificaciones" 200 '"no_leidas":'
esperar "Con el aviso de la semilla" 200 'Aviso de prueba'

pedir POST /api/notificaciones/abc/leida
esperar "Un id que no es un número da 404" 404
pedir POST /api/notificaciones/999999/leida
esperar "Un aviso que no existe da 404" 404

CSRF_CLIENTE=$CSRF
CSRF=""
pedir POST /api/notificaciones/901/leida
esperar "Sin el token CSRF no se marca (403)" 403
CSRF=$CSRF_CLIENTE

iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/notificaciones/901/leida
esperar "Un aviso de otro usuario da 404 (no se revela que existe)" 404

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST /api/notificaciones/901/leida
esperar "El cliente marca su aviso como leído" 200 '"leida":true'
pedir POST /api/notificaciones/901/leida
esperar "Marcarlo de nuevo también da 200" 200

cerrar_sesion