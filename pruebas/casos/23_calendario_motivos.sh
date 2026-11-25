# shellcheck shell=bash
# 25/11 (migración 025): el calendario sanitario manda en los turnos de vacunación y desparasitación.
#   - Un turno de vacunación o desparasitación dice cuál (plan_sanitario_id) y solo se saca si está en
#     el calendario de la mascota sin dar, sin una dosis anterior sin dar y sin otro turno para lo mismo.
#   - La veterinaria edita el calendario: agrega, marca como dada (por ejemplo, en otra veterinaria),
#     cambia la fecha y quita.
#   - La consulta de una vacuna lleva su insumo; sin stock no finaliza, y el stock se carga desde ahí.
# Contratos: Pacientes docs/api/contrato-calendario.md, contrato-mascotas-turnos.md y contrato-consultas.md.
# Usa a Michi (102, gato de cliente@) y la leucemia felina, que es opcional: no está en su calendario.
es_entorno_de_prueba || return 0

HOY_CAL=$(date -u -d '-3 hours' +%Y-%m-%d)
MANIANA_CAL=$(date -u -d '-3 hours +1 day' +%Y-%m-%d)
AYER_CAL=$(date -u -d '-3 hours -1 day' +%Y-%m-%d)
CAL=/api/pacientes/mascotas/102/calendario-sanitario
# El id del evento sin dar con ese nombre, en el calendario de la última respuesta.
evento_sin_dar() {
  printf '%s' "$RESPUESTA" | grep -o "\"id\":[0-9]*,\"tipo\":\"[A-Z]*\",\"nombre\":\"$1\",[^}]*\"fecha_aplicada\":null" \
    | head -1 | cut -d: -f2 | cut -d, -f1
}
turno_vacuna() { # PLAN HORA
  pedir POST /api/pacientes/turnos "{\"mascota_id\":102,\"fecha\":\"$MANIANA_CAL\",\"hora\":\"$2\",\"motivo\":\"VACUNACION\",\"plan_sanitario_id\":$1}"
}

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

# --- El calendario trae el plan de la especie ---
pedir GET "$CAL"
esperar "El calendario trae el plan del gato, con las vacunas opcionales" 200 '"nombre":"Leucemia felina (1.ª dosis)","aplicacion":"LEUCEMIA_FELINA","orden":1'

# --- El turno de vacunación dice cuál, y tiene que estar en el calendario ---
pedir POST /api/pacientes/turnos "{\"mascota_id\":102,\"fecha\":\"$MANIANA_CAL\",\"hora\":\"17:10\",\"motivo\":\"VACUNACION\"}"
esperar "Un turno de vacunación sin decir cuál da 400" 400 '"plan_sanitario_id":"Elegí la vacuna"'
turno_vacuna 15 17:10
esperar "Una vacuna que no está en el calendario da 409, con el aviso" 409 'En el calendario de Michi no figura que se le tenga que dar: Leucemia felina (2.ª dosis)'
turno_vacuna 4 17:10
esperar "Una vacuna de otra especie da 400" 400 'no es para la especie de Michi'
pedir POST /api/pacientes/turnos "{\"mascota_id\":102,\"fecha\":\"$MANIANA_CAL\",\"hora\":\"17:10\",\"motivo\":\"DESPARASITACION\",\"plan_sanitario_id\":7}"
esperar "La desparasitación también: Michi la tiene dada y no figura otra" 409 'no figura que se le tenga que dar: Desparasitación interna'

# --- El cliente ve el calendario pero no lo edita ---
iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir POST "$CAL" "{\"plan_sanitario_id\":14,\"fecha_programada\":\"$HOY_CAL\"}"
esperar "El cliente no puede agregar al calendario (403)" 403
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

