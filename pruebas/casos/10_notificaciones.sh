# shellcheck shell=bash
# Casos de notificaciones (rol 1). Contrato: docs/api/contrato-notificaciones.md del repo
# Backend. Los avisos de prueba usan un id_operacion con sufijo único por corrida, así el caso
# se puede repetir en dev sin chocar con los de la corrida anterior.

# --- Sin sesión (también corre contra producción, solo lectura) ---
cerrar_sesion
pedir GET /api/notificaciones
esperar "Sin sesión no se ven las notificaciones (401)" 401
pedir POST /api/notificaciones/1/leida
esperar "Sin sesión no se marca una notificación (401)" 401

# /internal/ es de proceso a proceso: desde afuera tiene que estar bloqueado,
# también con un token inventado.
CODIGO=$(curl --silent --max-time 60 -o /dev/null -w '%{http_code}' -X POST \
  -H 'X-Servicio-Token: cualquiera' -H 'Content-Type: application/json' \
  --data '{"usuario_id":1,"tipo":"VACUNA","canal":"WEB","mensaje":"x","fecha_programada":"2026-01-01 10:00:00","id_operacion":"humo-afuera"}' \
  "$BASE_URL/internal/notificaciones")
RESPUESTA=""
esperar "El aviso interno no se puede llamar desde afuera (404)" 404

es_entorno_de_prueba || return 0

# Cliente de prueba: el que recibe los avisos.
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/auth/yo
esperar "El cliente de prueba tiene sesión" 200 '"id":'
ID_CLIENTE=$(primer_id)

# --- Crear avisos (llamada interna: solo se puede probar dentro del contenedor) ---
# En local y CI el humo corre contra el contenedor; si el entorno no permite llamar al
# puerto interno, esta parte se saltea.
SUFIJO=$(date +%s)
interno() {
  # interno <token> <cuerpo>: POST directo a Backend (127.0.0.1:9001), sin pasar por Nginx.
  docker compose exec -T app curl --silent -o /dev/null -w '%{http_code}' -X POST \
    -H "X-Servicio-Token: $1" -H 'Content-Type: application/json' \
    --data "$2" http://127.0.0.1:9001/internal/notificaciones 2>/dev/null
}
AVISO="{\"usuario_id\":${ID_CLIENTE:-0},\"tipo\":\"VACUNA\",\"canal\":\"WEB\",\"mensaje\":\"Humo: a Rocco le toca la vacuna\",\"fecha_programada\":\"2026-11-18 10:00:00\",\"id_operacion\":\"humo-$SUFIJO-1\"}"

if [ "$(interno cualquiera '{}')" = 401 ]; then
  esperar_codigo() { [ "$1" = "$2" ] && echo "  ok  $3" || { echo "  FALLA  $3 (dio $1)"; FALLAS=$((${FALLAS:-0}+1)); }; }
  esperar_codigo "$(interno cualquiera "$AVISO")" 401 "Sin el token correcto no se crea un aviso (401)"
  esperar_codigo "$(interno "$INTERNAL_TOKEN" '{}')" 400 "Un cuerpo inválido da 400"
  esperar_codigo "$(interno "$INTERNAL_TOKEN" "$AVISO")" 200 "Se crea el aviso (aplicado: true)"
  esperar_codigo "$(interno "$INTERNAL_TOKEN" "$AVISO")" 200 "Repetirlo no da error (aplicado: false)"
  esperar_codigo "$(interno "$INTERNAL_TOKEN" "${AVISO/\"usuario_id\":${ID_CLIENTE:-0}/\"usuario_id\":999999}")" 404 "Un usuario que no existe da 404"
fi

# --- Ver y marcar como leída (sesión del cliente) ---
pedir GET /api/notificaciones
esperar "El cliente ve sus notificaciones" 200 '"no_leidas":'
pedir GET /api/notificaciones
esperar "Con la lista de avisos" 200 '"datos":'
ID_AVISO=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

CSRF_CLIENTE=$CSRF
CSRF=""
pedir POST "/api/notificaciones/${ID_AVISO:-0}/leida"
esperar "Sin el token CSRF no se marca (403)" 403
CSRF=$CSRF_CLIENTE

pedir POST /api/notificaciones/abc/leida
esperar "Un id que no es un número da 404" 404
pedir POST "/api/notificaciones/${ID_AVISO:-0}/leida"
esperar "El cliente marca su aviso como leído" 200 '"leida":true'
pedir POST "/api/notificaciones/${ID_AVISO:-0}/leida"
esperar "Marcarlo de nuevo también da 200" 200

# --- Otro usuario no toca los avisos ajenos ---
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST "/api/notificaciones/${ID_AVISO:-0}/leida"
esperar "Un aviso de otro usuario da 404 (no se revela que existe)" 404

cerrar_sesion