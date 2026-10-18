# Despliegue del módulo Inventario en producción

Qué hay que hacer en **Aiven** y en **Render** para que el módulo Inventario funcione en producción. El código ya está en los repos; esto es lo que no se puede hacer con un commit porque necesita las credenciales de producción.

Los cambios de código están explicados en [cambios-inventario.md](./cambios-inventario.md).

## Resumen

| # | Dónde | Qué |
|---|---|---|
| 1 | Render | Agregar las variables `INVENTARIO_DB_USER` e `INVENTARIO_DB_PASSWORD` |
| 2 | Aiven (desde tu máquina) | Correr el migrador: crea las tablas de Inventario y el usuario `inventario` de MySQL |
| 3 | Render | Desplegar el último commit de `main` (con el submódulo Inventario actualizado) |
| 4 | Navegador | Comprobar que funciona |

## 1. Variables de entorno en Render

En el servicio del ApiGateway: **Environment → Add Environment Variable**.

| Variable | Valor |
|---|---|
| `INVENTARIO_DB_USER` | `inventario` |
| `INVENTARIO_DB_PASSWORD` | Una contraseña nueva y larga. Por ejemplo, generada con `openssl rand -hex 24` |

`iniciar.sh` usa estas dos variables para conectar el módulo Inventario con su propio usuario de MySQL. **Hay que cargarlas antes de desplegar:** si faltan, `set -u` corta todo `iniciar.sh` y no arranca **ningún** módulo, tampoco Backend (se cae el login).

Las demás variables (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_SSL_CA`, `JWT_PUBLIC_KEY`, etc.) ya existen y no cambian.

## 2. Migración contra Aiven

Crea las tablas `producto` y `movimiento_inventario` (`base/002_inventario_producto.sql`), crea el usuario `inventario` de MySQL con la contraseña del paso 1 y le da sus permisos (`base/permisos.sql`).

Se corre igual que cuando se creó la tabla `usuario`: desde la carpeta del ApiGateway, con el `.env` que apunta a Aiven y el `ca.pem` de Aiven.

1. Traer los cambios: `git pull` y `git submodule update --init`.
2. En el `.env` de Aiven, agregar o actualizar:

   ```
   INVENTARIO_DB_USER=inventario
   INVENTARIO_DB_PASSWORD=<la misma contraseña que pusiste en Render>
   ```

3. Correr el migrador:

   ```bash
   docker compose --profile tools run --rm migrator
   ```

   Tiene que mostrar:

   ```
   Ya aplicada: 001_backend_usuario.sql
   Aplicada: 002_inventario_producto.sql
   Migraciones y permisos listos para ...

   Permisos de inventario:
     GRANT SELECT, INSERT ON `...`.`movimiento_inventario` TO `inventario`@`%`
     GRANT SELECT, INSERT, UPDATE ON `...`.`producto` TO `inventario`@`%`
     GRANT SELECT ON `...`.`usuario` TO `inventario`@`%`
   ```

> **Importante — contraseñas:** el migrador, cada vez que corre, le **vuelve a asignar** la contraseña a los usuarios `backend` e `inventario` (`ALTER USER`) con los valores del `.env`.
> - `BACKEND_DB_PASSWORD` del `.env` tiene que ser **la misma que está en Render**. Si es distinta, Backend deja de poder conectarse y se cae el login.
> - `INVENTARIO_DB_PASSWORD` tiene que ser la misma que cargaste en Render en el paso 1.

## 3. Desplegar en Render

El commit de `main` del ApiGateway ya incluye el submódulo `Inventario` apuntando al código nuevo. Si Render no desplegó solo, **Manual Deploy → Deploy latest commit**.

En los logs del build se tiene que ver que copia `Inventario/` con contenido (Render clona los submódulos al construir, igual que con `Backend/`).

## 4. Comprobar

Reemplazar `<front>` por la URL de Vercel (que reenvía `/api/` a Render):

| Prueba | Resultado esperado |
|---|---|
| `https://<front>/api/inventario/salud` | `{"estado":"funciona","modulo":"Inventario"}` |
| `https://<front>/api/tienda/productos` | `{"datos":[],"pagina":1,"por_pagina":12,"total":0}` (vacío hasta que se carguen productos) |
| Entrar como veterinario → Panel → ABM de productos → Nuevo producto | Se crea y aparece en el listado y en el catálogo |

### Si algo falla

| Síntoma | Causa probable |
|---|---|
| Todo el sitio responde `502` (también el login) | Falta una variable del paso 1: `iniciar.sh` se corta y no arranca nada. Revisar los logs de Render |
| `502 Bad Gateway` solo en `/api/inventario/...` | El proceso de Inventario no arrancó: `Inventario/` llegó vacío (submódulo sin clonar) o hay un error de PHP. Revisar los logs de Render |
| `/api/inventario/salud` responde `503` | Inventario arrancó pero no se conecta a la base: la contraseña de Render no coincide con la del migrador, o no se corrió el paso 2 |
| `500` al listar o crear productos | No se corrió la migración: faltan las tablas |
| El login de Backend deja de funcionar después de migrar | Se corrió el migrador con un `BACKEND_DB_PASSWORD` distinto al de Render (ver el recuadro del paso 2) |
| `413` al guardar un producto con imagen | Nginx no tomó el `client_max_body_size 2m` nuevo: el deploy no tiene el último `nginx.conf` |
