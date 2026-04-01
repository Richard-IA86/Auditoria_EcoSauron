#!/usr/bin/env bash
# =============================================================
# pre_commit_hook.sh
# Hook de pre-commit reutilizable.
# Se instala como .git/hooks/pre-commit en los repos externos.
# Ejecuta: black, flake8, mypy sobre archivos staged.
# Rol: Agente Auditor Linux (El Ojo de Sauron)
# =============================================================
set -euo pipefail

# -----------------------------------------------------------
# Colores para salida
# -----------------------------------------------------------
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

log_ok()   { echo -e "${VERDE}[PRE-COMMIT OK]${RESET}   $*"; }
log_err()  { echo -e "${ROJO}[PRE-COMMIT ERR]${RESET}  $*"; }
log_warn() { echo -e "${AMARILLO}[PRE-COMMIT WARN]${RESET} $*"; }

# -----------------------------------------------------------
# Obtener archivos Python en staging area
# -----------------------------------------------------------
staged_py=$(git diff --cached --name-only --diff-filter=ACM | \
    grep '\.py$' || true)

if [[ -z "$staged_py" ]]; then
    log_ok "Sin archivos Python en staging. Nada que validar."
    exit 0
fi

errores=0

# -----------------------------------------------------------
# black — formato
# -----------------------------------------------------------
if command -v black &>/dev/null; then
    echo "--- black (formato, max 79 chars) ---"
    if ! echo "$staged_py" | xargs -d '\n' black \
        --check \
        --line-length 79 \
        --quiet; then
        log_err "black: archivos sin formatear."
        echo "Ejecuta: black --line-length 79 <archivo>"
        ((errores++))
    else
        log_ok "black: OK"
    fi
else
    log_warn "black no está instalado."
fi

# -----------------------------------------------------------
# flake8 — estilo y errores
# -----------------------------------------------------------
if command -v flake8 &>/dev/null; then
    echo "--- flake8 (PEP8, max-line=79) ---"
    if ! echo "$staged_py" | xargs -d '\n' flake8 \
        --max-line-length=79 \
        --show-source \
        --statistics; then
        log_err "flake8: infracciones encontradas."
        ((errores++))
    else
        log_ok "flake8: OK"
    fi
else
    log_warn "flake8 no está instalado."
fi

# -----------------------------------------------------------
# mypy — tipos estáticos
# -----------------------------------------------------------
if command -v mypy &>/dev/null; then
    echo "--- mypy (tipado estático) ---"
    if ! echo "$staged_py" | xargs -d '\n' mypy \
        --ignore-missing-imports \
        --no-error-summary; then
        log_err "mypy: errores de tipado."
        ((errores++))
    else
        log_ok "mypy: OK"
    fi
else
    log_warn "mypy no está instalado."
fi

# -----------------------------------------------------------
# Resultado final
# -----------------------------------------------------------
echo "==========================================="
if [[ "$errores" -gt 0 ]]; then
    log_err "Pre-commit FALLIDO: ${errores} herramienta(s) KO."
    echo "Commit bloqueado por El Ojo de Sauron."
    echo "==========================================="
    exit 1
fi

log_ok "Pre-commit APROBADO. Commit autorizado."
echo "==========================================="
exit 0
