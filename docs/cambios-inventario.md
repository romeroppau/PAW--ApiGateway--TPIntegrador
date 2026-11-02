# Cambios en ApiGateway para el módulo Inventario

Qué se modificó en este repo para sumar el módulo Inventario (productos, stock y movimientos). El contrato de los endpoints está en el repo Inventario: [docs/api/contrato.md](https://github.com/romeroppau/PAW--Inventario--TPIntegrador/blob/main/docs/api/contrato.md).

Para desplegarlo en producción, ver [despliegue-inventario.md](./despliegue-inventario.md).

## Archivos

| Archivo | Cambio |
|---|---|
| `base/002_inventario_producto.sql` | **Nuevo.** Migración que crea las tablas `producto` y `movimiento_inventario`, según el DER |
| `base/permisos.sql` | Permisos del usuario `inventario` sobre sus tablas (desde la Entrega 4: `base/permisos/002_inventario_producto.sql`) |
| `docker/iniciar.sh` | Se descomentó el bloque que levanta el módulo Inventario en el puerto 9002 |
| `docker/nginx.conf` | `client_max_body_size 2m` en `/api/inventario/`, para las imágenes |
| `Inventario` (submódulo) | Apunta al commit con el código del módulo |
| `.gitattributes` | **Nuevo.** Los `.sh` siempre con finales de línea LF |

## Detalle

### Migración 002

- `producto`: todas las columnas del DER. `etapa_vida` tiene `TODAS` por defecto y `huellitas` y `peso_kg` aceptan `NULL`, porque todavía no se usan (llegan con Huellitas y el motor de recomendaciones). La imagen se guarda en la base (`imagen MEDIUMBLOB` + `imagen_tipo`).
- `movimiento_inventario`: claves foráneas a `producto` y a `usuario`. La tabla `insumo` todavía no existe (se usa con las consultas del módulo Pacientes), así que `insumo_id` queda sin clave foránea por ahora. Un `CHECK` exige que cada movimiento tenga un producto o un insumo.

### Permisos del usuario `inventario`

| Tabla | Permisos | Por qué |
|---|---|---|
| `producto` | `SELECT, INSERT, UPDATE` | Sin `DELETE`: la baja de un producto es lógica (`activo = 0`) |
| `movimiento_inventario` | `SELECT, INSERT` | El historial de stock no se modifica ni se borra |
| `usuario` | `SELECT` (ya estaba) | Para mostrar quién registró cada movimiento |

### `iniciar.sh`

Inventario corre como un proceso PHP más dentro del contenedor, en `127.0.0.1:9002`, con su propio usuario de MySQL (`INVENTARIO_DB_USER` / `INVENTARIO_DB_PASSWORD`) y **sin** la clave privada del JWT: solo verifica sesiones, no las crea. Nginx ya derivaba `/api/inventario/` y `/api/tienda/` a ese puerto.

### `nginx.conf`

Nginx acepta por defecto pedidos de hasta 1 MB. Las imágenes de los productos (hasta 1 MB) viajan en base64 dentro del JSON y ocupan alrededor de 1,4 MB, así que en `/api/inventario/` el límite pasa a 2 MB. El tamaño real de la imagen lo controla el módulo.

### `.gitattributes`

Con `core.autocrlf=true` (lo habitual en Windows), Git convierte los finales de línea de `iniciar.sh` a CRLF al clonar, y el script falla dentro del contenedor Linux (`set: Illegal option -`). El `.gitattributes` fuerza LF en los `.sh`.

## Desarrollo local

El `.env.example` no cambió: `INVENTARIO_DB_USER` e `INVENTARIO_DB_PASSWORD` ya estaban. Para probar localmente, la migración se corre con el migrador como siempre (`docker compose --profile tools run --rm migrator`) y el módulo responde en:

```bash
curl http://localhost:10000/api/inventario/salud
```
