# PAW--ApiGateway--TPIntegrador
# HuellaVet — API Gateway

API Gateway es el punto de entrada HTTP de HuellaVet. Recibe las solicitudes del Frontend y, mediante Nginx, las deriva al módulo responsable. El Gateway centraliza la infraestructura común, pero no reemplaza la lógica de negocio de Backend ni de Inventario.

## Objetivo y alcance de este repositorio

Este repositorio reúne la configuración que permite ejecutar e integrar los módulos PHP:

- **Nginx:** recibe las solicitudes y las deriva según el prefijo de la ruta.
- **PHP común (`comun/`):** ofrece herramientas compartidas para leer pedidos, responder JSON, leer variables de entorno, conectarse a MySQL, validar datos y registrar errores.
- **Backend:** gestiona el registro y el inicio/cierre de sesión, los datos del usuario actual y la creación inicial de la cuenta de veterinario.
- **Inventario:** es responsable del ABM de productos, el stock y los endpoints del catálogo. Su disponibilidad depende de que el módulo y su proceso estén integrados y levantados.
- **Base de datos:** las migraciones de `base/` crean la estructura y asignan permisos a las cuentas de los módulos.

El Gateway define las reglas de enrutamiento; cada módulo implementa sus propias operaciones y controles de autorización.

En el Frontend, `js/api.js` centraliza el uso de `fetch`. `vercel.json` reescribe las solicitudes `/api/...` al servicio público de Render para que el navegador use el mismo origen del sitio.

## Estructura principal

```text
.
├── Backend/                     # Submódulo Git con el código de Backend
├── Inventario/                  # Submódulo Git con el código de Inventario
├── api/CONTRATO_API_ApiGateway.md
├── base/
│   ├── migrar.php               # Ejecuta migraciones SQL y asigna permisos
│   ├── 001_backend_usuario.sql  # Crea la tabla usuario
│   └── permisos.sql             # Permisos por módulo
├── comun/
│   ├── index.php                # Entrada del proceso PHP del Gateway
│   ├── router.php               # Ruteo de endpoints propios del Gateway
│   ├── request.php              # Lectura de la petición HTTP
│   ├── response.php             # Respuestas JSON y códigos HTTP
│   ├── config.php               # Lectura de configuración
│   ├── database.php             # Conexión PDO a MySQL
│   ├── validator.php            # Validaciones reutilizables
│   ├── logger.php               # Registro de eventos y errores
│   └── auth.php                 # Validación de sesión, rol y CSRF compartida
├── docker/
│   ├── iniciar.sh               # Inicia los procesos PHP y Nginx
│   └── nginx.conf               # Rutas y configuración de Nginx
├── Dockerfile                   # Imagen del servicio
├── compose.yaml                 # Servicios para desarrollo local
├── .env.example                 # Plantilla de variables, sin secretos
└── .gitmodules                  # Definición de submódulos
```

Los nombres y la disponibilidad de los endpoints de cada módulo deben coincidir con el contrato de API y con la implementación que esté desplegada.

## Requisitos

- Git.
- Docker Desktop instalado y en ejecución.
- Acceso al repositorio GitHub y a los repositorios usados como submódulos.
- Para la configuración remota: acceso a Aiven, Render y a las credenciales/certificado de la base.

En Windows, iniciar Docker Desktop antes de ejecutar comandos `docker compose`.

## Obtener el proyecto

Clonar el repositorio incluyendo los submódulos:

```bash
git clone --recurse-submodules <URL_DEL_REPOSITORIO_APIGATEWAY>
cd PAW--ApiGateway--TPIntegrador
```

Si ya lo clonaste sin submódulos, desde la raíz del repositorio ejecutá:

```bash
git submodule update --init --recursive
```

Backend e Inventario son repositorios independientes incorporados como submódulos. El repositorio principal guarda la referencia al commit de cada submódulo.

## Configurar las variables de entorno

1. Copiar `.env.example` a `.env` en la raíz del repositorio.
2. Completar los valores para el entorno que se quiera utilizar.
3. No subir `.env`, contraseñas, claves JWT ni certificados privados al repositorio.

Variables principales:

