# shellcheck shell=bash
# Casos del motor de recomendaciones y avisos (Entrega 5, rol 4).
# Contrato: docs/api/contrato-reportes.md del repo Reportes, sección 2 ("POST /api/reportes/tareas/diaria").
# Semillas:
#   - 009_reportes.sql: vacuna próxima 951 (Simba, cliente 103, en 3 días) y producto 101 (vence en 7 días, 30 %).
#   - 005_calendario.sql: vacuna vencida 101 (Firulais, cliente 102).
#   - 007_adopciones.sql: adopción 103 (Simba, cliente 103, finalizada hace exactamente 30 días).
#   - 002_productos.sql / 003_insumos.sql: productos e insumos con stock <= 10 y producto 107 (vence en 20 días, 15 %).

# --- Autorización del endpoint de la tarea diaria (también corre en solo lectura) ---
cerrar_sesion
pedir POST /api/reportes/tareas/diaria
esperar "La tarea diaria del motor sin X-Tarea-Token da 401" 401

CODIGO=$(curl --silent --max-time 60 -o /dev/null -w '%{http_code}' -X POST \
  -H 'X-Tarea-Token: token-incorrecto' "$BASE_URL/api/reportes/tareas/diaria")
RESPUESTA=""
esperar "La tarea diaria del motor con un X-Tarea-Token inválido da 401" 401

es_entorno_de_prueba || return 0

if [ -z "${TAREAS_TOKEN:-}" ]; then
  echo "  (sin TAREAS_TOKEN: no se prueba la ejecución de la tarea diaria del motor)"
  return 0
fi

# --- 1.ª corrida: el motor evalúa las 5 reglas y manda los avisos a Backend ---
SALIDA=$(curl --silent --max-time 60 -w '\n%{http_code}' -X POST \
  -H "X-Tarea-Token: $TAREAS_TOKEN" "$BASE_URL/api/reportes/tareas/diaria")
CODIGO=$(printf '%s' "$SALIDA" | tail -n1)
RESPUESTA=$(printf '%s' "$SALIDA" | sed '$d')

esperar "La tarea diaria del motor con su token corre y devuelve el resumen" 200 '"generados":'
esperar "  sin avisos fallidos" 200 '"fallidos":0'
esperar "  con el detalle de cada regla" 200 '"detalle":{"vacuna_proxima":'

# --- Los avisos generados por el motor llegan a la campana de cada destinatario ---
iniciar_sesion cliente2@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/notificaciones
esperar "Al cliente 103 le llega el aviso de vacuna próxima de Simba" 200 'A Simba le toca la vacuna Antirrábica'
esperar "  y el control de los 30 días de la adopción de Simba" 200 'Se cumplen 30 días de la adopción de Simba'
cerrar_sesion

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/notificaciones
esperar "Al cliente 102 le llega el aviso de la vacuna vencida de Firulais" 200 'La vacuna Séxtuple (refuerzo anual) de Firulais está vencida'
cerrar_sesion

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/notificaciones
esperar "A la veterinaria le llega el aviso de stock bajo" 200 'Stock bajo para '
esperar "  y el aviso de qué liquidar con su descuento sugerido" 200 'Descuento sugerido: 30%'
cerrar_sesion

# --- 2.ª corrida el mismo día: idempotencia por id_operacion ---
SALIDA=$(curl --silent --max-time 60 -w '\n%{http_code}' -X POST \
  -H "X-Tarea-Token: $TAREAS_TOKEN" "$BASE_URL/api/reportes/tareas/diaria")
CODIGO=$(printf '%s' "$SALIDA" | tail -n1)
RESPUESTA=$(printf '%s' "$SALIDA" | sed '$d')

esperar "Correr la tarea diaria por segunda vez el mismo día no repite avisos" 200 '"aplicados":0'
esperar "  y tampoco falla ninguno" 200 '"fallidos":0'
