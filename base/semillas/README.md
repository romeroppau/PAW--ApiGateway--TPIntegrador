# Datos semilla

Datos **de prueba** para local, CI y dev. **Nunca se cargan en producción**: `base/sembrar.php`
solo corre con `ENTORNO=local`, `dev` o `ci`.

## Cómo se cargan

Desde la carpeta del Gateway, después del migrador:

    # local (solo si tu .env apunta a un MySQL local)
    docker compose --profile tools run --rm --build sembrador

    # dev (con el .env de dev y el ca.pem de Aiven dev, igual que el migrador)
    docker compose --env-file .env.aiven-dev --profile tools run --rm --build sembrador

Se pueden correr todas las veces que haga falta: vuelven a dejar los datos de prueba como estaban.

## Cuentas de prueba

Son de prueba y no existen en producción, por eso las contraseñas están acá.

| Id | Rol | Email | Contraseña |
|---|---|---|---|
| 101 | Veterinario | `vet@prueba.huellavet` | `Vet-Prueba-2026` |
| 102 | Cliente | `cliente@prueba.huellavet` | `Cliente-Prueba-2026` |
| 103 | Cliente | `cliente2@prueba.huellavet` | `Cliente-Prueba-2026` |
| 104 | Rescatista (aprobado) | `rescatista@prueba.huellavet` | `Rescatista-Prueba-2026` |
| 105 | Rescatista (pendiente) | `rescatista2@prueba.huellavet` | `Rescatista-Prueba-2026` |

## Productos

Ids 101 a 115: de las tres categorías y las tres especies. El 104 no tiene stock y el 107
vence en 20 días (la fecha se calcula desde hoy cada vez que se cargan las semillas).

## Insumos

| Id | Insumo | Stock | Costo | Estado |
|---|---|---|---|---|
| 101 | Jeringa descartable 3 ml | 200 | $150 | Disponible |
| 102 | Guantes de látex (par) | 150 | $220 | Disponible |
| 103 | Gasa estéril 10 x 10 | 100 | $180 | Disponible |
| 104 | Vacuna séxtuple canina (dosis) | 25 | $6.500 | Disponible |
| 105 | Vacuna triple felina (dosis) | 20 | $7.200 | Disponible |
| 106 | Vacuna antirrábica (dosis) | 30 | $3.800 | Disponible |
| 107 | Sutura absorbible 3-0 | 0 | $2.500 | En falta (sin stock, para probar ese error) |
| 108 | Solución fisiológica 500 ml | 3 | $1.900 | Disponible (stock bajo: 10 o menos) |
| 109 | Venda elástica 5 cm | 10 | $900 | Dado de baja (no aparece en los listados) |

## Mascotas

| Id | Nombre | Especie | Dueño | Edad |
|---|---|---|---|---|
| 101 | Firulais | Perro | 102 (`cliente@`) | 3 años |
| 102 | Michi | Gato | 102 (`cliente@`) | 5 años |
| 103 | Luna | Perro | 103 (`cliente2@`) | 10 semanas (cachorra) |
| 104 | Tom | Gato | 103 (`cliente2@`) | 2 años |

## Turnos

Todos con la veterinaria 101 (`vet@prueba.huellavet`). "Hoy" es la fecha de Argentina.

| Id | Cuándo | Mascota | Motivo | Estado | Para qué |
|---|---|---|---|---|---|
| 101 | Hoy, 8:00 | 101 Firulais | Consulta | Programado | La consulta (rol 4): el caso que tiene que funcionar |
| 102 | Hoy, 8:30 | 103 Luna | Vacunación | Programado | Otra consulta, o un caso de error. Al ser vacunación, también prueba el calendario |
| 103 | Mañana, 8:00 | 102 Michi | Consulta | Programado | No se puede atender un turno que no es de hoy |
| 104 | Ayer, 8:00 | 104 Tom | Consulta | Atendido | No se puede atender un turno ya atendido |

Volver a cargar las semillas deja los turnos como en la tabla, aunque se hayan atendido o cancelado.
No cargues a mano turnos de la veterinaria 101 a las 8:00 o 8:30 de esos días: chocarían con estos.

## Calendario sanitario

El plan de vacunas (`plan_sanitario`) no es una semilla: lo carga la migración 005, porque también
hace falta en producción. Estos son algunos eventos de las mascotas de prueba:

| Id | Mascota | Evento | Programado | Estado |
|---|---|---|---|---|
| 101 | Firulais | Séxtuple (refuerzo anual) | Hace 2 semanas | **Vencido** (no tiene las vacunas al día) |
| 102 | Firulais | Antirrábica | En 1 mes | Pendiente |
| 103 | Michi | Desparasitación interna | Hace 1 mes | Aplicado |
| 104 | Michi | Triple felina (refuerzo anual) | En 3 meses | Pendiente |
| 105 | Luna | Séxtuple (1.ª dosis) | Hace 4 semanas | Aplicado |
| 106 | Luna | Séxtuple (2.ª dosis) | Hace 1 semana | Pendiente: **se aplica en el turno 102 de hoy** |
| 107 | Luna | Séxtuple (3.ª dosis) | En 2 semanas | Pendiente |
| 108 | Luna | Antirrábica | En 6 semanas | Pendiente |
| 109 | Tom | Antirrábica | En 2 meses | Pendiente |

## Consultas

| Id | Turno | Mascota | Estado | Factura |
|---|---|---|---|---|
| 101 | 104 (ayer) | Tom | Finalizada: otitis externa leve | `C-000101`, $24.420 (base $15.000 + insumos $520 + productos $8.900), pagada |

Volver a cargar las semillas **borra las consultas de los turnos 101, 102 y 103** (las que se
hicieron al probar), con sus ítems y su factura, y deja pendiente la vacuna que se haya aplicado
en ellas. Así esos turnos se pueden atender de nuevo. Las consultas de prueba no mueven el stock:
lo vuelven a dejar las semillas de productos e insumos.

## Reglas para agregar semillas

- Un archivo por tema: `NNN_tema.sql`, en orden.
- Ids fijos desde 101 e `INSERT ... ON DUPLICATE KEY UPDATE`.
- Fechas relativas a hoy (`CURDATE()`), así nunca quedan viejas. Si importa el día exacto (como
  en los turnos "de hoy"), usar la fecha de Argentina: `DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR)`.
- Mails `@prueba.huellavet` y contraseñas hasheadas con bcrypt.
