#!/usr/bin/env bash
# =============================================================
# prefetch_check.sh
# Guardia de sincronización PREVIA a cualquier edición.
# Hace git fetch (sin modificar el working tree) y detecta si
# origin tiene commits que el local NO tiene.
#
# Uso:
#   bash scripts/prefetch_check.sh <repo_path>
#   bash scripts/prefetch_check.sh <repo_path> <archivo>
#
# Salida:
#   0 = seguro editar
#   1 = origin tiene commits nuevos → hacer pull primero
#
# Integración: invocar ANTES de cualquier replace_string_in_file
# o create_file en repos del ecosistema.
# =============================================================
set -euo pipefail

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

REPO_PATH="${1:-}"
ARCHIVO="${2:-}"

if [[ -z "$REPO_PATH" ]]; then
    echo -e "${ROJO}✘ Uso: $0 <repo_path> [archivo]${RESET}" >&2
    exit 2
fi

if [[ ! -d "${REPO_PATH}/.git" ]]; then
    echo -e "${ROJO}✘ No es un repo git: ${REPO_PATH}${RESET}" >&2
    exit 2
fi

cd "$REPO_PATH"
RAMA=$(git branch --show-current 2>/dev/null || echo "")

if [[ -z "$RAMA" ]]; then
    echo -e "${AMARILLO}⚠ Repo en estado detached HEAD — verificar manualmente.${RESET}" >&2
    exit 1
fi

# Fetch silencioso — no modifica working tree
git fetch --quiet origin 2>/dev/null || {
    echo -e "${AMARILLO}⚠ No se pudo conectar a origin — continuando sin verificación remota.${RESET}"
    exit 0
}

UPSTREAM="origin/${RAMA}"

# Verificar si existe el upstream remoto
if ! git rev-parse --verify "$UPSTREAM" &>/dev/null; then
    echo -e "${VERDE}✔ Rama '${RAMA}' sin upstream remoto — seguro editar localmente.${RESET}"
    exit 0
fi

ADELANTE=$(git rev-list HEAD.."${UPSTREAM}" --count 2>/dev/null || echo "0")
ATRAS=$(git rev-list "${UPSTREAM}"..HEAD --count 2>/dev/null || echo "0")

if [[ "$ADELANTE" -gt 0 ]]; then
    echo -e "${ROJO}✘ DIVERGENCIA DETECTADA — origin/${RAMA} tiene ${ADELANTE} commit(s) que local NO tiene.${RESET}" >&2
    echo "" >&2
    echo -e "  Commits remotos pendientes de integrar:" >&2
    git log --oneline HEAD.."${UPSTREAM}" | sed 's/^/    /' >&2
    echo "" >&2
    if [[ -n "$ARCHIVO" ]]; then
        # Verificar si el archivo específico fue modificado remotamente
        ARCHIVO_RELATIVO="${ARCHIVO#${REPO_PATH}/}"
        MODIFICADO=$(git diff --name-only HEAD "${UPSTREAM}" \
            2>/dev/null | grep -c "^${ARCHIVO_RELATIVO}$" || echo "0")
        if [[ "$MODIFICADO" -gt 0 ]]; then
            echo -e "${ROJO}  ⚠ CONFLICTO POTENCIAL: '${ARCHIVO_RELATIVO}' fue modificado en origin.${RESET}" >&2
            echo -e "  Hacer git pull ANTES de editar ese archivo." >&2
        else
            echo -e "${AMARILLO}  El archivo '${ARCHIVO_RELATIVO}' NO fue tocado en origin.${RESET}" >&2
            echo -e "  Igualmente se recomienda git pull antes de continuar." >&2
        fi
    fi
    echo "" >&2
    echo -e "  Acción requerida: ${AMARILLO}git -C ${REPO_PATH} pull${RESET}" >&2
    exit 1
fi

if [[ "$ATRAS" -gt 0 ]]; then
    echo -e "${AMARILLO}⚠ Local tiene ${ATRAS} commit(s) sin push — recordar publicar antes del cierre.${RESET}"
fi

if [[ -n "$ARCHIVO" ]]; then
    ARCHIVO_RELATIVO="${ARCHIVO#${REPO_PATH}/}"
    echo -e "${VERDE}✔ Seguro editar '${ARCHIVO_RELATIVO}' — sin divergencia en origin.${RESET}"
else
    echo -e "${VERDE}✔ Repo '$(basename "$REPO_PATH")' sincronizado — seguro editar.${RESET}"
fi

exit 0
