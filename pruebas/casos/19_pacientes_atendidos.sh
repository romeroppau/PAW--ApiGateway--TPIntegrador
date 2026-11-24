# shellcheck shell=bash
# Pacientes atendidos ("Historial clínico" de la veterinaria): las mascotas con consultas finalizadas,
# con su dueño, cuántas consultas tuvieron y la última. Contrato: docs/api/contrato-consultas.md de
# Pacientes ("Pacientes atendidos"). Usa la consulta finalizada de Tom (semilla 006).
es_entorno_de_prueba || return 0

pedir GET /api/pacientes/atendidos
esperar "Los pacientes atendidos piden sesión (401)" 401

iniciar_sesion cliente@prueba.huellavet 'Cliente-Prueba-2026'
pedir GET /api/pacientes/atendidos
esperar "Un cliente no ve la lista de pacientes (403)" 403
cerrar_sesion

iniciar_sesion vet@prueba.huellavet 'Vet-Prueba-2026'
pedir GET /api/pacientes/atendidos
esperar "La veterinaria ve los pacientes atendidos, de a 20" 200 '"por_pagina":20'
esperar "  con la mascota y su dueño" 200 '"mascota":{"id":104,"nombre":"Tom"'
esperar "  y la última consulta" 200 '"ultima_consulta":{"fecha":"'
pedir GET '/api/pacientes/atendidos?buscar=tom'
esperar "Busca por el nombre de la mascota" 200 '"nombre":"Tom"'
pedir GET '/api/pacientes/atendidos?buscar=Aguirre'
esperar "Busca por el nombre del dueño (el cliente 103, Tomás Aguirre)" 200 '"duenio":{"id":103,'
pedir GET '/api/pacientes/atendidos?buscar=%25'
esperar "Un % se busca como letra, no trae todo" 200 '"datos":[]'
pedir GET '/api/pacientes/atendidos?pagina=0'
esperar "Una página 0 da 400" 400
pedir GET /api/pacientes/mascotas/104/historial
esperar "Y el historial de cada uno, con sus consultas" 200 '"consultas":[{"id":'
cerrar_sesion
