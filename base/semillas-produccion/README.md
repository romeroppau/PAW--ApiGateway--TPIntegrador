# Datos para producción

Un juego de datos **con nombres, productos y textos reales**, para que producción parezca una
veterinaria funcionando y para mostrar los flujos en la demo. No usa las cuentas de prueba
(`@prueba.huellavet`): se carga **alrededor de las cuentas de la demo**, que se crean desde la web.

## Qué carga

| Archivo | Qué | Ids |
|---|---|---|
| 001 | 40 clientes y 5 rescatistas de la zona "de fondo" (no pueden iniciar sesión ni tienen teléfono: nunca reciben un WhatsApp); 128 mascotas, entre ellas Rocco, Mishi y Coco (cliente 1 de la demo) y Lola (cliente 2) | usuarios 3001 a 3045, mascotas 30001 a 30144 |
| 002 | 30 productos con marca, precio y foto (6 por vencer, 6 con stock bajo) y 15 insumos; da de baja los productos e insumos que había antes (no los borra) | 3001 a 3030 |
| 003 | 6 meses de agenda con la veterinaria de la demo (~720 turnos), consultas con diagnóstico, indicaciones, lo que se usó y factura; calendario sanitario | turnos 30001 a 30765 |
| 004 | Fotos de las mascotas (14 de perro y 12 de gato, Unsplash) | — |
| 005 | 44 adopciones en todos los estados; 4 son del rescatista de la demo | 30001 a 30044 |
| 006 | 150 compras de la tienda (19 del cliente 1; la V-030002 está pagada y para retirar) | 30001 a 30150 |
| 007 | 120 avisos de la campana para la veterinaria, el cliente 1 y el rescatista | 30001 a 30120 |
| 008 | 22 reseñas, la mitad respondidas | 30001 a 30022 |

Ningún turno de este juego pisa uno que ya exista: si el horario está ocupado, el de acá queda
cancelado. Una cuenta de fondo cuyo email ya exista no se carga.

## Cómo se carga

1. **Crear las cuentas de la demo desde la web** de producción: 2 clientes (con un WhatsApp que esté
   en la lista de Meta) y 1 rescatista; la veterinaria aprueba al rescatista. La veterinaria es la
   que ya existe.
2. **Crear `.env.aiven-prod`** en la carpeta del Gateway, copiando `.env.aiven-dev` con los valores de
   producción (no se sube al repo: `.env*` está en `.gitignore`). El `ca.pem` de la raíz es el de
   producción.
3. Con Docker Desktop abierto, desde la carpeta del Gateway:

       EMAIL_VET=… EMAIL_CLIENTE1=… EMAIL_CLIENTE2=… EMAIL_RESCATISTA=… \
         bash base/semillas-produccion/cargar.sh aiven .env.aiven-prod ca.pem

   Muestra a qué base va, busca las cuatro cuentas y pide escribir `CARGAR`.

Para probarlo antes en el sistema local de pruebas (proyecto `huellavet-ci`), con las cuentas de
prueba haciendo de cuentas de la demo:

    EMAIL_VET=vet@prueba.huellavet EMAIL_CLIENTE1=cliente@prueba.huellavet \
    EMAIL_CLIENTE2=cliente2@prueba.huellavet EMAIL_RESCATISTA=rescatista@prueba.huellavet \
      bash base/semillas-produccion/cargar.sh local

Se puede correr todas las veces que haga falta: vuelve a dejar los datos como estaban, con las
fechas corridas a hoy (lo que se haya hecho en la demo sobre estos datos se deshace).
