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

## Reglas para agregar semillas

- Un archivo por tema: `NNN_tema.sql`, en orden.
- Ids fijos desde 101 e `INSERT ... ON DUPLICATE KEY UPDATE`.
- Fechas relativas a hoy (`CURDATE()`), así nunca quedan viejas. Si importa el día exacto (como
  en los turnos "de hoy"), usar la fecha de Argentina: `DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR)`.
- Mails `@prueba.huellavet` y contraseñas hasheadas con bcrypt.
