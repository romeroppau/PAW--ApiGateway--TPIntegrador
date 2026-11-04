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

## Reglas para agregar semillas

- Un archivo por tema: `NNN_tema.sql`, en orden.
- Ids fijos desde 101 e `INSERT ... ON DUPLICATE KEY UPDATE`.
- Fechas relativas a hoy (`CURDATE()`), así nunca quedan viejas.
- Mails `@prueba.huellavet` y contraseñas hasheadas con bcrypt.
