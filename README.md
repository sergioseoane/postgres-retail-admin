# postgres-retail-admin

Proyecto de administración práctica de PostgreSQL sobre un caso de uso
real de retail (inventario y ventas de un TPV), con tareas de
administración: roles con privilegio mínimo, backups con
verificación de integridad, y tuning medido con datos reales, no
teóricos.

## Por qué este enfoque

Se monta un escenario cercano a un entorno de tienda/retail (tiendas, productos, inventario, ventas
por TPV) para que las tareas de administración tengan sentido de
negocio real, no solo sintaxis SQL suelta.

## Qué incluye

- **`schema/`**: esquema completo (tiendas, productos, inventario,
  ventas), datos de ejemplo (5.000 ventas simuladas), y gestión de
  roles con privilegio mínimo (un rol de solo lectura, un rol de
  aplicación sin permisos de borrado de esquema).
- **`scripts/backup_postgres.sh`**: backup con `pg_dump`, que además
  **verifica la integridad real del archivo** con `pg_restore --list`
  antes de darlo por bueno.
- **`tuning/`**: caso real de creación de un índice compuesto, con
  medidas de `EXPLAIN ANALYZE` **antes y después**, no solo la teoría.

## Gestión de contraseñas

Las contraseñas de los roles **nunca están escritas en el código**.
`03_roles_permisos.sql` se sustituyó por `03_roles_permisos.sh`, que
lee las contraseñas de variables de entorno
(`RETAIL_READONLY_PASSWORD`, `RETAIL_APP_PASSWORD`) — un `.sql` plano
no puede leer variables de entorno, un `.sh` sí, y Postgres lo
ejecuta igual de automático al arrancar (los scripts de
`docker-entrypoint-initdb.d/` se ejecutan en orden alfabético, sean
`.sql` o `.sh`).

## Cómo probarlo

### Dentro de Docker Compose (uso real, ver `portfolio-infra`)

Las variables de entorno se definen en el `.env` de `portfolio-infra`
(a partir de `.env.example`) y se pasan solas al contenedor — no hay
que hacer nada más, los tres scripts de `schema/` se ejecutan
automáticamente al primer arranque.

### Probar el script de roles y el backup manualmente (opcional)

```bash
# El script de roles necesita las variables de entorno presentes:
export POSTGRES_USER=postgres
export POSTGRES_DB=retail_demo
export RETAIL_READONLY_PASSWORD=una_contrasena_de_prueba
export RETAIL_APP_PASSWORD=otra_contrasena_de_prueba
./schema/03_roles_permisos.sh

# Ejecutar un backup verificado
./scripts/backup_postgres.sh retail_demo
```

## Piezas TPV reales, más allá de lo genérico

El esquema (`01_schema.sql`) no es solo "tiendas/productos/inventario/
ventas" — incluye desde el principio piezas que **solo tienen sentido
en un TPV físico real**, no en un e-commerce genérico:

- **`empleados`** y **`metodos_pago`**: quién cobra y cómo se paga
  (incluye "Mixto", pago dividido, típico de caja física).
- **`turnos_caja`**: apertura/cierre por turno, con una columna
  `diferencia` **calculada automáticamente** (`GENERATED ALWAYS AS`)
  — el clásico "descuadre de caja".
- **`movimientos_inventario`** (kardex): un historial de *por qué*
  cambia el stock (venta, compra, ajuste, merma), no solo la cantidad
  actual.
- **Trigger `fn_actualizar_inventario`**: cada movimiento actualiza
  el stock solo — la aplicación nunca hace `UPDATE` directo sobre
  `inventario`.
- **IVA por producto**: tipos reales españoles (10% en leche/pan,
  21% en el resto).

## Dos orígenes de datos distintos, a propósito

- **`02_datos_ejemplo.sql`**: 5.000 ventas masivas **sin** empleado/
  turno (representan un histórico importado, sin ese detalle) — sirven
  solo para tener volumen real con el que medir el índice (ver
  `tuning/01_indice_compuesto.md`).
- **`04_datos_tpv_coherentes.sql`**: un puñado de ventas generadas
  **paso a paso de verdad** (venta → línea → movimiento de inventario,
  disparando el trigger real), vinculadas a un empleado, un método de
  pago y un turno concreto. Incluye un turno **cuadrado** (diferencia
  0.00) y otro con un **descuadre real** (-2.50€), ambos calculados a
  partir de las ventas generadas, no inventados a mano — verificado
  con `tuning/02_cierre_de_caja.sql`, que da los mismos números que
  guarda `turnos_caja`.

## Roles creados

| Rol | Uso previsto | Permisos |
|---|---|---|
| `retail_readonly` | Informes/dashboards | Solo `SELECT` |
| `retail_app` | El propio software del TPV | `SELECT`/`INSERT`/`UPDATE`, sin borrar tablas |

Ninguno de los dos tiene privilegios de superusuario - si la
aplicación tiene un fallo o una inyección SQL, el daño posible queda
limitado por diseño.
