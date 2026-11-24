# Datos en cantidad (volumen)

Un juego de datos **grande y con fechas viejas**, para ver cómo escalan las pantallas (paginación,
filtros, reportes) y para que aparezcan los avisos del motor (vacunas, controles de adopción).
Lo pidió el profesor después de la demo (19/11).

Va **aparte** de `base/semillas/` porque la prueba de humo depende de que las semillas comunes
sean exactamente esas. Por eso:

- **Solo se carga a mano**, en local o en dev. `base/sembrar.php volumen` se niega en el CI y en
  producción.
- **Se carga después de las semillas comunes** (usa sus usuarios, productos e insumos).
- Con el volumen cargado, la prueba de humo pasa salvo un caso: el de `12_reportes.sh` que cuenta
  exactamente los turnos de una franja ("Lunes a la mañana: 2"), porque el volumen suma turnos
  (probado el 21/11: 490 de 491).

## Cómo se carga

Desde la carpeta del Gateway, con Docker Desktop abierto. Igual que el sembrador común, pero con el
servicio `sembrador-volumen`:

    # local (solo si tu .env apunta a un MySQL local)
    docker compose --profile tools run --rm --build sembrador
    docker compose --profile tools run --rm --build sembrador-volumen

    # dev (con el .env de dev y el ca.pem de Aiven dev, igual que el migrador)
    docker compose --env-file .env.aiven-dev --profile tools run --rm --build sembrador
    docker compose --env-file .env.aiven-dev --profile tools run --rm --build sembrador-volumen

Se puede correr todas las veces que haga falta: vuelve a dejar los datos como estaban y corre las
fechas a hoy (los "hace 30 días" siempre son hace 30 días).

## Qué carga

Cada tabla usa un **rango de ids fijo**. Después de la primera carga, la base numera las filas
nuevas por encima de esos rangos, así que una recarga nunca toca lo que se cargó a mano en dev.
Lo que se haya hecho al probar *sobre* los datos del volumen (atender uno de sus turnos, postularse
a una de sus adopciones) se deshace al recargar.

| Archivo | Qué | Ids | Para probar |
|---|---|---|---|
| 001 | Veterinario Dos, 40 clientes y 5 rescatistas aprobados (`@volumen.huellavet`, sin teléfono) | 2001 a 2046 | Búsquedas, listas largas |
| 001 | 80 mascotas de los clientes, 2 más del cliente de prueba 102, 40 de los rescatistas | 20001 a 20082, 20101 a 20140 | Mis mascotas, adopciones |
| 002 | 30 productos: 10 por vencer, 8 con stock bajo, 12 normales; 180 cargas de stock | 2001 a 2030 | Qué liquidar y Publicitar, stock bajo, Movimientos |
| 003 | 760 turnos: 4 por día desde hace 180 días hasta dentro de 9, con el Veterinario Dos; los lunes a la tarde quedan cancelados (la franja sin turnos, que el motor sugiere promocionar) | 20001 a 20760 | Agenda, Mis turnos, Turnos atendidos, sugerencia y promoción de franjas |
| 003 | Consulta y factura de cada turno atendido (C-020001...) | igual que su turno | Historial, facturas |
| 003 | 30 vacunas antirrábicas sin aplicar, para los próximos 0 a 9 días | 20001 a 20030 | Aviso de vacuna próxima |
| 004 | 40 publicaciones y adopciones en todos los estados, 83 postulaciones | 20001 a 20040 | Pestañas de adopciones, moderación, mis postulaciones |
| 004 | 12 adopciones finalizadas: 2 hace exactamente 30 días y 2 hace 90 | (turnos de chequeo 20801 a 20840) | Controles de adopción del motor |
| 005 | 150 compras (30 del cliente de prueba 102): pagadas, entregadas y canceladas | 20001 a 20150 (V-020001...) | Mis compras de a 20, Ventas con filtros, facturas |
| 006 | 200 avisos web, mitad para la veterinaria 101 y mitad para el cliente 102; los 12 más nuevos sin leer | 20001 a 20200 | La campana y su paginación |
| 007 | Fotos de las 122 mascotas: 7 de perro y 6 de gato (Unsplash), rotando por especie | las mascotas de 001 | Listas de mascotas y la ficha de la mascota con foto |

## Cuentas

Las contraseñas son las mismas que las de las cuentas de prueba del mismo rol
(`base/semillas/README.md`):

| Cuenta | Contraseña |
|---|---|
| `vet2@volumen.huellavet` | `Vet-Prueba-2026` |
| `cliente01@volumen.huellavet` a `cliente40@volumen.huellavet` | `Cliente-Prueba-2026` |
| `rescatista1@volumen.huellavet` a `rescatista5@volumen.huellavet` | `Rescatista-Prueba-2026` |

Para recorrer las pantallas alcanza con las cuentas de prueba de siempre: la veterinaria 101 ve
todo el volumen (agenda, reportes, adopciones, ventas) y el cliente 102 tiene mascotas, turnos,
compras, postulaciones y avisos del volumen.

## Cuidados

- **Aiven exige clave primaria** en toda tabla nueva, también en las temporales
  (`sql_require_primary_key=ON`). Por eso las tablas temporales de 004 y 005 se crean con su clave
  primaria y se llenan después. Para probarlo en local: `SET GLOBAL sql_require_primary_key = ON;`
  en el MySQL de Docker antes de cargar.

- **Nunca en producción.** Las semillas no se cargan ahí (`sembrar.php` se niega).
- Los usuarios del volumen **no tienen teléfono**: los avisos del motor para ellos quedan en la web
  y nunca salen por WhatsApp a un número inventado.
- Las compras del volumen no mueven el stock (lo deja la semilla 002), pero sí dejan su movimiento
  de venta, para los reportes.
- Si se agrega una tabla, usar un rango de ids nuevo, `INSERT ... ON DUPLICATE KEY UPDATE` y fechas
  relativas a hoy en hora de Argentina (`DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR)`).
