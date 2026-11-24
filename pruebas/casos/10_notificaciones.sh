# shellcheck shell=bash
# Casos de notificaciones (rol 1). Contrato: docs/api/contrato-notificaciones.md del repo Backend.
# La lógica interna (idempotencia, 400, 401, 404) la prueban las PHPUnit de Backend.

# --- Sin sesión (también corre contra producción, solo lectura) ---
cerrar_sesion
pedir GET /api/notificaciones
esperar "Sin sesión no se ven las notificaciones (401)" 401
pedir POST /api/notificaciones/1/leida
esperar "Sin sesión no se marca una notificación (401)" 401
pedir GET /api/notificaciones/historial
esperar "Sin sesión no se ve el historial (401)" 401

# /internal/ es de proceso a proceso: desde afuera tiene que estar bloqueado.
pedir POST /internal/notificaciones '{"usuario_id":1,"tipo":"VACUNA","canal":"WEB","mensaje":"x","fecha_programada":"2026-01-01 10:00:00","id_operacion":"humo-afuera"}'
esperar "El aviso interno no se puede llamar desde afuera (404)" 404

CODIGO=$(curl --silent --max-time 60 -o /dev/null -w '%{http_code}' -X POST \
  -H 'X-Servicio-Token: cualquiera' -H 'Content-Type: application/json' --data '{}' \
  "$BASE_URL/internal/notificaciones")
RESPUESTA=""
esperar "Con un X-Servicio-Token inventado también da 404" 404

# La tarea de envío por WhatsApp (la llama GitHub Actions cada 15 minutos) exige X-Tarea-Token.
pedir POST /api/notificaciones/tareas/enviar
esperar "La tarea de envío sin X-Tarea-Token da 401" 401

CODIGO=$(curl --silent --max-time 60 -o /dev/null -w '%{http_code}' -X POST \
  -H 'X-Tarea-Token: token-incorrecto' "$BASE_URL/api/notificaciones/tareas/enviar")
RESPUESTA=""
esperar "La tarea de envío con un X-Tarea-Token inválido da 401" 401

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

# --- La campana muestra solo los sin leer (hasta 10); el historial, todos ---
pedir GET /api/notificaciones
if printf '%s' "$RESPUESTA" | grep -q 'Aviso de prueba'; then
  echo "  FALLA  el aviso leído sigue en la campana"; FALLAS=$((FALLAS + 1))
else
  echo "  ok     Ya leído, el aviso deja la campana"
fi
TOTAL=$((TOTAL + 1))
LEIDAS=$(printf '%s' "$RESPUESTA" | grep -o '"leida":true' | wc -l | tr -d ' ')
CUANTOS=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | wc -l | tr -d ' ')
TOTAL=$((TOTAL + 1))
if [ "$LEIDAS" -eq 0 ] && [ "$CUANTOS" -le 10 ]; then echo "  ok     La campana trae solo sin leer, hasta 10 ($CUANTOS)"; else echo "  FALLA  la campana trae $CUANTOS avisos, $LEIDAS leídos"; FALLAS=$((FALLAS + 1)); fi

pedir GET '/api/notificaciones/historial?estado=LEIDAS'
esperar "El historial tiene el aviso leído" 200 'Aviso de prueba'
esperar "  de a 20, con las fechas que usó (los últimos 30 días)" 200 '"por_pagina":20'
pedir GET '/api/notificaciones/historial?estado=SIN_LEER'
if printf '%s' "$RESPUESTA" | grep -q 'Aviso de prueba'; then echo "  FALLA  el filtro Sin leer trae el leído"; FALLAS=$((FALLAS + 1)); else echo "  ok     Con el filtro Sin leer, no está"; fi
TOTAL=$((TOTAL + 1))
pedir GET '/api/notificaciones/historial?desde=2020-01-01&hasta=2020-01-31'
esperar "Entre dos fechas sin avisos, vacío" 200 '"datos":[]'
pedir GET '/api/notificaciones/historial?estado=CUALQUIERA'
esperar "Un estado inválido da 400" 400 '"estado"'
pedir GET '/api/notificaciones/historial?desde=2020-02-01&hasta=2020-01-01'
esperar "Desde después de hasta da 400" 400 '"desde"'

# --- Marcar todas como leídas ---
CSRF_CLIENTE=$CSRF
CSRF=""
pedir POST /api/notificaciones/leidas
esperar "Marcar todas sin el token CSRF da 403" 403
CSRF=$CSRF_CLIENTE
pedir POST /api/notificaciones/leidas
esperar "Marcar todas como leídas" 200 '"no_leidas":0'
pedir GET /api/notificaciones
esperar "  y la campana queda vacía" 200 '"no_leidas":0,"datos":[]'

cerrar_sesion

# --- La tarea de envío corre y devuelve el resumen (en local y ci el WhatsApp es simulado) ---
if [ -z "${TAREAS_TOKEN:-}" ]; then
  echo "  (sin TAREAS_TOKEN: no se prueba la ejecución de la tarea de envío)"
  return 0
fi

SALIDA=$(curl --silent --max-time 60 -w '\n%{http_code}' -X POST \
  -H "X-Tarea-Token: $TAREAS_TOKEN" "$BASE_URL/api/notificaciones/tareas/enviar")
CODIGO=$(printf '%s' "$SALIDA" | tail -n1)
RESPUESTA=$(printf '%s' "$SALIDA" | sed '$d')
esperar "La tarea de envío con su token corre y devuelve el resumen" 200 '"enviadas":'
esperar "  separando los que se reintentan de los descartados" 200 '"descartadas":'

# Correrla de nuevo enseguida no vuelve a mandar lo que ya salió.
SALIDA=$(curl --silent --max-time 60 -w '\n%{http_code}' -X POST \
  -H "X-Tarea-Token: $TAREAS_TOKEN" "$BASE_URL/api/notificaciones/tareas/enviar")
CODIGO=$(printf '%s' "$SALIDA" | tail -n1)
RESPUESTA=$(printf '%s' "$SALIDA" | sed '$d')
esperar "Una segunda corrida no reenvía los avisos ya enviados" 200 '"enviadas":0'
