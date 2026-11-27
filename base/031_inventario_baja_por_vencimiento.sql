-- Migración 031 · módulo Inventario: baja de los lotes vencidos (27/11).
-- Todos los días, la tarea de Inventario (POST /api/inventario/tareas/vencer-lotes, la llama el motor
-- diario) da de baja el stock de cada lote vencido, de productos y de insumos: un movimiento SALIDA con
-- motivo VENCIMIENTO por lote, que se ve en Movimientos, y un aviso a la veterinaria.
-- Es compatible hacia atrás: solo agrega un valor al final del ENUM.

ALTER TABLE movimiento_inventario
  MODIFY motivo ENUM('CARGA_VETERINARIO','CONSULTA','VENTA','AJUSTE','VENTA_CANCELADA','VENCIMIENTO') NOT NULL;
