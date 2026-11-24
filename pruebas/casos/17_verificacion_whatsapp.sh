# shellcheck shell=bash
# Verificación del WhatsApp (migración 019): registrarse y cambiar el número solo con el código que
# llega por WhatsApp. Contrato: docs/api/contrato.md de Backend, sección "Verificación del WhatsApp".
# En local y en el CI el WhatsApp no sale y la respuesta trae el código; en dev y en producción no
# (sale de verdad), así que ahí estos casos se saltean.
es_entorno_de_prueba || return 0

SUFIJO=$(date +%s)
TEL_REGISTRO="23235${SUFIJO: -5}"     # 10 dígitos, distinto en cada corrida (el límite es por número)
TEL_NUEVO="23236${SUFIJO: -5}"
EMAIL_VERIF="verificado-$SUFIJO@prueba.huellavet"
codigo_de() { printf '%s' "$RESPUESTA" | grep -o '"codigo":"[0-9]*"' | cut -d'"' -f4; }

pedir POST /api/auth/registro/codigo "{\"telefono\":\"$TEL_REGISTRO\",\"nombre\":\"Vera\"}"
COD_REG=$(codigo_de)
if [ -z "$COD_REG" ]; then
  echo "  (el WhatsApp sale de verdad en este entorno: no se prueba la verificación)"
  return 0
fi
esperar "Pedir el código para registrarse manda el WhatsApp" 200 "\"mensaje\":\"Te mandamos un código por WhatsApp al $TEL_REGISTRO.\""

# --- Pedir el código ---
pedir POST /api/auth/registro/codigo '{"telefono":"123"}'
esperar "Un teléfono inválido da 400 en el campo" 400 '"telefono":"El teléfono no es válido. Ejemplo: 2323 555555"'
pedir POST /api/auth/registro/codigo "{\"telefono\":\"$TEL_REGISTRO\"}"
esperar "Otro código al mismo número antes del minuto da 429" 429 '"espera_segundos":'

# --- Registrarse con el código ---
REGISTRO="\"nombre\":\"Vera Verificada\",\"email\":\"$EMAIL_VERIF\",\"password\":\"Clave-Segura-2026\",\"telefono\":\"$TEL_REGISTRO\""
pedir POST /api/auth/registro/cliente "{$REGISTRO}"
esperar "Registrarse sin el código da 400 en el campo código" 400 '"codigo":"Escribí el código de 6 números que te llegó por WhatsApp"'
OTRO=$(printf '%06d' $(( (10#$COD_REG + 1) % 1000000 )))
pedir POST /api/auth/registro/cliente "{$REGISTRO,\"codigo\":\"$OTRO\"}"
esperar "Con un código equivocado no se crea la cuenta" 400 '"codigo":"El código no es correcto"'
pedir POST /api/auth/login "{\"email\":\"$EMAIL_VERIF\",\"password\":\"Clave-Segura-2026\"}"
esperar "  (la cuenta no existe)" 401
pedir POST /api/auth/registro/cliente "{\"nombre\":\"Otra\",\"email\":\"otra-$SUFIJO@prueba.huellavet\",\"password\":\"Clave-Segura-2026\",\"telefono\":\"2323999999\",\"codigo\":\"$COD_REG\"}"
esperar "El código de un número no sirve para otro" 400 '"codigo":"Primero pedí el código por WhatsApp"'
pedir POST /api/auth/registro/cliente "{$REGISTRO,\"codigo\":\"$COD_REG\"}"
esperar "Con el código correcto se crea la cuenta (201)" 201 '"rol":"CLIENTE"'
pedir POST /api/auth/registro/cliente "{\"nombre\":\"Otra\",\"email\":\"otra2-$SUFIJO@prueba.huellavet\",\"password\":\"Clave-Segura-2026\",\"telefono\":\"$TEL_REGISTRO\",\"codigo\":\"$COD_REG\"}"
esperar "El mismo código no sirve dos veces" 400 '"codigo":"Primero pedí el código por WhatsApp"'

# --- Cambiar el número ---
pedir POST /api/cuenta/telefono/codigo "{\"telefono\":\"$TEL_NUEVO\"}"
esperar "Cambiar el número sin sesión da 401" 401
iniciar_sesion "$EMAIL_VERIF" 'Clave-Segura-2026'
pedir PUT /api/cuenta "{\"nombre\":\"Vera V.\",\"telefono\":\"$TEL_NUEVO\"}"
esperar "Guardar Mis datos cambia el nombre pero no el teléfono" 200 "\"nombre\":\"Vera V.\",\"email\":\"$EMAIL_VERIF\",\"telefono\":\"$TEL_REGISTRO\""
pedir POST /api/cuenta/telefono/codigo "{\"telefono\":\"$TEL_REGISTRO\"}"
esperar "Pedir el código para el mismo número da 400" 400 '"telefono":"Ese ya es tu número"'
pedir POST /api/cuenta/telefono/codigo "{\"telefono\":\"$TEL_NUEVO\"}"
esperar "Pedir el código al número nuevo" 200 "\"telefono\":\"$TEL_NUEVO\""
COD_CAMBIO=$(codigo_de)
pedir POST /api/cuenta/telefono '{"codigo":"000000"}'
esperar "Con un código equivocado el teléfono no cambia" 400 '"codigo":"El código no es correcto"'
pedir GET /api/cuenta
esperar "  (sigue el número anterior)" 200 "\"telefono\":\"$TEL_REGISTRO\""
pedir POST /api/cuenta/telefono "{\"codigo\":\"$COD_CAMBIO\"}"
esperar "Con el código correcto el teléfono pasa a ser el nuevo" 200 "\"telefono\":\"$TEL_NUEVO\""
pedir POST /api/cuenta/telefono "{\"codigo\":\"$COD_CAMBIO\"}"
esperar "  y el código ya no sirve otra vez" 400 '"codigo":"Primero pedí el código por WhatsApp"'
cerrar_sesion
