# HuellaVet — API Gateway

Repositorio **ApiGateway** del Trabajo Práctico Integrador de **Programación en Ambiente Web (PAW)** — UNLu, 2026 — Grupo **La 25**.

Es la **única entrada pública** de la API de HuellaVet. Recibe los pedidos del Frontend y, con Nginx, los deriva al módulo que corresponde según el prefijo de la ruta. Además reúne lo que comparten todos los módulos: el código PHP común, Docker, las migraciones, los datos de prueba, las pruebas de integración y las tareas programadas.

| Entorno | URL |
| --- | --- |
| Producción | https://paw-apigateway-tpintegrador.onrender.com |
| Desarrollo | https://paw-apigateway-tpintegrador-dev.onrender.com |

## Autores

| Integrante | Legajo |
| --- | --- |
| Ana Paula Romero | 195388 |
| Maria Trinidad Lopez | 197958 |
| Valentino Aimale | 197961 |
| Cristian Tomás Anito | 158887 |

## Documentación

- [Contrato del ApiGateway](./api/CONTRATO_API_ApiGateway.md): prefijos, reglas comunes (sesión, CSRF, errores) y qué módulo atiende cada ruta.
- Contratos de cada módulo: carpeta `docs/api/` de cada submódulo.
- DER y diagrama de clases: en el repo [Backend](https://github.com/romeroppau/PAW--Backend--TPIntegrador/tree/dev/docs).
- Cuentas de prueba: [`base/semillas/README.md`](./base/semillas/README.md).

---

## Arquitectura

```
Navegador ──> Vercel (Frontend) ──/api/…──> Render: un contenedor Docker
                                              │
                                              ├─ Nginx (puerto público)
                                              │    ├─ /api/gateway/       → Gateway     127.0.0.1:9000
                                              │    ├─ /api/auth, /cuenta, /clientes, /rescatistas,
                                              │    │  /configuracion, /notificaciones, /resenas,
                                              │    │  /backend/salud      → Backend     127.0.0.1:9001
                                              │    ├─ /api/tienda/, /api/inventario/ → Inventario 127.0.0.1:9002
                                              │    ├─ /api/pacientes/     → Pacientes   127.0.0.1:9003
                                              │    ├─ /api/adopciones     → Adopciones  127.0.0.1:9004
                                              │    ├─ /api/reportes/      → Reportes    127.0.0.1:9005
                                              │    └─ /internal/          → 404 (bloqueado desde afuera)
                                              │
                                              └─ MySQL en Aiven (un usuario por módulo)
```

- Cada módulo es un **repositorio aparte**, incluido acá como **submódulo de Git**, y corre en su **propio proceso PHP**, con su propio usuario de MySQL.
- Los módulos se hablan entre sí por `127.0.0.1` y rutas `/internal/` con el header `X-Servicio-Token` (`INTERNAL_TOKEN`). Nginx no publica esas rutas.
- `docker/iniciar.sh` le pasa a cada proceso **solo las variables que necesita**: la clave privada del JWT solo la recibe Backend, el token de WhatsApp solo Backend y los de Mercado Pago solo Inventario.
- Si a Pacientes, Adopciones o Reportes les faltan sus credenciales de base, ese módulo no se inicia (queda un `[AVISO]` en el log) y el resto sigue funcionando.

| Módulo | Qué tiene |
| --- | --- |
| [Backend](https://github.com/romeroppau/PAW--Backend--TPIntegrador) | Usuarios, sesión, cuenta, configuración, notificaciones, WhatsApp y reseñas |
| [Inventario](https://github.com/romeroppau/PAW--Inventario--TPIntegrador) | Productos, insumos, stock y la tienda (carrito, compras, pagos, promociones) |
| [Pacientes](https://github.com/romeroppau/PAW--Pacientes--TPIntegrador) | Mascotas, turnos, consultas, facturas, calendario sanitario y turnos con descuento |
| [Adopciones](https://github.com/romeroppau/PAW--Adopciones--TPIntegrador) | Publicaciones, moderación, postulaciones y cierre de la adopción |
| [Reportes](https://github.com/romeroppau/PAW--Reportes--TPIntegrador) | Reportes, sugerencias y el motor diario de avisos |

### Estructura

```text
.
├── Backend/ Inventario/ Pacientes/ Adopciones/ Reportes/   Submódulos
├── api/CONTRATO_API_ApiGateway.md
├── base/
│   ├── migrar.php            Aplica las migraciones pendientes y los permisos
│   ├── NNN_*.sql             Migraciones (001 a 020)
│   ├── permisos/             Permisos de MySQL, un archivo por migración
│   ├── sembrar.php           Carga los datos de prueba (nunca en producción)
│   ├── semillas/             Datos de prueba comunes (los usa la prueba de humo)
│   └── semillas-volumen/     Datos en cantidad, para ver cómo escalan las pantallas
├── comun/                    PHP compartido: router, request, response, config, database,
│                             validator, logger, auth (sesión, rol y CSRF) y configuracion
├── docker/
│   ├── iniciar.sh            Inicia los procesos PHP y Nginx
│   └── nginx.conf            Las rutas
├── pruebas/
│   ├── integracion.sh        Levanta todo en Docker, migra, siembra y corre la prueba de humo
│   ├── humo.sh               Herramientas de la prueba de humo
│   └── casos/                Un archivo de casos por tema (01 a 18)
├── .github/workflows/        Pruebas, Motor diario, Enviar avisos y Keepalive
├── Dockerfile · compose.yaml · .env.example
└── autores.txt · VERSION.txt
```

---

## Cómo correrlo

### Qué hace falta

- Git y [Docker Desktop](https://www.docker.com/products/docker-desktop/) (en Windows, iniciarlo antes de correr `docker compose`).
- Para conectarse a la base remota: acceso a Aiven, Render y al certificado `ca.pem` de la base.

### 1. Clonar con los submódulos

```bash
git clone --recurse-submodules https://github.com/romeroppau/PAW--ApiGateway--TPIntegrador.git
cd PAW--ApiGateway--TPIntegrador
```

Si ya estaba clonado sin submódulos: `git submodule update --init --recursive`.

### 2. Variables de entorno

```bash
cp .env.example .env
```

El `.env` tiene contraseñas y claves: **nunca se sube** al repositorio. Las claves del JWT se generan como dice el README de [Backend](https://github.com/romeroppau/PAW--Backend--TPIntegrador#cómo-correrlo); los tokens, con `openssl rand -hex 32`, y las contraseñas de los módulos, con `openssl rand -hex 16`.

| Variable | Para qué |
| --- | --- |
| `ENTORNO` | `local`, `ci` o `dev`; en producción, otro valor (por ejemplo `prod`). En `local` y `ci` el WhatsApp y Mercado Pago se simulan; las semillas solo se cargan en `local`, `dev` y `ci` |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_SSL_CA` | La base. `DB_SSL_CA` es la ruta del certificado **dentro del contenedor** (`/app/ca.pem` en local, la del Secret File en Render) |
| `DB_ADMIN_USER`, `DB_ADMIN_PASSWORD` | Solo para el migrador y el sembrador; la API nunca la usa |
| `MYSQL_ROOT_PASSWORD` | El MySQL local opcional (perfil `local`) |
| `BACKEND_DB_*`, `INVENTARIO_DB_*`, `PACIENTES_DB_*`, `ADOPCIONES_DB_*`, `REPORTES_DB_*` | Usuario y contraseña de MySQL de cada módulo |
| `JWT_PRIVATE_KEY` | Firma la sesión. Solo la recibe Backend |
| `JWT_PUBLIC_KEY` | Verifica la sesión en todos los módulos |
| `INTERNAL_TOKEN` | Llamadas internas entre módulos (`/internal/`) |
| `TAREAS_TOKEN` | Tareas programadas (header `X-Tarea-Token`) |
| `WHATSAPP_TOKEN`, `WHATSAPP_NUMERO_ID`, `WHATSAPP_PLANTILLA`, `WHATSAPP_IDIOMA`, `WHATSAPP_API_VERSION` | Envío real de WhatsApp. Solo Backend |
| `MP_ACCESS_TOKEN`, `MP_WEBHOOK_SECRET` | Mercado Pago (siempre credenciales de prueba). Solo Inventario |
| `SITIO_URL` | Dirección pública del frontend, sin `/` al final (vuelta desde Mercado Pago) |

En Render, las variables y el `ca.pem` (como Secret File) se cargan en el panel de cada servicio; no se copian solas desde el `.env`. Dev y producción tienen **valores distintos** para las contraseñas, el JWT y los tokens.

### 3. Levantar

```bash
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 app
```

Para usar un MySQL local en vez de Aiven: `docker compose --profile local up -d db` (y en el `.env`, `DB_HOST=db`).

### 4. Migraciones

Se corren **a mano** cuando hay cambios de esquema:

```bash
docker compose --profile tools run --rm --build migrator
```

Para otro entorno, con otro archivo de variables: `docker compose --env-file .env.dev --profile tools run --rm --build migrator`.

`base/migrar.php` registra en la tabla `migracion` qué archivos ya se aplicaron, aplica los pendientes en orden, crea o actualiza los usuarios de cada módulo con las contraseñas del `.env` y aplica los permisos de `base/permisos/`.

> **Precaución:** revisá `DB_HOST` y `DB_NAME` antes de correrlo. El migrador **vuelve a asignar las contraseñas de los módulos**, así que tienen que ser las mismas que están en Render; si no, ese entorno deja de conectarse a la base.

### 5. Datos de prueba (solo local y dev)

```bash
docker compose --profile tools run --rm sembrador            # datos comunes
docker compose --profile tools run --rm sembrador-volumen    # datos en cantidad (opcional)
```

El sembrador se niega a correr con `ENTORNO=prod`: en producción las cuentas se crean por la web y el veterinario con el script de Backend. Las cuentas de prueba están en `base/semillas/README.md`.

### 6. Crear al veterinario (si no se cargaron las semillas)

```bash
docker compose exec app sh -c 'DB_USER="$BACKEND_DB_USER" DB_PASSWORD="$BACKEND_DB_PASSWORD" VET_NOMBRE="Nombre" VET_EMAIL="vet@huellavet.com" VET_PASSWORD="una-contraseña-segura" php /app/Backend/scripts/crear_veterinario.php'
```

### 7. Comprobar

```bash
curl http://localhost:10000/api/gateway/salud
curl http://localhost:10000/api/backend/salud
curl http://localhost:10000/api/inventario/salud
curl http://localhost:10000/api/pacientes/salud
curl http://localhost:10000/api/adopciones/salud
curl http://localhost:10000/api/reportes/salud
```

Cada uno tiene que responder `200` con `{"estado":"funciona","modulo":"…"}`. Los de los módulos además prueban la conexión a la base.

Para apagar: `docker compose down` (sin `-v`, salvo que se quiera borrar el volumen de la base local).

---

## Pruebas

| Prueba | Qué hace | Cómo se corre |
| --- | --- | --- |
| **Integración** | Levanta todo en Docker con un MySQL propio, migra, siembra y corre la prueba de humo. No toca el entorno local (usa otro proyecto de Docker y otros puertos) | `bash pruebas/integracion.sh` (con `MANTENER=1` queda levantado) |
| **Humo** | Pedidos con `curl` a la API y el resultado esperado de cada uno, por tema: general, roles, insumos, stock interno, mascotas y turnos, calendario, consultas, adopciones, notificaciones, configuración, reportes, tienda, promociones, motor, mis datos, reseñas, verificación del WhatsApp y promoción de turnos | `bash pruebas/humo.sh http://localhost:10000`; contra producción, solo lectura: `SOLO_LECTURA=1 bash pruebas/humo.sh https://paw-apigateway-tpintegrador.onrender.com` |
| **PHPUnit** | Las de cada módulo | En la carpeta de cada submódulo (ver su README) |

GitHub Actions (`pruebas.yml`) corre en cada push y pull request: comprueba que a `main` solo se mergee desde `dev`, la sintaxis de PHP y de los scripts, que cada PHP empiece con `<?php` y la prueba de integración completa.

---

## Tareas programadas (GitHub Actions)

| Workflow | Cuándo | Qué hace |
| --- | --- | --- |
| **Enviar avisos** | Cada 5 minutos, en dev y producción. Cada corrida dura una hora y se vuelve a disparar sola (ver abajo) | `POST /api/notificaciones/tareas/enviar` (WhatsApp pendientes) y `POST /api/tienda/tareas/vencer` (compras vencidas, recordatorios de retiro, reintegros pendientes). Desde las 9:00 de Argentina dispara el **Motor diario** si ese día todavía no corrió |
| **Motor diario** | Una vez por día desde las 9:00 de Argentina (la dispara Enviar avisos; el horario de las 12:00 UTC queda de respaldo), en dev y producción por separado. También a mano, eligiendo el entorno | `POST /api/inventario/tareas/vencer-lotes` (baja de los lotes vencidos de productos e insumos), `POST /api/reportes/tareas/diaria` (avisos de vacunas, controles de adopción, stock bajo y qué liquidar) y `POST /api/notificaciones/tareas/enviar` |
| **Keepalive** | Cada 14 minutos | Consulta la salud de producción para que Render no apague el servicio |
| **Pruebas** | En cada push y pull request | Ver [Pruebas](#pruebas) |

- Las tareas usan el header `X-Tarea-Token` con los secrets `TAREAS_TOKEN` (producción) y `TAREAS_TOKEN_DEV` (dev). Todas son idempotentes: correr de más no repite avisos ni movimientos.
- GitHub corre los horarios programados con la versión del workflow de la rama por defecto del repo (`dev`).
- **Por qué Enviar avisos se dispara sola (27/11):** GitHub no garantiza los horarios programados. Con "cada 5 minutos" la disparó 16 veces en dos días y medio, y el Motor diario de las 9:00 llegó a arrancar nueve horas tarde. Ahora cada corrida hace las tareas cada 5 minutos durante una hora y, al terminar, se vuelve a disparar con el `GITHUB_TOKEN` (GitHub permite `workflow_dispatch` desde un workflow). El horario programado queda de respaldo: si la cadena se corta, la retoma. Nunca corren dos a la vez (`concurrency`). Para frenarla, se deshabilita el workflow en Actions.
- Dev y producción van por separado: si dev falla (por ejemplo, porque `TAREAS_TOKEN_DEV` no coincide con el de Render), producción corre igual. Una corrida queda en rojo solo si falló producción.

---

## Actualizar los submódulos

Cuando un compañero mergea cambios en un módulo, desde la raíz:

```bash
git checkout dev && git pull
git submodule update --init
cd Backend                                        # o Inventario, Pacientes, Adopciones, Reportes
git fetch origin && git checkout origin/dev
cd ..
```

Ojo: `git submodule update --remote` trae la rama **`main`** del submódulo (`.gitmodules` no fija otra), no `dev`. En la rama `dev` de ApiGateway, los submódulos tienen que apuntar a `dev` de cada módulo.

Después se guarda la nueva referencia en una rama y se abre un pull request a `dev`:

```bash
git add Backend
git commit -m "Actualiza Backend"
git push -u origin <rama>
```

Agregá solo los submódulos que realmente cambiaron, y no uses `--remote` si tenés cambios sin guardar dentro del submódulo (revisá antes `git status`).

---

## Despliegue

- **API:** Render construye la imagen con el `Dockerfile`. El servicio de dev sigue la rama `dev` y el de producción la rama `main`.
- **Base:** MySQL en Aiven; dev y producción son instancias separadas, cada una con su `ca.pem`.
- **Frontend:** Vercel, desde su propio repo; reescribe `/api/…` al servicio de Render que corresponde.

### Pasar de dev a producción

1. Pull request de `dev` a `main` en cada repo (primero los módulos, después ApiGateway con las referencias de los submódulos, al final Frontend).
2. Revisar que estén en Render de producción todas las variables nuevas.
3. Correr el migrador contra producción con el `.env` de producción.
4. Comprobar la salud de todos los módulos y correr la prueba de humo en modo solo lectura.

---

## Seguridad

- Nginx es la única entrada pública; `/internal/` y cualquier ruta desconocida responden 404.
- Sesión con JWT RS256 en cookie `HttpOnly`, `Secure` y `SameSite=Strict`; `comun/auth.php` verifica la sesión, el rol y el token CSRF en todo `POST`, `PUT` y `DELETE`.
- Cada módulo usa su propio usuario de MySQL, con permisos solo sobre sus tablas; la cuenta de administración solo la usan el migrador y el sembrador.
- Cada proceso recibe solo las claves que usa (`env -u` en `docker/iniciar.sh`).
- Las llamadas entre módulos y las tareas programadas usan tokens comparados en tiempo constante.
- Todas las consultas son parametrizadas (PDO). Los errores al usuario son genéricos; el detalle queda en los logs, que nunca incluyen contraseñas, cookies ni tokens.
- Nada secreto en el repo: `.env`, claves y `ca.pem` están en `.gitignore`.

---

## Problemas frecuentes

| Síntoma | Qué revisar |
| --- | --- |
| `502 Bad Gateway` | El proceso del módulo no está levantado. `docker compose logs app` y buscar `[AVISO]` |
| `503` en una salud | El módulo no llega a la base: `DB_HOST`, `DB_PORT`, usuario, contraseña y `DB_SSL_CA` |
| `500` con `Unknown column` o `Table doesn't exist` | Falta correr el migrador en ese entorno |
| Error SSL `verify code 19` en el migrador | El `ca.pem` no es el de esa instancia de Aiven |
| `Access denied` en el migrador | El usuario administrador o su contraseña no son los de esa base |
| El WhatsApp no llega (error 131030) | Con el número de prueba de Meta, el destinatario tiene que estar verificado en la app de Meta |
| La primera carga tarda un minuto | Render apaga el servicio tras 15 minutos sin visitas |
