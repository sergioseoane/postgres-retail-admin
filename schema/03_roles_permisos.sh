#!/bin/bash
# ============================================================
# Gestion de roles: separacion de privilegios por tipo de acceso.
#
# Es un .sh, no un .sql, porque necesita leer las contrasenas de
# variables de entorno (RETAIL_READONLY_PASSWORD, RETAIL_APP_PASSWORD),
# definidas en el .env real (no versionado) - nunca escritas aqui.
# Postgres ejecuta los scripts de /docker-entrypoint-initdb.d/ en
# orden alfabetico, sean .sql o .sh.
# ============================================================
set -e

: "${RETAIL_READONLY_PASSWORD:?Falta la variable RETAIL_READONLY_PASSWORD}"
: "${RETAIL_APP_PASSWORD:?Falta la variable RETAIL_APP_PASSWORD}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Rol de solo lectura, para informes/dashboards.
    CREATE ROLE retail_readonly LOGIN PASSWORD '${RETAIL_READONLY_PASSWORD}';
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO retail_readonly;
    GRANT USAGE ON SCHEMA public TO retail_readonly;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO retail_readonly;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO retail_readonly;

    -- Rol de aplicacion: lectura/escritura, sin poder borrar tablas.
    CREATE ROLE retail_app LOGIN PASSWORD '${RETAIL_APP_PASSWORD}';
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO retail_app;
    GRANT USAGE ON SCHEMA public TO retail_app;
    GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO retail_app;
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO retail_app;
EOSQL

echo "Roles retail_readonly y retail_app creados correctamente."
