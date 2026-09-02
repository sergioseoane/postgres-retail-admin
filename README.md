# postgres-retail-admin

Administración de PostgreSQL sobre un esquema realista de retail/TPV
(tiendas, inventario, ventas, turnos de caja), aplicando prácticas de
administración de bases de datos de producción: control de acceso,
verificación de backups y optimización basada en medición real.

## Objetivo del proyecto

Diseñar y administrar una base de datos con las mismas exigencias
que tendría un sistema de punto de venta real:

1. **Modelo de datos con sentido de negocio** — tiendas, productos,
   inventario, empleados, turnos de caja y ventas, no tablas sueltas.
2. **Control de acceso por roles** — separación real entre lectura y
   escritura, sin conceder privilegios de superusuario a la aplicación.
3. **Backups verificables**, no solo generados.
4. **Rendimiento medido**, no supuesto — decisiones de indexación
   respaldadas por `EXPLAIN ANALYZE` con datos reales.

## Arquitectura de datos

```
tiendas ──┬── productos ── movimientos_inventario (kardex)
          │                        ▲
          ├── inventario ──────────┘ (actualizado por trigger)
          │
          ├── empleados ── turnos_caja ── ventas ── ventas_lineas
          │
          └── metodos_pago
```

El inventario **nunca se actualiza manualmente** — un trigger
(`fn_actualizar_inventario`) lo mantiene consistente a partir de cada
movimiento registrado (venta, compra, ajuste, merma), garantizando
que el histórico y el estado actual nunca diverjan.

## Competencias técnicas aplicadas

- **Diseño de esquemas relacionales**: modelado de un dominio de
  negocio real (retail/TPV) con integridad referencial completa.
- **Control de acceso (RBAC a nivel de base de datos)**: roles
  diferenciados (`retail_readonly`, `retail_app`) bajo el principio
  de mínimo privilegio, sin permisos de superusuario.
- **Automatización a nivel de base de datos**: triggers y funciones
  en `PL/pgSQL` para mantener la integridad de datos sin depender de
  la capa de aplicación.
- **Gestión de backups**: verificación activa de integridad
  (`pg_restore --list`) antes de dar un backup por válido.
- **Optimización basada en evidencia**: decisiones de indexación
  respaldadas por planes de ejecución (`EXPLAIN ANALYZE`), no por
  suposiciones.

## Resultado medido: impacto real de un índice compuesto

| | Sin índice | Con índice compuesto |
|---|---|---|
| Tipo de plan | Seq Scan | Bitmap Index Scan |
| Tiempo de ejecución | 0.479 ms | 0.175 ms |
| Mejora | — | **2.7x** |

(Medición sobre 5.000 filas reales, ver `tuning/01_indice_compuesto.md`)

## Estructura del repositorio

```
schema/
  01_schema.sql              → modelo de datos completo
  02_datos_ejemplo.sql       → volumen de prueba para medición de rendimiento
  03_roles_permisos.sh       → creación de roles (lee credenciales de entorno)
  04_datos_tpv_coherentes.sql → casos de negocio reales (turno cuadrado y con descuadre)
scripts/
  backup_postgres.sh         → backup con verificación de integridad
tuning/
  01_indice_compuesto.md     → análisis de rendimiento con EXPLAIN ANALYZE
  02_cierre_de_caja.sql      → consulta de conciliación de caja
```

## Cómo ejecutarlo

Integrado dentro de [`portfolio-infra`](../portfolio-infra), que
monta `schema/` como scripts de inicialización de PostgreSQL:

```bash
cd ../portfolio-infra
docker compose up -d postgres
```

Los tres primeros scripts se ejecutan automáticamente en orden al
crear el contenedor por primera vez; `04_datos_tpv_coherentes.sql`
genera además un caso de conciliación de caja completo, calculado a
partir de ventas reales, no de valores fijados a mano.

## Proyectos relacionados

- [`nagios-monitoring-lab`](../nagios-monitoring-lab) — monitoriza la
  disponibilidad de esta base de datos mediante el rol de solo lectura.
- [`portfolio-infra`](../portfolio-infra) — infraestructura completa
  de despliegue.
