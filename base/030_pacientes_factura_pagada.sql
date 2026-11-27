-- Migración 030 · módulo Pacientes: registrar el pago de la factura de una consulta (27/11).
-- La factura de la consulta nace PENDIENTE_PAGO y se abona en la veterinaria. La veterinaria la marca
-- como pagada desde la factura, con el medio de pago; queda quién y cuándo.
-- Lo que ya existe: las facturas PAGADA de antes quedan sin medio de pago (NULL): se muestran "Pagada".
-- Es compatible hacia atrás: las columnas aceptan NULL y Pacientes de antes no las usa.

ALTER TABLE factura_consulta
  ADD COLUMN medio_pago ENUM('EFECTIVO','TRANSFERENCIA','TARJETA') NULL AFTER estado,
  ADD COLUMN pagada_en  DATETIME NULL AFTER medio_pago,
  ADD COLUMN pagada_por INT UNSIGNED NULL AFTER pagada_en,
  ADD CONSTRAINT fk_factura_consulta_pagada_por FOREIGN KEY (pagada_por) REFERENCES usuario (id);
