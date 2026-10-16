
#!/bin/sh
set -eu

mkdir -p \
  /tmp/nginx/client_temp \
  /tmp/nginx/proxy_temp \
  /tmp/nginx/fastcgi_temp \
  /tmp/nginx/uwsgi_temp \
  /tmp/nginx/scgi_temp

OPC="-d display_errors=0 -d log_errors=1"

# Gateway: no recibe la clave privada JWT.
env -u JWT_PRIVATE_KEY php $OPC \
  -S 127.0.0.1:9000 \
  -t /app/comun \
  /app/comun/index.php &

# Backend: recibe sus credenciales y la clave privada JWT.
env \
  DB_USER="$BACKEND_DB_USER" \
  DB_PASSWORD="$BACKEND_DB_PASSWORD" \
  php $OPC \
  -S 127.0.0.1:9001 \
  -t /app/Backend/public \
  /app/Backend/public/index.php &

# Inventario: no recibe la clave privada JWT.
env -u JWT_PRIVATE_KEY \
  DB_USER="$INVENTARIO_DB_USER" \
  DB_PASSWORD="$INVENTARIO_DB_PASSWORD" \
  php $OPC \
  -S 127.0.0.1:9002 \
  -t /app/Inventario/public \
  /app/Inventario/public/index.php &

# Nginx tampoco debe heredar la clave privada.
unset JWT_PRIVATE_KEY

exec nginx -g 'daemon off;'
