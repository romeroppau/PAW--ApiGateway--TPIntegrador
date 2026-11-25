# shellcheck shell=bash
# 25/11: los avisos de turnos y el bloqueo del login.
#   - Cuando la veterinaria da, reprograma o cancela un turno, al dueño le llega el aviso (tipo TURNO,
#     migración 024; Pacientes src/AvisosTurno.php, contrato-mascotas-turnos.md "Avisos de turnos").
#   - Una cuenta bloqueada (5 intentos fallidos) responde 429 con cuánto falta, también con la
#     contraseña correcta (Backend, contrato.md "Bloqueo"). Usa rescatista2@, al final: queda bloqueada.
es_entorno_de_prueba || return 0

MANIANA_AVISOS=$(date -u -d '-3 hours +1 day' +%Y-%m-%d)
id_turno_aviso() { printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

# --- Avisos de turnos ---
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir POST /api/pacientes/turnos "{\"mascota_id\":102,\"fecha\":\"$MANIANA_AVISOS\",\"hora\":\"18:10\",\"motivo\":\"CONSULTA\"}"
esperar "La veterinaria le da un turno a Michi" 201
TURNO_AVISO=$(id_turno_aviso)

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/notificaciones
esperar "A la dueña le llega el aviso del turno" 200 'turno de consulta para Michi'

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir POST "/api/pacientes/turnos/${TURNO_AVISO:-0}/reprogramar" "{\"fecha\":\"$MANIANA_AVISOS\",\"hora\":\"18:20\"}"
esperar "La veterinaria lo reprograma" 200 '"hora":"18:20"'
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/notificaciones
esperar "  y le llega el aviso del cambio" 200 'Cambiamos el turno de Michi'

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir POST "/api/pacientes/turnos/${TURNO_AVISO:-0}/cancelar"
esperar "La veterinaria lo cancela" 200 '"estado":"CANCELADO"'
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/notificaciones
esperar "  y le llega el aviso de la cancelación" 200 'Cancelamos el turno de consulta de Michi'
cerrar_sesion

# --- Bloqueo del login ---
for intento in 1 2 3 4; do
  pedir POST /api/auth/login '{"email":"rescatista2@prueba.huellavet","password":"incorrecta"}'
done
esperar "Con 4 intentos fallidos sigue diciendo el mensaje de siempre (401)" 401 'Email o contrase'
pedir POST /api/auth/login '{"email":"rescatista2@prueba.huellavet","password":"incorrecta"}'
esperar "El 5.o intento fallido bloquea y lo dice (429)" 429 '"bloqueada":true'
pedir POST /api/auth/login '{"email":"rescatista2@prueba.huellavet","password":"Rescatista-Prueba-2026"}'
esperar "Bloqueada, ni con la contraseña correcta entra, y dice cuánto falta" 429 '"segundos_restantes":'
pedir POST /api/auth/login '{"email":"nadie@prueba.huellavet","password":"incorrecta"}'
esperar "Un email que no existe sigue sin revelarse (401)" 401 'Email o contrase'