# --- Agregar al calendario ---
pedir POST "$CAL" "{\"plan_sanitario_id\":14,\"fecha_programada\":\"$HOY_CAL\"}"
esperar "La veterinaria agrega la 1.ª dosis de leucemia felina" 200 '"nombre":"Leucemia felina (1.ª dosis)","plan_sanitario_id":14'
pedir POST "$CAL" "{\"plan_sanitario_id\":15,\"fecha_programada\":\"$MANIANA_CAL\"}"
esperar "  y la 2.ª" 200 '"nombre":"Leucemia felina (2.ª dosis)","plan_sanitario_id":15'
DOSIS1=$(evento_sin_dar 'Leucemia felina (1.ª dosis)')
DOSIS2=$(evento_sin_dar 'Leucemia felina (2.ª dosis)')
pedir POST "$CAL" "{\"plan_sanitario_id\":15,\"fecha_programada\":\"$MANIANA_CAL\"}"
esperar "Agregar de nuevo una que está sin dar da 409" 409 'Ya está en el calendario'
pedir POST "$CAL" "{\"plan_sanitario_id\":4,\"fecha_programada\":\"$MANIANA_CAL\"}"
esperar "Una de otra especie da 400" 400 '"plan_sanitario_id"'
pedir POST "$CAL" "{\"plan_sanitario_id\":16,\"fecha_programada\":\"$AYER_CAL\"}"
esperar "Una fecha pasada da 400" 400 '"fecha_programada"'

# --- El orden de las dosis ---
turno_vacuna 15 17:10
esperar "La 2.ª dosis no se agenda con la 1.ª sin dar" 409 'Antes de Leucemia felina (2.ª dosis) tiene que darse Leucemia felina (1.ª dosis)'
pedir POST "$CAL/${DOSIS2:-0}/dada" "{\"fecha_aplicada\":\"$HOY_CAL\"}"
esperar "  ni se marca como dada antes que la 1.ª" 409 'Primero marcá como dada: Leucemia felina (1.ª dosis)'
pedir POST "$CAL/${DOSIS1:-0}/dada" "{\"fecha_aplicada\":\"$MANIANA_CAL\"}"
esperar "Marcar como dada con una fecha futura da 400" 400 'no puede ser posterior a hoy'
pedir POST "$CAL/${DOSIS1:-0}/dada" "{\"fecha_aplicada\":\"$HOY_CAL\"}"
esperar "La 1.ª se marca como dada a mano (se la dieron en otra veterinaria)" 200 '"en_consulta":false'

