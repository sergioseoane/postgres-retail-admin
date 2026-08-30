# Ejemplo real de tuning: índice compuesto en tabla de ventas

Caso de uso: en un TPV, la consulta más habitual es "ventas de esta
tienda en los últimos N días" (para el cierre de caja, informes, etc.).
Con 5.000 ventas de prueba repartidas en 30 días, así se comporta esa
consulta con y sin índice.

## Consulta analizada

```sql
EXPLAIN ANALYZE
SELECT * FROM ventas
WHERE tienda_id = 1 AND creado_en > now() - interval '7 days';
```

## Sin índice (Seq Scan - recorre toda la tabla)

```
Seq Scan on ventas  (cost=0.00..132.00 rows=601 width=22) (actual time=0.007..0.444 rows=587 loops=1)
  Filter: ((tienda_id = 1) AND (creado_en > (now() - '7 days'::interval)))
  Rows Removed by Filter: 4413
Execution Time: 0.479 ms
```

Postgres recorre las 5.000 filas de la tabla una a una, descarta 4.413
que no cumplen la condición, y se queda con las 587 válidas.

## Con índice compuesto (tienda_id, creado_en)

```sql
CREATE INDEX idx_ventas_tienda_fecha ON ventas (tienda_id, creado_en);
```

```
Bitmap Heap Scan on ventas  (cost=4.33..16.16 rows=4 width=74) (actual time=0.045..0.142 rows=587 loops=1)
  Heap Blocks: exact=32
  ->  Bitmap Index Scan on idx_ventas_tienda_fecha (actual time=0.037..0.037 rows=587 loops=1)
Execution Time: 0.175 ms
```

Con el índice, Postgres va directo a las 587 filas relevantes sin
descartar las otras 4.413 una por una.

## Resultado medido

| | Sin índice | Con índice |
|---|---|---|
| Tiempo de ejecución | 0.479 ms | 0.175 ms |
| Filas descartadas | 4.413 | 0 |

Con solo 5.000 filas la diferencia ya es notable (~2.7x más rápido).
En una tabla de ventas real de un comercio, que puede acumular
millones de filas en pocos años, esa misma consulta sin índice
pasaría de milisegundos a segundos completos - la diferencia entre
un TPV que responde al instante y uno que se queda "pensando" en
cada cierre de caja.

## Por qué un índice compuesto y no dos índices simples

Se creó **un solo índice sobre (tienda_id, creado_en)**, no dos
índices separados (uno por columna). Esto es deliberado: Postgres
solo puede usar de forma óptima un índice compuesto cuando la
consulta filtra por las columnas **en el mismo orden** en que están
en el índice (aquí: primero tienda, luego fecha) - que es exactamente
el patrón de consulta real de un TPV. Dos índices simples habrían
ocupado más espacio en disco y no habrían sido más rápidos para este
caso concreto.