| Variable | Uso |
|---|---|
| `DB_HOST` | Host de MySQL. En la configuración remota, es el hostname de Aiven; no usar `db` para conectarse a Aiven. |
| `DB_PORT` | Puerto de MySQL informado por el proveedor. |
| `DB_NAME` | Base de datos que utiliza la aplicación (por ejemplo, `huellavet`). |
| `DB_SSL_CA` | Ruta **dentro del contenedor** al archivo CA que verifica el servidor MySQL. |
| `BACKEND_DB_USER` / `BACKEND_DB_PASSWORD` | Credenciales de la cuenta limitada usada por Backend. |
| `INVENTARIO_DB_USER` / `INVENTARIO_DB_PASSWORD` | Credenciales de la cuenta de Inventario. |
| `DB_ADMIN_USER` / `DB_ADMIN_PASSWORD` | Cuenta con permisos suficientes para ejecutar las migraciones; no se usa para las peticiones habituales de la API. |
| `JWT_PRIVATE_KEY` | Clave privada que usa Backend para firmar los JWT. No debe compartirse con Gateway ni Inventario. |
| `JWT_PUBLIC_KEY` | Clave pública para verificar firmas JWT en los módulos que la necesiten. |
| `MYSQL_ROOT_PASSWORD`, `LOCAL_DB_NAME`, `MYSQL_HOST_PORT` | Parámetros del MySQL local opcional definido en Compose. |

Ejemplo de variables (no copiar contraseñas reales ni pegar secretos en el README):

```dotenv
PORT=10000
APP_PORT=10000
DB_HOST=<HOST_DE_AIVEN>
DB_PORT=<PUERTO_DE_AIVEN>
DB_NAME=huellavet
DB_SSL_CA=/app/ca.pem
BACKEND_DB_USER=backend
BACKEND_DB_PASSWORD=<CONTRASENA_BACKEND>
INVENTARIO_DB_USER=inventario
INVENTARIO_DB_PASSWORD=<CONTRASENA_INVENTARIO>
DB_ADMIN_USER=avnadmin
DB_ADMIN_PASSWORD=<CONTRASENA_ADMIN_AIVEN>
JWT_PRIVATE_KEY=<CLAVE_PRIVADA_JWT>
JWT_PUBLIC_KEY=<CLAVE_PUBLICA_JWT>
```

### Certificado CA

Para desarrollo local, si `ca.pem` está en la raíz del repositorio y `compose.yaml` lo monta en `/app/ca.pem`, configurá `DB_SSL_CA=/app/ca.pem`. El archivo debe existir y ser legible dentro del contenedor. Mantenelo fuera de Git si el equipo decidió administrarlo localmente; agregalo a `.gitignore`.

En Render, el sistema de archivos del contenedor es distinto al de tu computadora. Si el certificado se entrega como Secret File, configurá `DB_SSL_CA` con la ruta que Render le asigna (por ejemplo `/etc/secrets/ca.pem`). No reutilices una ruta local que solo existe en Windows o en Docker Compose.

## Ejecutar localmente

Desde la raíz del repositorio, con Docker Desktop iniciado:

1. Comprobar que Compose puede interpretar la configuración:

   ```bash
   docker compose config --quiet
   ```

2. Construir la imagen y levantar el servicio:

   ```bash
   docker compose up --build --force-recreate -d
   ```

3. Ver el estado de los servicios:

   ```bash
   docker compose ps
   ```

4. Ver los registros de la aplicación:

   ```bash
   docker compose logs --tail=100 app
   ```

5. Probar la salud del Gateway:

   ```bash
   curl -i http://localhost:10000/api/gateway/salud
   ```

6. Probar la salud del Backend:

   ```bash
   curl -i http://localhost:10000/api/backend/salud
   ```

La respuesta esperada para cada endpoint es HTTP `200 OK` y un JSON que indique que el módulo funciona. El endpoint de salud del Backend intenta además ejecutar `SELECT 1`, por lo que permite comprobar la conectividad de la base configurada.

Para detener los servicios:

```bash
docker compose down
```

Este comando detiene y elimina los contenedores de este proyecto, pero no elimina el volumen de datos nombrado. No agregues `-v` salvo que realmente quieras eliminar los volúmenes asociados.

### MySQL local opcional

`compose.yaml` puede incluir el servicio `db` bajo el perfil `local`. Se inicia con:

```bash
docker compose --profile local up -d db
```

