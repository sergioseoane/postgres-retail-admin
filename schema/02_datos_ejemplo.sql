-- ============================================================
-- Datos de ejemplo: catalogo + volumen masivo de ventas.
--
-- Las ventas de este archivo se dejan SIN empleado/metodo_pago/turno
-- a proposito (quedan NULL) - representan un caso realista: historico
-- de ventas importado de un sistema anterior sin ese detalle, usado
-- aqui solo para tener volumen real con el que medir el rendimiento
-- del indice de "ventas" (ver tuning/01_indice_compuesto.md).
-- Los ejemplos DE VERDAD ligados a empleado/turno/metodo de pago estan
-- en 04_datos_tpv_coherentes.sql.
-- ============================================================

INSERT INTO tiendas (nombre, ubicacion) VALUES
  ('Tienda Betanzos', 'Poligono Piadela, Betanzos'),
  ('Tienda A Coruna', 'Centro, A Coruna');

-- La leche y el pan llevan IVA reducido (10%) en Espana, el resto 21%
INSERT INTO productos (sku, nombre, precio_venta, categoria, iva_pct) VALUES
  ('SKU-001', 'Leche entera 1L', 1.10, 'Lacteos', 10.00),
  ('SKU-002', 'Pan de molde', 1.85, 'Panaderia', 10.00),
  ('SKU-003', 'Detergente 40 lavados', 6.50, 'Drogueria', 21.00),
  ('SKU-004', 'Agua 6x1.5L', 3.20, 'Bebidas', 10.00),
  ('SKU-005', 'Cafe molido 250g', 3.95, 'Desayuno', 21.00);

INSERT INTO inventario (tienda_id, producto_id, cantidad)
SELECT t.id, p.id, (random() * 200)::int
FROM tiendas t CROSS JOIN productos p;

-- Volumen masivo (5.000 ventas) para poder medir el efecto real de un
-- indice compuesto con EXPLAIN ANALYZE - ver tuning/01_indice_compuesto.md
INSERT INTO ventas (tienda_id, terminal_tpv, creado_en)
SELECT
  (1 + floor(random() * 2))::int,
  'TPV-' || (1 + floor(random() * 3))::int,
  now() - (random() * interval '30 days')
FROM generate_series(1, 5000);

INSERT INTO ventas_lineas (venta_id, producto_id, cantidad, precio_unit)
SELECT
  v.id,
  p.id,
  1 + floor(random() * 4)::int,
  p.precio_venta
FROM ventas v
JOIN productos p ON p.id = (1 + floor(random() * 5))::int;
