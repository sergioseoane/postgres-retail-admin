-- ============================================================
-- Esquema de un TPV de retail: tiendas, productos, inventario,
-- empleados, metodos de pago, turnos de caja y ventas, con un
-- historial de movimientos de inventario (kardex) que se mantiene
-- solo mediante un trigger.
-- ============================================================

CREATE TABLE tiendas (
    id            SERIAL PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    ubicacion     VARCHAR(150) NOT NULL,
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE productos (
    id            SERIAL PRIMARY KEY,
    sku           VARCHAR(30) UNIQUE NOT NULL,
    nombre        VARCHAR(150) NOT NULL,
    precio_venta  NUMERIC(10, 2) NOT NULL CHECK (precio_venta >= 0),
    categoria     VARCHAR(60),
    -- IVA real espanol: 21% general, 10% reducido (alimentacion basica)
    iva_pct       NUMERIC(4,2) NOT NULL DEFAULT 21.00
);

CREATE TABLE inventario (
    id             SERIAL PRIMARY KEY,
    tienda_id      INTEGER NOT NULL REFERENCES tiendas(id) ON DELETE CASCADE,
    producto_id    INTEGER NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    cantidad       INTEGER NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tienda_id, producto_id)
);

CREATE TABLE empleados (
    id     SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    rol    VARCHAR(30) NOT NULL DEFAULT 'cajero' CHECK (rol IN ('cajero', 'gerente')),
    activo BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE metodos_pago (
    id     SERIAL PRIMARY KEY,
    nombre VARCHAR(30) UNIQUE NOT NULL
);

-- Apertura y cierre de caja por turno. "diferencia" se calcula sola,
-- nunca se escribe a mano - es el clasico "descuadre de caja".
CREATE TABLE turnos_caja (
    id                       SERIAL PRIMARY KEY,
    tienda_id                INTEGER NOT NULL REFERENCES tiendas(id),
    empleado_id              INTEGER NOT NULL REFERENCES empleados(id),
    terminal_tpv             VARCHAR(20) NOT NULL,
    abierto_en               TIMESTAMPTZ NOT NULL DEFAULT now(),
    cerrado_en               TIMESTAMPTZ,
    importe_apertura         NUMERIC(10,2) NOT NULL,
    importe_cierre_declarado NUMERIC(10,2),
    importe_cierre_calculado NUMERIC(10,2),
    diferencia               NUMERIC(10,2) GENERATED ALWAYS AS
        (importe_cierre_declarado - importe_cierre_calculado) STORED
);

CREATE TABLE ventas (
    id            SERIAL PRIMARY KEY,
    tienda_id     INTEGER NOT NULL REFERENCES tiendas(id),
    terminal_tpv  VARCHAR(20) NOT NULL,
    empleado_id   INTEGER REFERENCES empleados(id),
    metodo_pago_id INTEGER REFERENCES metodos_pago(id),
    turno_caja_id INTEGER REFERENCES turnos_caja(id),
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ventas_lineas (
    id          SERIAL PRIMARY KEY,
    venta_id    INTEGER NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
    producto_id INTEGER NOT NULL REFERENCES productos(id),
    cantidad    INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unit NUMERIC(10, 2) NOT NULL
);

-- Kardex: historial de POR QUE cambia el stock, no solo cuanto queda.
CREATE TABLE movimientos_inventario (
    id          SERIAL PRIMARY KEY,
    tienda_id   INTEGER NOT NULL REFERENCES tiendas(id),
    producto_id INTEGER NOT NULL REFERENCES productos(id),
    tipo        VARCHAR(20) NOT NULL CHECK (tipo IN ('venta', 'compra', 'ajuste', 'merma')),
    cantidad    INTEGER NOT NULL,  -- positivo = entra, negativo = sale
    venta_id    INTEGER REFERENCES ventas(id),
    motivo      VARCHAR(200),
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- El inventario se mantiene solo: cada movimiento lo actualiza via trigger,
-- la aplicacion nunca hace UPDATE directo sobre "inventario".
CREATE OR REPLACE FUNCTION fn_actualizar_inventario()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE inventario
       SET cantidad = cantidad + NEW.cantidad,
           actualizado_en = now()
     WHERE tienda_id = NEW.tienda_id
       AND producto_id = NEW.producto_id;

    IF NOT FOUND THEN
        INSERT INTO inventario (tienda_id, producto_id, cantidad)
        VALUES (NEW.tienda_id, NEW.producto_id, NEW.cantidad);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_movimiento_inventario
AFTER INSERT ON movimientos_inventario
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_inventario();

-- Indices pensados para las consultas mas habituales de un TPV/retail
CREATE INDEX idx_ventas_tienda_fecha ON ventas (tienda_id, creado_en);
CREATE INDEX idx_inventario_tienda_cantidad ON inventario (tienda_id, cantidad);
CREATE INDEX idx_movimientos_producto_fecha ON movimientos_inventario (producto_id, creado_en);
CREATE INDEX idx_turnos_caja_empleado ON turnos_caja (empleado_id, abierto_en);
