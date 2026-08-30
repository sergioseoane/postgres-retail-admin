-- ============================================================
-- Datos TPV coherentes: a diferencia de las 5.000 ventas masivas de
-- 02_datos_ejemplo.sql (sin empleado/turno, solo para volumen), aqui
-- cada venta se genera paso a paso -de verdad-, vinculada a un
-- empleado, un metodo de pago y un turno de caja concreto, disparando
-- el trigger real de movimientos_inventario en cada linea.
-- ============================================================

INSERT INTO empleados (nombre, rol) VALUES
    ('Marta Fernandez', 'gerente'),
    ('Carlos Vidal', 'cajero'),
    ('Lucia Rey', 'cajero');

INSERT INTO metodos_pago (nombre) VALUES ('Efectivo'), ('Tarjeta'), ('Mixto');

-- ---- Turno 1: CERRADO Y CUADRADO (sin descuadre) ----
-- Se generan las ventas primero, y el cierre se calcula A PARTIR de
-- esas ventas reales - no se inventa un numero aparte.
DO $$
DECLARE
    v_turno_id      INTEGER;
    v_venta_id      INTEGER;
    v_total_efectivo NUMERIC(10,2) := 0;
    v_importe_linea  NUMERIC(10,2);
    v_metodo_efectivo INTEGER;
    v_metodo_tarjeta  INTEGER;
BEGIN
    SELECT id INTO v_metodo_efectivo FROM metodos_pago WHERE nombre = 'Efectivo';
    SELECT id INTO v_metodo_tarjeta  FROM metodos_pago WHERE nombre = 'Tarjeta';

    INSERT INTO turnos_caja (tienda_id, empleado_id, terminal_tpv, abierto_en, importe_apertura)
    VALUES (1, 2, 'TPV-1', now() - interval '8 hours', 50.00)
    RETURNING id INTO v_turno_id;

    -- 5 ventas en efectivo (cuentan para el cierre de caja) + 2 con tarjeta
    FOR i IN 1..7 LOOP
        INSERT INTO ventas (tienda_id, terminal_tpv, empleado_id, metodo_pago_id, turno_caja_id, creado_en)
        VALUES (
            1, 'TPV-1', 2,
            CASE WHEN i <= 5 THEN v_metodo_efectivo ELSE v_metodo_tarjeta END,
            v_turno_id,
            now() - interval '8 hours' + (i * interval '40 minutes')
        )
        RETURNING id INTO v_venta_id;

        -- Cada venta: 2 unidades del producto i (ciclando entre los 5)
        v_importe_linea := (SELECT precio_venta FROM productos WHERE id = ((i - 1) % 5) + 1) * 2;

        INSERT INTO ventas_lineas (venta_id, producto_id, cantidad, precio_unit)
        VALUES (v_venta_id, ((i - 1) % 5) + 1, 2,
                (SELECT precio_venta FROM productos WHERE id = ((i - 1) % 5) + 1));

        -- Dispara el trigger real: baja el stock de verdad, no un UPDATE a mano
        INSERT INTO movimientos_inventario (tienda_id, producto_id, tipo, cantidad, venta_id, motivo)
        VALUES (1, ((i - 1) % 5) + 1, 'venta', -2, v_venta_id, 'Venta turno 1');

        IF i <= 5 THEN
            v_total_efectivo := v_total_efectivo + v_importe_linea;
        END IF;
    END LOOP;

    -- El cierre se calcula A PARTIR de las ventas reales generadas arriba:
    -- fondo de apertura + lo cobrado en efectivo. Declarado = calculado -> sin descuadre.
    UPDATE turnos_caja
       SET cerrado_en = now(),
           importe_cierre_calculado = importe_apertura + v_total_efectivo,
           importe_cierre_declarado = importe_apertura + v_total_efectivo
     WHERE id = v_turno_id;
END $$;

-- ---- Turno 2: CERRADO CON DESCUADRE REAL (faltan 2,50 EUR) ----
DO $$
DECLARE
    v_turno_id       INTEGER;
    v_venta_id       INTEGER;
    v_total_efectivo NUMERIC(10,2) := 0;
    v_metodo_efectivo INTEGER;
BEGIN
    SELECT id INTO v_metodo_efectivo FROM metodos_pago WHERE nombre = 'Efectivo';

    INSERT INTO turnos_caja (tienda_id, empleado_id, terminal_tpv, abierto_en, importe_apertura)
    VALUES (1, 3, 'TPV-2', now() - interval '6 hours', 50.00)
    RETURNING id INTO v_turno_id;

    FOR i IN 1..4 LOOP
        INSERT INTO ventas (tienda_id, terminal_tpv, empleado_id, metodo_pago_id, turno_caja_id, creado_en)
        VALUES (1, 'TPV-2', 3, v_metodo_efectivo, v_turno_id, now() - interval '6 hours' + (i * interval '50 minutes'))
        RETURNING id INTO v_venta_id;

        INSERT INTO ventas_lineas (venta_id, producto_id, cantidad, precio_unit)
        VALUES (v_venta_id, i, 3, (SELECT precio_venta FROM productos WHERE id = i));

        INSERT INTO movimientos_inventario (tienda_id, producto_id, tipo, cantidad, venta_id, motivo)
        VALUES (1, i, 'venta', -3, v_venta_id, 'Venta turno 2');

        v_total_efectivo := v_total_efectivo + (SELECT precio_venta FROM productos WHERE id = i) * 3;
    END LOOP;

    -- Aqui SI hay descuadre real: el empleado declara 2,50 EUR de menos
    -- de lo que la caja calcula que deberia haber (caso real de faltante).
    UPDATE turnos_caja
       SET cerrado_en = now(),
           importe_cierre_calculado = importe_apertura + v_total_efectivo,
           importe_cierre_declarado = (importe_apertura + v_total_efectivo) - 2.50
     WHERE id = v_turno_id;
END $$;

-- ---- Turno 3: TODAVIA ABIERTO (sin cerrar_en ni importes de cierre) ----
INSERT INTO turnos_caja (tienda_id, empleado_id, terminal_tpv, importe_apertura)
VALUES (1, 2, 'TPV-1', 50.00);
