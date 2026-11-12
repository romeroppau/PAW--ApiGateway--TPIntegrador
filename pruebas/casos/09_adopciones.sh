# shellcheck shell=bash
# Casos del circuito de adopción (rol 3). Contrato: docs/api/contrato-adopciones.md del repo
# Adopciones. Datos: base/semillas/README.md, sección "Adopciones" (rescatista@ aprobada,
# rescatista2@ pendiente). Volver a sembrar deja todo como al principio.

# --- Validación de rescatistas (Backend) ---
cerrar_sesion
pedir GET /api/rescatistas
esperar "Sin sesión no se ven los rescatistas (401)" 401

# La transferencia de la mascota al adoptante es de proceso a proceso (Adopciones -> Pacientes):
# desde afuera tiene que estar bloqueada, también con un token inventado.
CODIGO=$(curl --silent --max-time 60 -o /dev/null -w '%{http_code}' -X POST \
  -H 'X-Servicio-Token: cualquiera' -H 'Content-Type: application/json' \
  --data '{"duenio_actual_id":104,"nuevo_duenio_id":103}' "$BASE_URL/internal/mascotas/902/transferir")
RESPUESTA=""
esperar "La transferencia de la mascota no se puede llamar desde afuera (404)" 404

es_entorno_de_prueba || return 0

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/rescatistas
esperar "Un cliente no ve los rescatistas (403)" 403
pedir POST /api/rescatistas/105/aprobar
esperar "Un cliente no aprueba rescatistas (403)" 403

# La sesión de la rescatista pendiente se guarda: después de aprobarla, la misma sesión ya dice APROBADO.
iniciar_sesion rescatista2@prueba.huellavet 'Rescatista-Prueba-2026'
SESION_RESCATISTA2=$SESION
CSRF_RESCATISTA2=$CSRF
pedir GET /api/auth/yo
esperar "La rescatista pendiente ve su estado en la sesión" 200 '"estado_validacion":"PENDIENTE"'
pedir POST /api/rescatistas/105/aprobar
esperar "Una rescatista no se aprueba a sí misma (403)" 403

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/rescatistas
esperar "La veterinaria ve las rescatistas pendientes" 200 '"email":"rescatista2@prueba.huellavet"'
pedir GET '/api/rescatistas?estado=APROBADO'
esperar "Y, filtrando, las aprobadas" 200 '"email":"rescatista@prueba.huellavet"'
pedir GET '/api/rescatistas?estado=OTRO'
esperar "Un estado que no existe da 400" 400

CSRF_VET=$CSRF
CSRF=""
pedir POST /api/rescatistas/105/aprobar
esperar "Sin el token CSRF no se aprueba (403)" 403
CSRF=$CSRF_VET

pedir POST /api/rescatistas/102/aprobar
esperar "Un cliente no es un rescatista (404)" 404
pedir POST /api/rescatistas/abc/aprobar
esperar "Un id que no es un número da 404" 404
pedir POST /api/rescatistas/104/rechazar
esperar "Una rescatista ya aprobada no se rechaza (409)" 409 'ya fue aprobado'

pedir POST /api/rescatistas/105/aprobar
esperar "La veterinaria aprueba a la rescatista pendiente" 200 '"estado_validacion":"APROBADO"'
pedir POST /api/rescatistas/105/rechazar
esperar "La decisión es una sola: después no se rechaza (409)" 409

SESION=$SESION_RESCATISTA2
CSRF=$CSRF_RESCATISTA2
pedir GET /api/auth/yo
esperar "La rescatista ve que la aprobaron sin volver a iniciar sesión" 200 '"estado_validacion":"APROBADO"'

# --- Mascotas a cargo de la rescatista (Pacientes) ---
iniciar_sesion rescatista@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/pacientes/mascotas
esperar "La rescatista ve las mascotas que tiene a cargo" 200 '"nombre":"Canela"'
pedir GET /api/pacientes/mascotas/101
esperar "La mascota de un cliente le da 404" 404

pedir POST /api/pacientes/mascotas '{"nombre":"Rescatado de humo","especie":"GATO"}'
esperar "La rescatista carga un animal rescatado" 201 '"duenio":{"id":104'
MASCOTA_RESCATADA=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
pedir PUT "/api/pacientes/mascotas/${MASCOTA_RESCATADA:-0}" '{"nombre":"Rescatado de humo","especie":"GATO","peso_kg":3.5}'
esperar "La rescatista edita la mascota que cargó" 200 '"peso_kg":"3.50"'

pedir GET /api/pacientes/mascotas/902/historial
esperar "El historial clínico no es para la rescatista (403)" 403
pedir GET /api/pacientes/turnos
esperar "Los turnos tampoco (403)" 403

pedir DELETE "/api/pacientes/mascotas/${MASCOTA_RESCATADA:-0}"
esperar "La rescatista da de baja la mascota que cargó" 204

iniciar_sesion rescatista2@prueba.huellavet 'Rescatista-Prueba-2026'
pedir GET /api/pacientes/mascotas/902
esperar "Otra rescatista no ve las mascotas de la primera (404)" 404

cerrar_sesion