El host `db` solo tiene sentido desde otros contenedores de la misma red de Compose. Para conectar la API con Aiven, utilizá el host y puerto de Aiven en las variables de entorno.

## Migraciones de la base de datos

Las migraciones se ejecutan manualmente cuando hay cambios de esquema; no se ejecutan en cada petición de la API. El script `base/migrar.php`:

- Se conecta usando `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_ADMIN_USER`, `DB_ADMIN_PASSWORD` y `DB_SSL_CA`.
- Crea/consulta la tabla `migracion` para registrar qué archivos `base/NNN_*.sql` ya se aplicaron.
- Ejecuta las migraciones pendientes en orden.
- Aplica los permisos definidos en `base/permisos.sql` y crea/actualiza las cuentas `backend` e `inventario` con las contraseñas indicadas.

Para ejecutar el migrador con el perfil `tools`:

```bash
docker compose --profile tools run --rm migrator
```

**Precaución:** verificá cuidadosamente `DB_HOST`, `DB_NAME` y `DB_ADMIN_USER` antes de ejecutarlo, porque el comando modifica la estructura y los permisos de la base a la que apunten las variables. En la configuración remota, la migración se aplica a Aiven; no asumas que se está usando MySQL local.

Actualmente, `001_backend_usuario.sql` crea la tabla `usuario`. Las tablas de producto y movimientos de Inventario requieren sus propias migraciones y deben comprobarse aparte.

## Crear la cuenta inicial de veterinario

El veterinario se crea mediante `Backend/scripts/crear_veterinario.php`, no a través del formulario público de registro. Con el servicio `app` levantado, desde la raíz del repositorio se puede ejecutar el script pasando las variables que espera:

```bash
docker compose exec app sh -c 'DB_USER="$BACKEND_DB_USER" DB_PASSWORD="$BACKEND_DB_PASSWORD" VET_NOMBRE="Nombre de prueba" VET_EMAIL="vet@example.com" VET_PASSWORD="REEMPLAZAR_POR_UNA_CLAVE_SEGURA" php /app/Backend/scripts/crear_veterinario.php'
```

Reemplazá los datos de ejemplo. Evitá usar una contraseña real en comandos que vayan a quedar guardados en el historial compartido de la terminal.

## Rutas principales

| Método | Ruta | Propósito |
|---|---|---|
| `GET` | `/api/gateway/salud` | Comprueba el Gateway. |
| `GET` | `/api/backend/salud` | Comprueba el Backend y su conexión a la base. |
| `POST` | `/api/auth/registro/cliente` | Registra un cliente. |
| `POST` | `/api/auth/registro/rescatista` | Registra un rescatista. |
| `POST` | `/api/auth/login` | Inicia sesión. |
| `POST` | `/api/auth/logout` | Cierra sesión (requiere sesión y verificación CSRF según el contrato). |
| `GET` | `/api/auth/yo` | Devuelve los datos de la sesión actual. |
| `GET` | `/api/tienda/productos` | Lista productos públicos con búsqueda, filtros y paginado; depende de Inventario. |
| `GET` | `/api/tienda/productos/{id}` | Consulta el detalle de un producto activo; depende de Inventario. |
| `GET/POST/PUT/DELETE` | `/api/inventario/productos...` | Operaciones de administración de productos definidas en el contrato de API. |

Las rutas de tienda e Inventario están documentadas en `api/CONTRATO_API_ApiGateway.md`; la implementación debe estar disponible en el módulo Inventario para que respondan correctamente.

## Actualizar los submódulos

Cuando un compañero publique cambios en el repositorio remoto de Backend o Inventario, hay que actualizar el submódulo correspondiente y luego reconstruir la imagen para probar localmente. Por ejemplo, desde la raíz:

```bash
git submodule update --init --remote Backend
```

Para Inventario:

```bash
git submodule update --init --remote Inventario
```

Si el repositorio principal debe guardar la nueva versión utilizada, registrar la referencia del submódulo y subirla:

```bash
git add Backend Inventario
git commit -m "Actualiza referencias de submódulos"
git push
```

Hacé `git add` solo para el submódulo cuyo commit haya cambiado y que corresponda incluir. No uses `--remote` si tenés modificaciones locales sin guardar en el submódulo: revisá primero `git status`.

## Despliegue y HTTPS

