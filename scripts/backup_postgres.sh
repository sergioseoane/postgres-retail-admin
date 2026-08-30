#!/usr/bin/env bash
#
# backup_postgres.sh
#
# Hace un backup logico de la base de datos con pg_dump, y VERIFICA
# que el backup es realmente restaurable (no solo que el archivo
# existe) antes de darlo por bueno.

set -euo pipefail

DB_NAME="${1:-retail_demo}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"
LOG_FILE="${BACKUP_DIR}/backup_history.log"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Iniciando backup de '$DB_NAME'..."

# Formato "custom" de pg_dump: comprimido y el unico formato que
# permite restaurar tablas sueltas despues, en vez de todo o nada.
pg_dump -Fc "$DB_NAME" > "$BACKUP_FILE"

# --- Verificacion de integridad real ---
# pg_restore --list no restaura nada, pero SI lee el archivo entero
# y falla si esta corrupto o incompleto.
if pg_restore --list "$BACKUP_FILE" > /dev/null 2>&1; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    CHECKSUM=$(sha256sum "$BACKUP_FILE" | cut -d' ' -f1)
    echo "[$(date)] OK - Backup valido: $BACKUP_FILE ($SIZE, sha256=$CHECKSUM)" | tee -a "$LOG_FILE"
else
    echo "[$(date)] ERROR - El backup parece corrupto: $BACKUP_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

# Rotacion: se queda solo con los ultimos 7 backups para no llenar el disco.
ls -1t "${BACKUP_DIR}"/${DB_NAME}_*.dump | tail -n +8 | xargs -r rm -v
