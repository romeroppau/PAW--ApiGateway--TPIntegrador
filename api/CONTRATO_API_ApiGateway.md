# Contrato de la API — ApiGateway

## 1. Objetivo

El módulo **ApiGateway** es el punto de entrada de las peticiones HTTP de HuellaVet. Recibe las solicitudes del frontend y las deriva al módulo responsable de procesarlas.

Nginx se encarga del enrutamiento entre módulos. El Gateway no implementa la lógica de negocio de Backend, Inventario, Pacientes, Adopciones ni Reportes.

## 2. Endpoint propio del Gateway

### `GET /api/gateway/salud`

Comprueba que el API Gateway está disponible.

- **Acceso:** público.
- **Método:** `GET`.
- **Ruta:** `/api/gateway/salud`.

**Respuesta propuesta — `200 OK`:**

```json
{
  "estado": "funciona",
  "modulo": "ApiGateway"
}
```

## 3. Enrutamiento hacia Inventario

### Catálogo público

| Método | Ruta | Función |
|---|---|---|
| GET | `/api/tienda/productos` | Listar productos con búsqueda, filtros y paginado |
| GET | `/api/tienda/productos/{id}` | Consultar el detalle de un producto |

### Administración de productos

| Método | Ruta | Función |
|---|---|---|
| GET | `/api/inventario/productos` | Listar productos para administración |
| POST | `/api/inventario/productos` | Crear un producto |
| GET | `/api/inventario/productos/{id}` | Consultar un producto por ID |
| PUT | `/api/inventario/productos/{id}` | Editar un producto |
| DELETE | `/api/inventario/productos/{id}` | Dar de baja un producto |
| POST | `/api/inventario/productos/{id}/stock` | Registrar una carga de stock |
| GET | `/api/inventario/productos/{id}/movimientos` | Consultar movimientos de un producto |

Estas rutas se derivan al módulo Inventario. Los métodos y las rutas son una propuesta que debe acordarse con su responsable.

## 4. Enrutamiento hacia Pacientes

| Método | Ruta | Función |
|---|---|---|
| GET | `/api/pacientes/mascotas` | Listar mascotas |
| POST | `/api/pacientes/mascotas` | Registrar una mascota |
| GET | `/api/pacientes/mascotas/{id}` | Consultar una mascota |
| PUT | `/api/pacientes/mascotas/{id}` | Editar datos de una mascota |
| GET | `/api/pacientes/mascotas/{id}/historial` | Consultar historial clínico |
| GET | `/api/pacientes/turnos` | Consultar turnos |
| POST | `/api/pacientes/turnos` | Registrar un turno |
| POST | `/api/pacientes/turnos/{id}/atencion` | Iniciar la atención de un turno |
| POST | `/api/pacientes/consultas/{id}/finalizar` | Finalizar una consulta |
| GET | `/api/pacientes/mascotas/{id}/calendario-sanitario` | Consultar calendario sanitario |

Estas rutas son una propuesta basada en las clases y funcionalidades del UML. Se prevén para la etapa correspondiente del módulo Pacientes.

## 5. Enrutamiento hacia Adopciones

| Método | Ruta | Función |
|---|---|---|
| GET | `/api/adopciones/publicaciones` | Listar publicaciones disponibles |
| GET | `/api/adopciones/publicaciones/{id}` | Consultar una publicación |
| POST | `/api/adopciones/publicaciones` | Crear una publicación |
| PUT | `/api/adopciones/publicaciones/{id}` | Editar una publicación |
| DELETE | `/api/adopciones/publicaciones/{id}` | Dar de baja una publicación |
| POST | `/api/adopciones/publicaciones/{id}/postulaciones` | Registrar una postulación |
| GET | `/api/adopciones/publicaciones/{id}/postulaciones` | Consultar postulaciones |
| POST | `/api/adopciones/{id}/elegir-adoptante` | Elegir un adoptante |
| POST | `/api/adopciones/{id}/completar` | Completar una adopción |

Estas rutas son una propuesta basada en el UML y deberán acordarse con el responsable del módulo Adopciones.

## 6. Enrutamiento hacia Reportes