# --- Ahora sí, el turno ---
turno_vacuna 15 17:10
esperar "Con la 1.ª dada, se saca el turno para la 2.ª" 201 "\"evento_sanitario\":{\"id\":${DOSIS2:-0},\"nombre\":\"Leucemia felina (2.ª dosis)\",\"aplicacion\":\"LEUCEMIA_FELINA\"}"
TURNO_LEU=$(printf '%s' "$RESPUESTA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
turno_vacuna 15 17:20
esperar "Un segundo turno para la misma dosis da 409" 409 'Michi ya tiene turno para Leucemia felina (2.ª dosis)'
pedir DELETE "$CAL/${DOSIS2:-0}"
esperar "No se quita una dosis que tiene turno" 409 'cancelalo primero'
pedir PUT "$CAL/${DOSIS2:-0}" "{\"fecha_programada\":\"$MANIANA_CAL\"}"
esperar "  pero sí se le cambia la fecha" 200 '"turno":{"id":'
pedir PUT "$CAL/${DOSIS2:-0}" "{\"fecha_programada\":\"$AYER_CAL\"}"
esperar "  a una fecha que no sea pasada" 400 'anterior a hoy'

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/notificaciones
esperar "A la dueña le llega el aviso con la vacuna" 200 'turno de vacunación (Leucemia felina, 2.ª dosis) para Michi'
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

# --- La consulta lleva la vacuna, y el stock se carga desde ahí ---
pedir POST "/api/pacientes/turnos/${TURNO_LEU:-0}/atencion"
esperar "La consulta dice qué vacuna se da y el insumo que sirve (sin stock)" 201 '"insumos":[{"id":191,"nombre":"Vacuna leucemia felina (dosis)","stock":0}]'
CONSULTA_LEU=$(printf '%s' "$RESPUESTA" | sed -n 's/^{"consulta":{"id":\([0-9]*\).*/\1/p')
pedir PUT "/api/pacientes/consultas/${CONSULTA_LEU:-0}" '{"diagnostico":"Sano. Segunda dosis de leucemia felina."}'
esperar "Se guarda el diagnóstico" 200 '"diagnostico":"Sano.'
pedir POST "/api/pacientes/consultas/${CONSULTA_LEU:-0}/finalizar"
esperar "Sin la vacuna en los insumos no se finaliza" 400 'cargá en los insumos la dosis que se da'
pedir POST "/api/pacientes/consultas/${CONSULTA_LEU:-0}/insumos" '{"insumo_id":191,"cantidad":1}'
esperar "Se carga la dosis (con su aplicación y su stock)" 201 '"aplicacion":"LEUCEMIA_FELINA","stock":0'
pedir POST "/api/pacientes/consultas/${CONSULTA_LEU:-0}/finalizar"
esperar "Sin stock tampoco se finaliza" 409 'Stock insuficiente'
pedir POST /api/inventario/insumos/191/stock '{"cantidad":3}'
esperar "Se carga stock de la vacuna (desde la consulta)" 200 '"stock":3'
pedir POST "/api/pacientes/consultas/${CONSULTA_LEU:-0}/finalizar"
esperar "Ahora sí se finaliza" 200 '"numero":"C-'
pedir GET "$CAL"
esperar "La 2.ª dosis queda dada en esa consulta" 200 "\"id\":${DOSIS2:-0},\"tipo\":\"VACUNA\",\"nombre\":\"Leucemia felina (2.ª dosis)\",\"plan_sanitario_id\":15,\"aplicacion\":\"LEUCEMIA_FELINA\",\"fecha_programada\":\"$MANIANA_CAL\",\"fecha_aplicada\":\"$HOY_CAL\",\"en_consulta\":true"
pedir GET /api/inventario/insumos/191
esperar "  y se descontó la dosis" 200 '"stock":2'

# --- Quitar del calendario ---
pedir POST "$CAL" "{\"plan_sanitario_id\":16,\"fecha_programada\":\"$MANIANA_CAL\"}"
esperar "Se agrega el refuerzo anual" 200 '"nombre":"Leucemia felina (refuerzo anual)"'
REFUERZO=$(evento_sin_dar 'Leucemia felina (refuerzo anual)')
pedir DELETE "$CAL/${REFUERZO:-0}"
esperar "  y se quita" 200 '"eventos":['
pedir POST "$CAL" "{\"plan_sanitario_id\":16,\"fecha_programada\":\"$MANIANA_CAL\"}"
esperar "  (ya no estaba: se puede volver a agregar)" 200 '"nombre":"Leucemia felina (refuerzo anual)"'
pedir DELETE "$CAL/999999999"
esperar "Quitar un evento que no es de la mascota da 404" 404

# --- Los motivos nuevos ---
pedir POST /api/pacientes/turnos "{\"mascota_id\":102,\"fecha\":\"$MANIANA_CAL\",\"hora\":\"17:30\",\"motivo\":\"CASTRACION\"}"
esperar "Se saca un turno de castración (no pide nada del calendario)" 201 '"motivo":"CASTRACION"'
esperar "  y no queda atado al calendario" 201 '"evento_sanitario":null'

# --- El insumo dice qué vacuna es ---
pedir GET /api/inventario/insumos/106
esperar "El insumo de la antirrábica dice su aplicación" 200 '"aplicacion":"ANTIRRABICA"'
pedir PUT /api/inventario/insumos/101 '{"nombre":"Jeringa descartable 3 ml","costo":150,"aplicacion":"PELUQUERIA"}'
esperar "Una aplicación que no es de la lista da 400" 400 '"aplicacion"'
cerrar_sesion
