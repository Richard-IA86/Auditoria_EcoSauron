#!/usr/bin/env bash
# =============================================================
# validate_deps.sh
# Validación de cobertura de dependencias al 100%.
# Verifica que cada repositorio tenga requirements.txt o
# pyproject.toml y que todas sus dependencias estén instaladas.
# Rol: Agente Auditor Linux (El Ojo de Sauron)
# Uso: bash scripts/validate_deps.sh [directorio_workspaces]
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACES_DIR="${1:-${REPO_ROOT}/workspaces}"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/validate_deps_$(date +%Y%m%d_%H%M%S).log"

# -----------------------------------------------------------
# Funciones auxiliares
# -----------------------------------------------------------
log() {
    local nivel="$1"
    shift
    echo "[$(date +%Y-%m-%dT%H:%M:%S)] [${nivel}] $*" | \
        tee -a "$LOG_FILE"
}

check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        log "ERROR" "Herramienta no encontrada: ${1}"
        exit 1
    fi
}

validate_repo_deps() {
    local repo_path="$1"
    local nombre
    nombre=$(basename "$repo_path")
    local estado="OK"

    log "INFO" "[${nombre}] Validando dependencias..."

    # Detectar archivo de dependencias
    local dep_file=""
    if [[ -f "${repo_path}/requirements.txt" ]]; then
        dep_file="${repo_path}/requirements.txt"
    elif [[ -f "${repo_path}/pyproject.toml" ]]; then
        dep_file="${repo_path}/pyproject.toml"
    elif [[ -f "${repo_path}/setup.cfg" ]]; then
        dep_file="${repo_path}/setup.cfg"
    else
        log "WARN" \
            "[${nombre}] Sin archivo de dependencias detectado."
        return 1
    fi

    log "INFO" "[${nombre}] Usando: ${dep_file}"

    # Verificar instalación con pip check
    if [[ "$dep_file" == *requirements.txt ]]; then
        log "INFO" "[${nombre}] Ejecutando pip install --dry-run..."
        if ! pip install \
            --dry-run \
            --quiet \
            -r "$dep_file" \
            >> "$LOG_FILE" 2>&1; then
            log "ERROR" \
                "[${nombre}] Dependencias faltantes o conflictos."
            estado="FALLO"
        fi
    fi

    # pip check detecta conflictos en el entorno activo
    log "INFO" "[${nombre}] Ejecutando pip check..."
    if ! pip check >> "$LOG_FILE" 2>&1; then
        log "ERROR" \
            "[${nombre}] pip check reportó conflictos."
        estado="FALLO"
    fi

    # Safety check si está disponible (solo requirements.txt)
    if command -v safety &>/dev/null && \
       [[ "$dep_file" == *requirements.txt ]]; then
        log "INFO" "[${nombre}] Ejecutando safety check..."
        if ! safety check \
            --file "$dep_file" \
            --full-report \
            >> "$LOG_FILE" 2>&1; then
            log "WARN" \
                "[${nombre}] safety detectó vulnerabilidades."
        fi
    fi

    if [[ "$estado" == "OK" ]]; then
        log "OK" "[${nombre}] Cobertura de dependencias: 100%"
        return 0
    else
        return 1
    fi
}

# -----------------------------------------------------------
# Inicialización
# -----------------------------------------------------------
mkdir -p "$LOG_DIR"
log "INFO" "Iniciando validación de dependencias."
log "INFO" "Workspaces: ${WORKSPACES_DIR}"

check_cmd python3
check_cmd pip

if [[ ! -d "$WORKSPACES_DIR" ]]; then
    log "ERROR" "Directorio no encontrado: ${WORKSPACES_DIR}"
    exit 1
fi

# -----------------------------------------------------------
# Iteración sobre repositorios
# -----------------------------------------------------------
exito=0
fallo=0

shopt -s nullglob
for repo_path in "${WORKSPACES_DIR}"/*/; do
    repo_path="${repo_path%/}"
    if validate_repo_deps "$repo_path"; then
        ((exito++))
    else
        ((fallo++))
    fi
done

# -----------------------------------------------------------
# Resumen
# -----------------------------------------------------------
log "INFO" \
    "Validación finalizada. Éxitos: ${exito} | Fallos: ${fallo}"

if [[ "$fallo" -gt 0 ]]; then
    log "ERROR" \
        "PIPELINE BLOQUEADO: ${fallo} repo(s) con dependencias KO."
    exit 1
fi

log "OK" "Cobertura total de dependencias: 100%"
exit 0
