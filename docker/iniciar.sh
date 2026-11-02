
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
# Solo lo reciben Inventario (lo verifica) y Pacientes (lo envía).

# Gateway: no recibe la clave privada JWT ni el token interno.
env -u JWT_PRIVATE_KEY -u INTERNAL_TOKEN php $OPC \
  -S 127.0.0.1:9000 \
  -t /app/comun \
  /app/comun/index.php &

# Backend: recibe sus credenciales y la clave privada JWT, pero no el token interno.
env -u INTERNAL_TOKEN \
  DB_USER="$BACKEND_DB_USER" \
  DB_PASSWORD="$BACKEND_DB_PASSWORD" \
  php $OPC \
  -S 127.0.0.1:9001 \
  -t /app/Backend/src \
  /app/Backend/src/Index.php &

# Inventario: no recibe la clave privada JWT.
env -u JWT_PRIVATE_KEY \
  DB_USER="$INVENTARIO_DB_USER" \
  DB_PASSWORD="$INVENTARIO_DB_PASSWORD" \
  php $OPC \
  -S 127.0.0.1:9002 \
  -t /app/Inventario/src \
  /app/Inventario/src/index.php &

# Pacientes: no recibe la clave privada JWT.
# Se levanta solo si están su código y sus credenciales. Si falta algo, avisa en el log y sigue:
# así un módulo nuevo sin configurar en Render no tira abajo a los demás (con set -u, una
# variable faltante cortaría todo el script).
if [ -f /app/Pacientes/src/index.php ] \
  && [ -n "${PACIENTES_DB_USER:-}" ] \
  && [ -n "${PACIENTES_DB_PASSWORD:-}" ]; then
  env -u JWT_PRIVATE_KEY \
    DB_USER="$PACIENTES_DB_USER" \
    DB_PASSWORD="$PACIENTES_DB_PASSWORD" \
    php $OPC \
    -S 127.0.0.1:9003 \
    -t /app/Pacientes/src \
    /app/Pacientes/src/index.php &
else
  echo "[AVISO] Pacientes no se inicia: falta Pacientes/src/index.php o PACIENTES_DB_USER/PACIENTES_DB_PASSWORD" >&2
fi

# Nginx tampoco debe heredar la clave privada ni el token interno.
unset JWT_PRIVATE_KEY INTERNAL_TOKEN

exec nginx -g 'daemon off;'
