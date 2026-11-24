#!/usr/bin/env bash
# Carga el juego de datos de producción (base/semillas-produccion/*.sql) alrededor de las cuentas de la
# demo, que ya tienen que existir (se crean desde la web). Ver README.md de esta carpeta.
#
# Uso, desde la carpeta del Gateway:
#
#   EMAIL_VET=... EMAIL_CLIENTE1=... EMAIL_CLIENTE2=... EMAIL_RESCATISTA=... \
#     bash base/semillas-produccion/cargar.sh aiven .env.aiven-prod ca.pem
#
#   (para probarlo antes contra el MySQL del sistema local de pruebas, proyecto huellavet-ci)
#   EMAIL_VET=... bash base/semillas-produccion/cargar.sh local
#
# Antes de escribir muestra a qué base va, busca las cuatro cuentas y pide escribir CARGAR.
# Se puede correr todas las veces que haga falta: vuelve a dejar los datos como estaban, con las
# fechas corridas a hoy. No toca nada que no sea de estos rangos de ids (salvo dar de baja los
# productos e insumos que había antes, ver 002).
set -euo pipefail

DESTINO=${1:-}
CARPETA=$(cd "$(dirname "$0")" && pwd)

for v in EMAIL_VET EMAIL_CLIENTE1 EMAIL_CLIENTE2 EMAIL_RESCATISTA; do
  [ -n "${!v:-}" ] || { echo "Falta $v (el email de esa cuenta de la demo)."; exit 1; }
done
# Los emails van dentro de comillas simples en el SQL: se rechaza cualquiera con una comilla.
for v in EMAIL_VET EMAIL_CLIENTE1 EMAIL_CLIENTE2 EMAIL_RESCATISTA; do
  case "${!v}" in *"'"*|*'\'*) echo "$v no es un email válido."; exit 1 ;; esac
done

case "$DESTINO" in
  aiven)
    ENV=${2:?Falta el archivo .env (por ejemplo .env.aiven-prod)}
    CA=${3:?Falta el ca.pem de esa base}
    [ -f "$ENV" ] || { echo "No encuentro $ENV"; exit 1; }
    [ -f "$CA" ] || { echo "No encuentro $CA"; exit 1; }
    CA=$(cd "$(dirname "$CA")" && pwd)/$(basename "$CA")
    HOST=$(grep -E '^DB_HOST=' "$ENV" | cut -d= -f2- | tr -d '"')
    NOMBRE=$(grep -E '^DB_NAME=' "$ENV" | cut -d= -f2- | tr -d '"')
    sql() {
      docker run --rm -i --env-file "$ENV" -v "$CA:/ca.pem:ro" mysql:8.4 sh -c \
        'mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_ADMIN_USER" -p"$DB_ADMIN_PASSWORD" --ssl-ca=/ca.pem --ssl-mode=VERIFY_CA --default-character-set=utf8mb4 -N "$DB_NAME"' 2> >(grep -v 'Using a password' >&2)
    }
    ;;
  local)
    HOST="MySQL local (proyecto huellavet-ci)"
    NOMBRE="la base de pruebas"
    sql() {
      docker compose -p huellavet-ci --env-file .ci/ci.env -f compose.yaml -f .ci/compose.ci.yaml exec -T db sh -c \
        'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -N "$MYSQL_DATABASE"' 2> >(grep -v 'Using a password' >&2)
    }
    ;;
  *)
    echo "Uso: cargar.sh aiven <.env> <ca.pem>   o   cargar.sh local"; exit 1 ;;
esac

echo "Base: $NOMBRE en $HOST"
echo "Buscando las cuentas de la demo…"
IDS=$(sql <<SQL
SELECT CONCAT_WS(' ',
  IFNULL((SELECT id FROM usuario WHERE email = '$EMAIL_VET' AND rol = 'VETERINARIO'), 'falta'),
  IFNULL((SELECT id FROM usuario WHERE email = '$EMAIL_CLIENTE1' AND rol = 'CLIENTE'), 'falta'),
  IFNULL((SELECT id FROM usuario WHERE email = '$EMAIL_CLIENTE2' AND rol = 'CLIENTE'), 'falta'),
  IFNULL((SELECT id FROM usuario WHERE email = '$EMAIL_RESCATISTA' AND rol = 'RESCATISTA' AND estado_validacion = 'APROBADO'), 'falta'));
SQL
)
read -r VET CLIENTE1 CLIENTE2 RESCATISTA <<<"$IDS"
falta=0
[[ "$VET" =~ ^[0-9]+$ ]] || { echo "  No hay una veterinaria con el email $EMAIL_VET."; falta=1; }
[[ "$CLIENTE1" =~ ^[0-9]+$ ]] || { echo "  No hay un cliente con el email $EMAIL_CLIENTE1."; falta=1; }
[[ "$CLIENTE2" =~ ^[0-9]+$ ]] || { echo "  No hay un cliente con el email $EMAIL_CLIENTE2."; falta=1; }
[[ "$RESCATISTA" =~ ^[0-9]+$ ]] || { echo "  No hay un rescatista APROBADO con el email $EMAIL_RESCATISTA (¿lo aprobó la veterinaria?)."; falta=1; }
[ "$falta" = 0 ] || exit 1
echo "  veterinaria $VET, cliente 1 $CLIENTE1, cliente 2 $CLIENTE2, rescatista $RESCATISTA"

read -r -p "Escribí CARGAR para cargar los datos en esa base: " ok
[ "$ok" = "CARGAR" ] || { echo "No se cargó nada."; exit 1; }

{
  echo "SET @vet = $VET, @cliente1 = $CLIENTE1, @cliente2 = $CLIENTE2, @rescatista = $RESCATISTA;"
  for f in "$CARPETA"/0*.sql; do
    echo "SELECT 'Cargando $(basename "$f")…';"
    cat "$f"
    echo
  done
  echo "SELECT 'Listo.';"
} | sql
