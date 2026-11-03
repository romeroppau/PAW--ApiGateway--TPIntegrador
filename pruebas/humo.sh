#!/bin/bash
# Pruebas de humo: pedidos con curl a la API y el resultado esperado de cada uno.
#
#   bash pruebas/humo.sh http://localhost:10000                      (local)
#   bash pruebas/humo.sh https://paw-apigateway-tpintegrador-dev.onrender.com   (dev)
#   SOLO_LECTURA=1 bash pruebas/humo.sh https://paw-apigateway-tpintegrador.onrender.com   (producción)
#
# Los casos están en pruebas/casos/*.sh: cada rol agrega su propio archivo, así nadie edita
# el archivo de otro. Este archivo solo tiene las herramientas comunes.

set -uo pipefail
export MSYS_NO_PATHCONV=1

BASE_URL="${1:?Uso: bash pruebas/humo.sh <URL base, por ejemplo http://localhost:10000>}"
SOLO_LECTURA="${SOLO_LECTURA:-0}"
FALLAS=0
TOTAL=0

# pedir MÉTODO RUTA [CUERPO_JSON]
# Hace el pedido con la sesión actual (si hay) y deja el resultado en CODIGO y RESPUESTA.
pedir() {
  local metodo=$1 ruta=$2 cuerpo=${3:-}
  local args=(--silent --max-time 60 -X "$metodo" -H 'Accept: application/json'
              -w '\n%{http_code}' "$BASE_URL$ruta")
  [ -n "${SESION:-}" ] && args+=(-H "Cookie: huellavet_sesion=$SESION")
  [ -n "${CSRF:-}" ] && [ "$metodo" != GET ] && args+=(-H "X-CSRF-Token: $CSRF")
  [ -n "$cuerpo" ] && args+=(-H 'Content-Type: application/json' --data "$cuerpo")
  local salida
  salida=$(curl "${args[@]}")
  CODIGO=$(printf '%s' "$salida" | tail -n1)
  RESPUESTA=$(printf '%s' "$salida" | sed '$d')
}

# esperar "DESCRIPCIÓN" CÓDIGO_ESPERADO [TEXTO_QUE_TIENE_QUE_APARECER]
# Compara el último pedido con lo esperado y lo anota como ok o FALLA.
esperar() {
  local descripcion=$1 codigo=$2 texto=${3:-}
  TOTAL=$((TOTAL + 1))
  if [ "$CODIGO" = "$codigo" ] && { [ -z "$texto" ] || printf '%s' "$RESPUESTA" | grep -qF -- "$texto"; }; then
    echo "  ok     $descripcion"
  else
    FALLAS=$((FALLAS + 1))
    echo "  FALLA  $descripcion"
    echo "         esperaba $codigo${texto:+ con \"$texto\"}, llegó $CODIGO: $(printf '%s' "$RESPUESTA" | head -c 200)"
  fi
}

# iniciar_sesion EMAIL CONTRASEÑA
# Inicia sesión y guarda la cookie (SESION) y el token CSRF para los pedidos siguientes.
# La cookie es "Secure": curl no la reenvía sola por http://localhost, así que se manda a mano.
iniciar_sesion() {
  local salida
  # -i: la respuesta trae juntas las cabeceras (con la cookie) y el cuerpo (con el csrf).
  salida=$(curl --silent --max-time 60 -i \
    -H 'Content-Type: application/json' \
    --data "{\"email\":\"$1\",\"password\":\"$2\"}" "$BASE_URL/api/auth/login" | tr -d '\r')
  SESION=$(printf '%s' "$salida" | sed -n 's/^[Ss]et-[Cc]ookie: huellavet_sesion=\([^;]*\).*/\1/p' | head -n1)
  CSRF=$(printf '%s' "$salida" | grep -o '"csrf":"[^"]*"' | cut -d'"' -f4)
  if [ -z "$SESION" ] || [ -z "$CSRF" ]; then
    echo "  (no se pudo iniciar sesión como $1)"
  fi
}

cerrar_sesion() { SESION=""; CSRF=""; }

# Los casos que crean o modifican datos, o que usan las cuentas de los datos semilla,
# empiezan con:   es_entorno_de_prueba || return 0
# En producción (SOLO_LECTURA=1) no hay semillas y no se escribe nada: esos casos se saltean.
es_entorno_de_prueba() { [ "$SOLO_LECTURA" != "1" ]; }

cerrar_sesion
echo "Pruebas de humo contra $BASE_URL$([ "$SOLO_LECTURA" = 1 ] && echo ' (solo lectura)')"
for archivo in "$(dirname "$0")"/casos/*.sh; do
  echo
  echo "== $(basename "$archivo" .sh)"
  cerrar_sesion
  # shellcheck source=/dev/null
  source "$archivo"
done

echo
echo "$((TOTAL - FALLAS)) de $TOTAL pruebas ok"
[ "$FALLAS" -eq 0 ]
