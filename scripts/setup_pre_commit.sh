#!/usr/bin/env bash
# =============================================================
# setup_pre_commit.sh
# Instala y configura hooks de pre-commit (black, flake8, mypy)
# en los repositorios del workspace.
# Rol: Agente Auditor Linux (El Ojo de Sauron)
# Uso: bash scripts/setup_pre_commit.sh [directorio_workspaces]
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACES_DIR="${1:-${REPO_ROOT}/workspaces}"
HOOK_SRC="${REPO_ROOT}/hooks/pre_commit_hook.sh"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/setup_precommit_$(date +%Y%m%d_%H%M%S).log"

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
    for cmd in python3 pip; do
        if ! command -v "$cmd" &>/dev/null; then
            log "ERROR" "Dependencia faltante: ${cmd}"
            exit 1
        fi
    done
}

install_python_tools() {
    log "INFO" "Instalando black, flake8, mypy, pre-commit..."
    pip install --quiet --upgrade \
        --break-system-packages \
        black flake8 mypy pre-commit >> "$LOG_FILE" 2>&1
    log "OK" "Herramientas Python instaladas."
}

deploy_hook() {
    local repo_path="$1"
    local hook_dest="${repo_path}/.git/hooks/pre-commit"

    if [[ ! -d "${repo_path}/.git" ]]; then
        log "WARN" "[${repo_path}] No es un repo Git. Omitiendo."
        return 1
    fi

    log "INFO" "Desplegando hook en: ${repo_path}"
    cp "$HOOK_SRC" "$hook_dest"
    chmod +x "$hook_dest"
    log "OK" "Hook instalado en ${hook_dest}"
    return 0
}

# setup_precommit_yaml eliminado: el hook personalizado
# (pre_commit_hook.sh) se despliega directamente via deploy_hook().
# El marco pre-commit no se usa — evita conflictos y WARNs.

# -----------------------------------------------------------
# Inicialización
# -----------------------------------------------------------
mkdir -p "$LOG_DIR"
log "INFO" "Iniciando setup de pre-commit hooks."
log "INFO" "Workspaces: ${WORKSPACES_DIR}"

check_deps
install_python_tools

if [[ ! -f "$HOOK_SRC" ]]; then
    log "ERROR" "Hook fuente no encontrado: ${HOOK_SRC}"
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
    nombre=$(basename "$repo_path")

    if deploy_hook "$repo_path"; then
        exito=$(( exito + 1 ))
    else
        fallo=$(( fallo + 1 ))
    fi
done

# -----------------------------------------------------------
# Resumen
# -----------------------------------------------------------
log "INFO" "Setup finalizado. Éxitos: ${exito} | Fallos: ${fallo}"
[[ "$fallo" -gt 0 ]] && exit 1 || exit 0
