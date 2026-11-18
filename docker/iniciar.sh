#!/bin/sh
set -eu

mkdir -p \
  /tmp/nginx/client_temp \
  /tmp/nginx/proxy_temp \
  /tmp/nginx/fastcgi_temp \
  /tmp/nginx/uwsgi_temp \
  /tmp/nginx/scgi_temp

OPC="-d display_errors=0 -d log_errors=1"

# INTERNAL_TOKEN: token de las llamadas internas entre módulos (/internal/).
# Lo reciben Inventario y Pacientes (stock), Backend (notificaciones) y Adopciones/Reportes (que llaman).
# El Gateway y Nginx no lo reciben.
# WHATSAPP_TOKEN: solo lo recibe Backend (envía los avisos por WhatsApp).
# TAREAS_TOKEN: lo reciben Backend y Inventario, que atienden las tareas programadas
# (Inventario: POST /api/tienda/tareas/vencer, vencimientos y recordatorios de la tienda).

# Gateway: no recibe la clave privada JWT, el token interno ni los de WhatsApp y tareas.
env -u JWT_PRIVATE_KEY -u INTERNAL_TOKEN -u WHATSAPP_TOKEN -u TAREAS_TOKEN php $OPC \
  -S 127.0.0.1:9000 \
  -t /app/comun \
  /app/comun/index.php &

# Backend: recibe sus credenciales, la clave privada JWT, el token interno
# y los de WhatsApp y tareas (los usa solo él).
env \
  DB_USER="$BACKEND_DB_USER" \
  DB_PASSWORD="$BACKEND_DB_PASSWORD" \
  php $OPC \
  -S 127.0.0.1:9001 \
  -t /app/Backend/src \
  /app/Backend/src/Index.php &

# Inventario: no recibe la clave privada JWT ni el de WhatsApp. Sí el de tareas (vencimientos de la tienda).
env -u JWT_PRIVATE_KEY -u WHATSAPP_TOKEN \
  DB_USER="$INVENTARIO_DB_USER" \
  DB_PASSWORD="$INVENTARIO_DB_PASSWORD" \
  php $OPC \
  -S 127.0.0.1:9002 \
  -t /app/Inventario/src \
  /app/Inventario/src/index.php &

# Pacientes: no recibe la clave privada JWT ni los de WhatsApp y tareas.
# Se levanta solo si están su código y sus credenciales. Si falta algo, avisa en el log y sigue:
# así un módulo nuevo sin configurar en Render no tira abajo a los demás (con set -u, una
# variable faltante cortaría todo el script).
if [ -f /app/Pacientes/src/index.php ] \
  && [ -n "${PACIENTES_DB_USER:-}" ] \
  && [ -n "${PACIENTES_DB_PASSWORD:-}" ]; then
  env -u JWT_PRIVATE_KEY -u WHATSAPP_TOKEN -u TAREAS_TOKEN \
    DB_USER="$PACIENTES_DB_USER" \
    DB_PASSWORD="$PACIENTES_DB_PASSWORD" \
    php $OPC \
    -S 127.0.0.1:9003 \
    -t /app/Pacientes/src \
    /app/Pacientes/src/index.php &
else
  echo "[AVISO] Pacientes no se inicia: falta Pacientes/src/index.php o PACIENTES_DB_USER/PACIENTES_DB_PASSWORD" >&2
fi

# Adopciones (Entrega 5): no recibe la clave privada JWT ni los de WhatsApp y tareas.
# Arranca condicionado, igual que Pacientes.
if [ -f /app/Adopciones/src/index.php ] \
  && [ -n "${ADOPCIONES_DB_USER:-}" ] \
  && [ -n "${ADOPCIONES_DB_PASSWORD:-}" ]; then
  env -u JWT_PRIVATE_KEY -u WHATSAPP_TOKEN -u TAREAS_TOKEN \
    DB_USER="$ADOPCIONES_DB_USER" \
    DB_PASSWORD="$ADOPCIONES_DB_PASSWORD" \
    php $OPC \
    -S 127.0.0.1:9004 \
    -t /app/Adopciones/src \
    /app/Adopciones/src/index.php &
else
  echo "[AVISO] Adopciones no se inicia: falta Adopciones/src/index.php o ADOPCIONES_DB_USER/ADOPCIONES_DB_PASSWORD" >&2
fi

# Nginx tampoco debe heredar la clave privada ni los tokens.
unset JWT_PRIVATE_KEY INTERNAL_TOKEN WHATSAPP_TOKEN TAREAS_TOKEN

exec nginx -g 'daemon off;'