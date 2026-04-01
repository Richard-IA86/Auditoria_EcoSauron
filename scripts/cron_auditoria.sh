#!/usr/bin/env bash
# cron_auditoria.sh — Wrapper para ejecución programada del pipeline
# Ejecutado por cron a las 06:00 diariamente.
# Log del sistema: /var/log/ecosauron_auditoria.log

set -euo pipefail

REPO_DIR="/home/richard/Dev/auditoria_ecosauron"
LOG_FILE="/var/log/ecosauron_auditoria.log"
FLAG_FALLO="/tmp/ecosauron_FALLO.flag"
TIMESTAMP="$(date '+%Y-%m-%dT%H:%M:%S')"

echo "======================================" >> "$LOG_FILE"
echo "[$TIMESTAMP] Auditoría iniciada por cron" >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"

cd "$REPO_DIR"

bash scripts/run_audit.sh >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "[$TIMESTAMP] Auditoría finalizada: APROBADA" >> "$LOG_FILE"
    rm -f "$FLAG_FALLO"
else
    echo "[$TIMESTAMP] Auditoría finalizada: FALLIDA (código $EXIT_CODE)" \
        >> "$LOG_FILE"
    echo "$TIMESTAMP | EXIT_CODE=$EXIT_CODE | Ver: $LOG_FILE" \
        > "$FLAG_FALLO"
fi

echo "" >> "$LOG_FILE"
exit "$EXIT_CODE"
