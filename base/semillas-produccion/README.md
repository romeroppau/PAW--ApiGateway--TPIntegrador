# Datos para producción

Un juego de datos **con nombres, productos y textos reales**, para que producción parezca una
veterinaria funcionando y para mostrar los flujos en la demo. No usa las cuentas de prueba
(`@prueba.huellavet`): se carga **alrededor de las cuentas de la demo**, que se crean desde la web.

## Qué carga

| Archivo | Qué | Ids |
|---|---|---|
| 001 | 40 clientes y 5 rescatistas de la zona "de fondo" (no pueden iniciar sesión ni tienen teléfono: nunca reciben un WhatsApp); 128 mascotas, entre ellas Rocco, Mishi y Coco (cliente 1 de la demo) y Lola (cliente 2) | usuarios 3001 a 3045, mascotas 30001 a 30144 |
| 002 | 30 productos con marca y precio (6 por vencer, 6 con stock bajo) y 17 insumos (con la vacuna o el antiparasitario del calendario que son); qué vence y hasta cuándo (029); da de baja los productos e insumos que había antes (no los borra) | 3001 a 3030, insumos 3001 a 3017 |
| 003 | 6 meses de agenda con la veterinaria de la demo (~470 turnos) y la historia de las mascotas de la demo desde cachorros: consultas con diagnóstico, lo que se usó y factura; el calendario de cada mascota con el plan de su especie (cada dosis dada sale de una consulta, en orden y con los días mínimos). **Generado por `generar.py`** | turnos 30001 a 30760, eventos 31001 en adelante |
| 004 | Una foto distinta para cada mascota (según su especie y su raza) y para cada producto (Unsplash, con los autores) | — |
| 005 | 44 adopciones en todos los estados; 4 son del rescatista de la demo. Las 2 rechazadas, también en el historial de rechazos (migración 023). Cada chequeo atendido, con su consulta y su factura | 30001 a 30044 |
| 006 | 150 compras de la tienda (19 del cliente 1; la V-030002 está pagada y para retirar), con sus plazos y sus movimientos (venta y devolución) | 30001 a 30150 |
| 008 | 22 reseñas de clientes atendidos antes de escribirlas, la mitad respondidas. **Generado por `generar.py`** | 30001 a 30022 |
| 009 | Los lotes de productos e insumos (028 y 029), de acuerdo con el stock | — |
| 010 | Los movimientos de stock: lo que usó cada consulta y las cargas que hacen falta para que el stock cierre | — |
| 011 | Los avisos de la campana, armados con lo que pasó (pedidos, reseñas, publicaciones, turnos, vacunas), con el texto del sistema | — |

**`generar.py`** arma `003` y `008` (Python 3, sin librerías): la agenda se simula mascota por mascota
para que nada quede inconsistente (una vacuna dada sin consulta, una dosis antes que la anterior, una
reseña de alguien que nunca vino). Para cambiar algo de la agenda o de las reseñas, se cambia el
generador y se vuelve a correr (`python base/semillas-produccion/generar.py`); no se editan los `.sql`
a mano.

**`controles.sql`** revisa que los datos cierren (solo lee): ninguna vacuna dada sin consulta, dosis en
orden y con los días mínimos, cada turno atendido con su consulta y su factura, cada adopción terminada
con su chequeo, el stock igual a sus movimientos y a sus lotes, ninguna foto repetida… Cada control
tiene que dar 0. Se corre después de `cargar.sh`, contra la misma base.

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