- **Frontend:** se publica desde su propio repositorio en Vercel. `vercel.json` reescribe `/api/:path*` al servicio de Render conservando la ruta, por ejemplo `/api/backend/salud`.
- **API Gateway / módulos PHP:** se construyen con el `Dockerfile` y se ejecutan en Render. Tras `git push`, verificá que el despliegue termine correctamente.
- **Base de datos:** MySQL se aloja en Aiven y la conexión remota debe utilizar el host, el puerto y el certificado CA de la misma instancia.

Pruebas públicas (reemplazar la URL por la URL real del servicio):

```text
https://<SERVICIO-RENDER>.onrender.com/api/backend/salud
https://<DOMINIO-VERCEL>/api/backend/salud
```

La primera comprueba el servicio publicado directamente; la segunda también comprueba la reescritura de Vercel.

En Render, las variables de entorno y los Secret Files se configuran en el panel del servicio. No se transfieren automáticamente desde el `.env` local. Para el certificado, usá la ruta que realmente exista en el contenedor de Render.

## Seguridad y consideraciones

- No subir `.env`, contraseñas, `JWT_PRIVATE_KEY`, tokens ni archivos de claves al repositorio.
- El Gateway y los módulos distintos de Backend no deben recibir la clave privada JWT; la clave pública puede utilizarse para verificar tokens.
- Las contraseñas de los usuarios deben almacenarse con hash; las consultas SQL deben ser parametrizadas.
- La cookie de sesión del Backend está configurada con `HttpOnly`, `Secure` y `SameSite=Strict`.
- El Frontend incluye el token CSRF en `X-CSRF-Token` para operaciones modificadoras cuando dispone de él. La verificación del lado servidor debe estar implementada y probada antes de dar por finalizada la protección CSRF; en una versión revisada de `comun/auth.php` aparecía como pendiente.
- Los errores enviados al usuario deben ser genéricos. Los detalles técnicos se consultan en los logs y nunca deben incluir contraseñas, cookies o tokens.
- Que `/api/backend/salud` responda `200 OK` demuestra conectividad básica y que se pudo ejecutar `SELECT 1`; no demuestra que las tablas, el registro, el login y todos los endpoints de Inventario estén completos.

## Problemas frecuentes

**`502 Bad Gateway`**

Nginx no pudo comunicarse con el proceso del módulo de destino. Revisá `docker compose ps`, `docker compose logs --tail=100 app` y que el proceso PHP correspondiente esté iniciado en `docker/iniciar.sh`.

**`503` en `/api/backend/salud`**

El Backend no pudo conectarse a la base. Verificá `DB_HOST`, `DB_PORT`, `DB_NAME`, usuario, contraseña, `DB_SSL_CA` y que el certificado sea legible dentro del contenedor.

**`500` al registrar un usuario**

Revisá los logs de Render. La tabla `usuario` debe existir en la base configurada y la cuenta utilizada por Backend necesita los permisos definidos en `base/permisos.sql`. El mensaje que recibe el cliente es genérico a propósito.

**Catálogo vacío o error al consultar productos**

Comprobá que Inventario esté implementado, que su proceso esté iniciado y que existan las tablas y productos necesarios. El Frontend consulta `/api/tienda/productos`; la migración `001_backend_usuario.sql` no crea tablas de productos.

## Estado y alcance actual

- La base de infraestructura común, las rutas del Gateway y el endpoint de salud del Backend se probaron localmente.
- El registro y el inicio de sesión se lograron probar tras crear la tabla `usuario` y configurar las migraciones.
- El catálogo del Frontend ya está preparado para usar `/api/tienda/productos` y `/api/tienda/productos/{id}`, pero su funcionamiento depende de la implementación disponible en Inventario y de tener productos cargados.
- Verificá nuevamente cada flujo tras actualizar submódulos o variables de entorno; los cambios locales, de Render y de Aiven son configuraciones distintas.

## Documentación relacionada

- `api/CONTRATO_API_ApiGateway.md`: prefijos, rutas y responsabilidades de enrutamiento.
- `Backend/docs/api/contrato.md`: contrato de autenticación del módulo Backend.
- `Backend/SEGURIDAD.md`: decisiones de seguridad del Backend.
- `compose.yaml`, `Dockerfile`, `docker/iniciar.sh` y `docker/nginx.conf`: configuración de ejecución.
