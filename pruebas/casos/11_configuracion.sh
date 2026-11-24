# shellcheck shell=bash
# Configuración de la veterinaria (Entrega 5, rol 3). Contrato: docs/api/contrato.md de Backend,
# sección "Configuración". Cambia el horario de los turnos y el límite de stock bajo, prueba que
# Pacientes y Reportes los usen y, al final, los vuelve a los valores por defecto (se borran las filas).

cerrar_sesion
pedir GET /api/configuracion
esperar "Sin sesión no se ve la configuración (401)" 401
pedir GET /api/pacientes/horario
esperar "El horario de atención es público (lo muestra la portada)" 200 '"apertura":'
pedir GET /api/configuracion/contacto
esperar "Los datos de la veterinaria son públicos (los muestra el pie de todas las páginas)" 200 '"enlaces":{"telefono":"tel:+54'

es_entorno_de_prueba || return 0

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/configuracion
esperar "Un cliente no ve la configuración (403)" 403
pedir PUT /api/configuracion '{"valores":{"hora_apertura":"09:00"}}'
esperar "Un cliente no la cambia (403)" 403

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'

# Se parte de los valores por defecto (en dev alguien pudo haberlos cambiado desde el panel).
VALORES_POR_DEFECTO='{"valores":{"hora_apertura":"08:00","hora_cierre":"20:00","hora_apertura_2":"","hora_cierre_2":"","dias_aviso_vacuna":7,"dias_control_adopcion_1":30,"dias_control_adopcion_2":90,"limite_stock_bajo":10,"dias_liquidar":30}}'
pedir PUT /api/configuracion "$VALORES_POR_DEFECTO"
esperar "La veterinaria vuelve todo a los valores por defecto" 200 '"parametros":['

pedir GET /api/configuracion
esperar "Ve los parámetros con su nombre" 200 '"nombre":"Primer horario: desde"'
esperar "Con su valor y su valor por defecto" 200 '"defecto":"08:00","valor":"08:00","modificado":false'

CSRF_REAL=$CSRF; CSRF="no-es-el-token"
pedir PUT /api/configuracion '{"valores":{"hora_apertura":"09:00"}}'
esperar "Cambiarla sin el token CSRF correcto da 403" 403
CSRF=$CSRF_REAL

pedir PUT /api/configuracion '{"valores":{"hora_cierre":"07:30"}}'
esperar "Un cierre antes de la apertura da 400 en ese campo" 400 '"hora_cierre":"El cierre tiene que ser después de la apertura"'
pedir PUT /api/configuracion '{"valores":{"dias_aviso_vacuna":0}}'
esperar "Un número fuera de rango da 400" 400 '"dias_aviso_vacuna":"Tiene que ser un número entero entre 1 y 30"'
pedir PUT /api/configuracion '{"valores":{"no_existe":1}}'
esperar "Un parámetro que no existe da 400" 400 '"no_existe"'
pedir PUT /api/configuracion '{}'
esperar "Sin valores da 400" 400 '"valores"'
pedir PUT /api/configuracion '{"valores":{"hora_apertura":"09:00","dias_liquidar":0}}'
esperar "Si uno está mal no se guarda ninguno (400)" 400 '"dias_liquidar"'
pedir GET /api/pacientes/horario
esperar "Y el horario sigue igual" 200 '"apertura":"08:00"'

pedir PUT /api/configuracion '{"valores":{"hora_apertura":"09:00","limite_stock_bajo":3}}'
esperar "La veterinaria abre a las 9 y baja el límite de stock" 200 '"valor":"09:00","modificado":true'
esperar "Y queda quién lo cambió" 200 '"actualizado_por":"'

# Pacientes usa el horario nuevo.
pedir GET /api/pacientes/horario
esperar "El horario de atención ahora empieza a las 9" 200 '"apertura":"09:00","cierre":"20:00"'
MANIANA=$(date -d '+1 day' +%F)
pedir POST /api/pacientes/turnos "{\"mascota_id\":101,\"fecha\":\"$MANIANA\",\"hora\":\"08:30\",\"motivo\":\"CONSULTA\"}"
esperar "Un turno a las 8:30 ya no se puede dar" 400 'El horario de atención es de 09:00 a 20:00'

