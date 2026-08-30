-- Cierre de caja: compara lo que la caja "debería" tener (fondo de
-- apertura + ventas en efectivo reales de ese turno) contra lo que el
-- empleado declaró al cerrar, y contra el descuadre ya calculado.
--
-- Uso: cuanto se acerque mas "deberia_haber" a "importe_cierre_calculado"
-- guardado en turnos_caja, mas fiable es el dato de cierre.

SELECT
    tc.id AS turno,
    e.nombre AS empleado,
    tc.importe_apertura,
    COALESCE(SUM(vl.cantidad * vl.precio_unit)
        FILTER (WHERE mp.nombre = 'Efectivo'), 0) AS ventas_efectivo,
    tc.importe_apertura + COALESCE(SUM(vl.cantidad * vl.precio_unit)
        FILTER (WHERE mp.nombre = 'Efectivo'), 0) AS deberia_haber,
    tc.importe_cierre_declarado AS declarado_por_empleado,
    tc.diferencia
FROM turnos_caja tc
JOIN empleados e ON e.id = tc.empleado_id
LEFT JOIN ventas v ON v.turno_caja_id = tc.id
LEFT JOIN ventas_lineas vl ON vl.venta_id = v.id
LEFT JOIN metodos_pago mp ON mp.id = v.metodo_pago_id
GROUP BY tc.id, e.nombre, tc.importe_apertura, tc.importe_cierre_declarado, tc.diferencia
ORDER BY tc.id;