| Método | Ruta | Función |
|---|---|---|
| GET | `/api/reportes/ventas` | Consultar reporte de ventas |
| GET | `/api/reportes/turnos` | Consultar reporte de turnos |
| GET | `/api/reportes/stock` | Consultar reporte de stock |
| GET | `/api/reportes/recomendaciones` | Consultar recomendaciones |

Estas rutas son una propuesta basada en el diagrama de arquitectura y deberán acordarse con el responsable del módulo Reportes.

## 7. Endpoints de salud

| Método | Ruta | Destino |
|---|---|---|
| GET | `/api/gateway/salud` | ApiGateway |
| GET | `/api/backend/salud` | Backend |
| GET | `/api/inventario/salud` | Inventario |
| GET | `/api/pacientes/salud` | Pacientes |
| GET | `/api/adopciones/salud` | Adopciones |
| GET | `/api/reportes/salud` | Reportes |

Cada módulo implementa su propio endpoint de salud. El Gateway deriva las peticiones correspondientes, excepto `/api/gateway/salud`, que responde desde el propio Gateway.

## 8. Reglas de enrutamiento por prefijo

| Prefijo de ruta | Destino |
|---|---|
| `/api/auth/` | Backend |
| `/api/tienda/` | Inventario |
| `/api/inventario/` | Inventario |
| `/api/pacientes/` | Pacientes |
| `/api/adopciones/` | Adopciones |
| `/api/reportes/` | Reportes |
| `/api/gateway/salud` | ApiGateway |

El Gateway conserva el método HTTP, los parámetros de consulta, el cuerpo y los encabezados necesarios al derivar las peticiones al módulo correspondiente.

Cada módulo es responsable de implementar sus endpoints, validar los datos recibidos, controlar los permisos y ejecutar su lógica de negocio.

Las rutas de Inventario, Pacientes, Adopciones y Reportes constituyen una propuesta inicial. En el caso de caso de pacientes y reportes no lo abarcamos en profundidad porque será parte de las próximas entregas.

## 9. Métodos HTTP y responsabilidad

El Gateway no debe combinar automáticamente todos los métodos (`GET`, `POST`, `PUT`, `DELETE`) con todas las rutas. Debe derivar las solicitudes conservando el método recibido; cada módulo define en su contrato qué métodos admite cada endpoint.

Las operaciones de alta, modificación, baja y otras funciones de Inventario, Pacientes, Adopciones y Reportes se agregarán a este documento una vez realizados los contratos.

## 10. Sesión y seguridad

- La cookie de sesión se llama `huellavet_sesion`, según el contrato de Backend.
- El Gateway debe permitir que la cookie viaje entre el navegador y el módulo correspondiente.
- Debe conservar el encabezado `X-CSRF-Token` en las solicitudes que lo incluyan.
- Backend, Inventario y los demás módulos son responsables de verificar la sesión, los roles y el token CSRF según sus contratos.
- El Gateway no debe confiar en un rol declarado por el frontend para autorizar una operación.
- Los logs no deben incluir contraseñas, tokens de sesión ni otros secretos.

## 11. Respuestas y errores

En condiciones normales, el Gateway devuelve al cliente la respuesta del módulo de destino, conservando su código HTTP y su contenido.

Si un módulo no está disponible o no puede responder, el Gateway debe devolver un error apropiado sin exponer detalles internos de infraestructura.

**Ejemplo de respuesta por indisponibilidad — formato propuesto:**

```json
{
  "error": "Servicio temporalmente no disponible"
}
```

El código HTTP concreto para este caso debe acordarse al implementar la configuración del Gateway. Los errores de validación, autenticación y autorización mantienen el formato definido por cada módulo.

## 12. Responsabilidades del ApiGateway

- Recibir las peticiones HTTP que llegan a la API.
- Enrutar las peticiones al módulo correspondiente.
- Exponer su endpoint de salud.
- Permitir la comunicación entre el frontend y los módulos.
- Gestionar errores de comunicación sin revelar detalles internos.
- Mantener una configuración de infraestructura común para el despliegue.

La lógica de negocio, las consultas a MySQL y la validación específica de cada entidad corresponden a los módulos responsables.


