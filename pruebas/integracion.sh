#!/bin/bash
# Prueba de integración: levanta el sistema completo en Docker (Nginx + módulos + MySQL),
# corre las migraciones (y las semillas, si existen) y comprueba que todo responda.
# La usa GitHub Actions en cada push y pull request, y se puede correr igual en la computadora:
#
#   bash pruebas/integracion.sh
#
# No toca el entorno local de cada uno: usa otro nombre de proyecto de Docker, otros puertos
# y sus propios archivos en .ci/ (no se suben). Al terminar borra los contenedores y la base.
# Para dejarlo levantado y mirar qué pasó: MANTENER=1 bash pruebas/integracion.sh

set -euo pipefail
cd "$(dirname "$0")/.."

# En Git Bash (Windows), evita que "/CN=..." de openssl se convierta en una ruta de archivo.
# En Linux y en GitHub Actions no tiene efecto.
export MSYS_NO_PATHCONV=1

PROYECTO=huellavet-ci
PUERTO_APP=10080
PUERTO_MYSQL=3317
DIR=.ci
BASE_URL="http://localhost:$PUERTO_APP"

mkdir -p "$DIR"

# --- 1. Certificados para el MySQL de prueba -------------------------------------------------
# comun/database.php exige conexión con SSL, también en pruebas: se genera una autoridad
# certificante descartable y un certificado para el host "db".
openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=HuellaVet CA pruebas" \
  -keyout "$DIR/ca-key.pem" -out "$DIR/ca.pem" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj "/CN=db" \
  -keyout "$DIR/server-key.pem" -out "$DIR/server.csr" 2>/dev/null
printf 'subjectAltName=DNS:db,DNS:localhost,IP:127.0.0.1\n' > "$DIR/san.ext"
openssl x509 -req -in "$DIR/server.csr" -CA "$DIR/ca.pem" -CAkey "$DIR/ca-key.pem" \
  -CAcreateserial -days 2 -extfile "$DIR/san.ext" -out "$DIR/server-cert.pem" 2>/dev/null
# El usuario de MySQL dentro del contenedor tiene que poder leer la clave.
chmod 644 "$DIR"/*.pem

# --- 2. Variables (todas descartables, generadas en cada corrida) ----------------------------
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$DIR/jwt_privada.pem" 2>/dev/null
openssl pkey -in "$DIR/jwt_privada.pem" -pubout -out "$DIR/jwt_publica.pem"
una_linea() { awk 'NF {printf "%s\\n", $0}' "$1"; }
clave() { openssl rand -hex 16; }
ROOT=$(clave)

cat > "$DIR/ci.env" <<EOF
ENTORNO=ci
APP_PORT=$PUERTO_APP
MYSQL_HOST_PORT=$PUERTO_MYSQL
MYSQL_ROOT_PASSWORD=$ROOT
LOCAL_DB_NAME=huellavet
DB_HOST=db
DB_PORT=3306
DB_NAME=huellavet
DB_SSL_CA=/app/ca.pem
DB_ADMIN_USER=root
DB_ADMIN_PASSWORD=$ROOT
BACKEND_DB_USER=backend
BACKEND_DB_PASSWORD=$(clave)
INVENTARIO_DB_USER=inventario
INVENTARIO_DB_PASSWORD=$(clave)
PACIENTES_DB_USER=pacientes
PACIENTES_DB_PASSWORD=$(clave)
ADOPCIONES_DB_USER=adopciones
ADOPCIONES_DB_PASSWORD=$(clave)
INTERNAL_TOKEN=$(openssl rand -hex 32)
JWT_PRIVATE_KEY="$(una_linea "$DIR/jwt_privada.pem")"
JWT_PUBLIC_KEY="$(una_linea "$DIR/jwt_publica.pem")"
EOF

# --- 3. Ajustes de Compose para la prueba ----------------------------------------------------
# MySQL con SSL, y el certificado de .ci/ en lugar del ca.pem de cada uno.
cat > "$DIR/compose.ci.yaml" <<EOF
services:
  db:
    command:
      - --ssl-ca=/etc/mysql/ssl/ca.pem
      - --ssl-cert=/etc/mysql/ssl/server-cert.pem
      - --ssl-key=/etc/mysql/ssl/server-key.pem
    volumes:
      - ./$DIR:/etc/mysql/ssl:ro
  app:
    volumes:
      - ./$DIR/ca.pem:/app/ca.pem:ro
  migrator:
    volumes:
      - ./$DIR/ca.pem:/app/ca.pem:ro
EOF

# El servicio "sembrador" (datos semilla) existe cuando está base/sembrar.php.
if [ -f base/sembrar.php ]; then
  cat >> "$DIR/compose.ci.yaml" <<EOF
  sembrador:
    volumes:
      - ./$DIR/ca.pem:/app/ca.pem:ro
EOF
fi

compose() {
  docker compose -p "$PROYECTO" --env-file "$DIR/ci.env" -f compose.yaml -f "$DIR/compose.ci.yaml" "$@"
}

terminar() {
  codigo=$?
  if [ "$codigo" -ne 0 ]; then
    echo
    echo "=== La prueba falló. Últimas líneas del log de la aplicación ==="
    compose logs --tail=80 app || true
  fi
  if [ "${MANTENER:-0}" != "1" ]; then
    compose --profile local --profile tools down -v --remove-orphans >/dev/null 2>&1 || true
  else
    echo "Quedó levantado en $BASE_URL (proyecto $PROYECTO)."
  fi
  exit "$codigo"
}
trap terminar EXIT

# --- 4. Levantar, migrar y sembrar -----------------------------------------------------------
echo "=== Levantando el sistema"
compose --profile local up -d --build --wait

echo "=== Migraciones"
compose --profile tools run --rm --build migrator

if [ -f base/sembrar.php ]; then
  echo "=== Datos semilla"
  # --build: la imagen copia base/semillas/; sin reconstruirla, se cargarían las semillas de la última vez.
  compose --profile tools run --rm --build sembrador
fi

# --- 5. Comprobar que cada módulo responde ----------------------------------------------------
esperar_salud() {
  local modulo=$1
  for _ in $(seq 1 20); do
    if curl --silent --fail --max-time 5 "$BASE_URL/api/$modulo/salud" >/dev/null; then
      echo "  ok   /api/$modulo/salud"
      return 0
    fi
    sleep 1
  done
  echo "  FALLA /api/$modulo/salud: $(curl --silent --max-time 5 -w ' [%{http_code}]' "$BASE_URL/api/$modulo/salud" | tr -d '\n' | cut -c1-120)"
  return 1
}

echo "=== Salud de los módulos"
esperar_salud gateway
[ -f Backend/src/Index.php ]      && esperar_salud backend
[ -f Inventario/src/index.php ]   && esperar_salud inventario
[ -f Pacientes/src/index.php ]    && esperar_salud pacientes

# --- 6. Pruebas de humo (si ya existen) -------------------------------------------------------
if [ -f pruebas/humo.sh ]; then
  echo "=== Pruebas de humo"
  bash pruebas/humo.sh "$BASE_URL"
fi

echo
echo "=== Prueba de integración: OK"
