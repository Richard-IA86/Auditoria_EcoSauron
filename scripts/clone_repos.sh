#!/usr/bin/env bash
# =============================================================
# clone_repos.sh
# Clonación masiva de repositorios definidos en config/repos.txt
# Rol: Agente Auditor Linux (El Ojo de Sauron)
# Uso: bash scripts/clone_repos.sh [directorio_destino]
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
REPOS_FILE="${REPO_ROOT}/config/repos.txt"
DEST_DIR="${1:-${REPO_ROOT}/workspaces}"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/clone_repos_$(date +%Y%m%d_%H%M%S).log"

# -----------------------------------------------------------
# Funciones auxiliares
# -----------------------------------------------------------
log() {
    local nivel="$1"
    shift
    echo "[$(date +%Y-%m-%dT%H:%M:%S)] [${nivel}] $*" | \
        tee -a "$LOG_FILE"
}

check_deps() {
    for cmd in git; do
        if ! command -v "$cmd" &>/dev/null; then
            log "ERROR" "Dependencia faltante: ${cmd}"
            exit 1
        fi
    done
}

# -----------------------------------------------------------
# Inicialización
# -----------------------------------------------------------
mkdir -p "$DEST_DIR" "$LOG_DIR"
log "INFO" "Iniciando clonación masiva."
log "INFO" "Archivo de repos: ${REPOS_FILE}"
log "INFO" "Directorio destino: ${DEST_DIR}"

check_deps

if [[ ! -f "$REPOS_FILE" ]]; then
    log "ERROR" "No se encontró ${REPOS_FILE}"
    exit 1
fi

# -----------------------------------------------------------
# Procesamiento de repositorios
# -----------------------------------------------------------
exito=0
fallo=0

while IFS= read -r linea || [[ -n "$linea" ]]; do
    # Ignorar comentarios y líneas vacías
    [[ "$linea" =~ ^#.*$ || -z "$linea" ]] && continue

    url=$(echo "$linea" | awk '{print $1}')
    nombre=$(echo "$linea" | awk '{print $2}')

    if [[ -z "$nombre" ]]; then
        nombre=$(basename "$url" .git)
    fi

    destino="${DEST_DIR}/${nombre}"

    if [[ -d "${destino}/.git" ]]; then
        log "INFO" "[${nombre}] Ya existe. Ejecutando git pull..."
        if git -C "$destino" pull --ff-only >> "$LOG_FILE" 2>&1; then
            log "OK" "[${nombre}] Actualizado correctamente."
            ((exito++))
        else
            log "WARN" "[${nombre}] No se pudo actualizar."
            ((fallo++))
        fi
    else
        log "INFO" "[${nombre}] Clonando desde ${url}..."
        if git clone "$url" "$destino" >> "$LOG_FILE" 2>&1; then
            log "OK" "[${nombre}] Clonado correctamente."
            ((exito++))
        else
            log "ERROR" "[${nombre}] Falló la clonación."
            ((fallo++))
        fi
    fi
done < "$REPOS_FILE"

# -----------------------------------------------------------
# Resumen final
# -----------------------------------------------------------
log "INFO" "Clonación finalizada. Éxitos: ${exito} | Fallos: ${fallo}"

if [[ "$fallo" -gt 0 ]]; then
    log "WARN" "Revisa el log: ${LOG_FILE}"
    exit 1
fi

exit 0