# Horario cortado: de 9 a 13 y de 16 a 19 (y de vuelta a 9 a 20 al final, con el resto).
pedir PUT /api/configuracion '{"valores":{"hora_cierre":"19:00","hora_apertura_2":"16:00"}}'
esperar "El segundo horario va con sus dos horas (400)" 400 '"hora_cierre_2":"Completá las dos horas'
pedir PUT /api/configuracion '{"valores":{"hora_cierre":"13:00","hora_apertura_2":"16:00","hora_cierre_2":"19:00"}}'
esperar "La veterinaria corta el horario: de 9 a 13 y de 16 a 19" 200 '"clave":"hora_apertura_2"'
pedir GET /api/pacientes/horario
esperar "El horario público trae las dos franjas" 200 '"franjas":[{"apertura":"09:00","cierre":"13:00"},{"apertura":"16:00","cierre":"19:00"}]'
pedir POST /api/pacientes/turnos "{\"mascota_id\":101,\"fecha\":\"$MANIANA\",\"hora\":\"14:00\",\"motivo\":\"CONSULTA\"}"
esperar "Un turno en el corte del mediodía no se puede dar" 400 'El horario de atención es de 09:00 a 13:00 y de 16:00 a 19:00'
pedir PUT /api/configuracion '{"valores":{"hora_apertura":"00:00","hora_cierre":"23:59","hora_apertura_2":"","hora_cierre_2":""}}'
esperar "Y se puede atender las 24 horas" 200 '"valor":"23:59"'

# Reportes usa el límite de stock nuevo.
pedir GET /api/reportes/stock
esperar "El reporte de stock usa el límite nuevo" 200 '"limite_stock_bajo":3'

# Se deja todo como estaba.
pedir PUT /api/configuracion "$VALORES_POR_DEFECTO"
esperar "Volver a los valores por defecto los deja sin modificar" 200 '"defecto":"08:00","valor":"08:00","modificado":false'
pedir GET /api/pacientes/horario
esperar "El horario vuelve a ser de 8 a 20" 200 '"apertura":"08:00","cierre":"20:00"'
pedir GET /api/reportes/stock
esperar "Y el límite de stock, 10" 200 '"limite_stock_bajo":10'

# Datos de la veterinaria: los carga en Configuración y los ve cualquiera, sin sesión.
pedir PUT /api/configuracion '{"valores":{"whatsapp":"2323 555-555","instagram":"https://www.instagram.com/huellavet"}}'
esperar "La veterinaria carga su WhatsApp y su Instagram" 200 '"clave":"instagram"'
pedir PUT /api/configuracion '{"valores":{"facebook":"https://www.instagram.com/huellavet","telefono":"123"}}'
esperar "Una red con un enlace de otro sitio da 400 en ese campo" 400 '"campos":{"facebook":"Tiene que ser un enlace https de facebook.com'
esperar "  y un teléfono que no es, en el suyo" 400 '"telefono":"El teléfono no es válido'
cerrar_sesion
pedir GET /api/configuracion/contacto
esperar "Sin sesión se ve el WhatsApp nuevo, con su enlace armado" 200 'wa.me\/5492323555555"'
esperar "  y el Instagram" 200 '"instagram":"https:\/\/www.instagram.com\/huellavet"'
esperar "  y lo no cargado va vacío (no se muestra)" 200 '"facebook":null'
iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir PUT /api/configuracion '{"valores":{"whatsapp":"+1 555 145 9000"}}'
esperar "El WhatsApp puede ser de otro país, con + y su código (el número de prueba de Meta)" 200 '"valor":"+1 555 145 9000"'
pedir GET /api/configuracion/contacto
esperar "  y el enlace va con ese número, sin el 9 de los celulares argentinos" 200 'wa.me\/15551459000"'
pedir PUT /api/configuracion '{"valores":{"whatsapp":"11 3901-0486","instagram":""}}'
esperar "Vuelven a como estaban" 200 '"clave":"instagram"'
