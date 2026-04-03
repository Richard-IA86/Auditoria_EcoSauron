#!/usr/bin/env bash
# =============================================================
# verificar_ramas.sh
# Detecta ramas "huérfanas" en GitHub: ramas remotas que no
# son main y no tienen un PR abierto asociado.
# Usa la GitHub REST API pública (curl + jq).
# Soporte opcional: variable GITHUB_TOKEN para evitar rate-limit.
#
# Uso:         bash scripts/verificar_ramas.sh
# Salida:       0 = sin huérfanas | 1 = huérfanas detectadas
# Rol:          Agente Auditor Linux (El Ojo de Sauron)
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
REPOS_FILE="${REPO_ROOT}/config/repos.txt"

# -----------------------------------------------------------
# Colores
# -----------------------------------------------------------
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

log_ok()   { echo -e "${VERDE}[RAMAS OK]${RESET}    $*"; }
log_warn() { echo -e "${AMARILLO}[RAMAS WARN]${RESET}  $*"; }
log_err()  { echo -e "${ROJO}[RAMAS ERR]${RESET}   $*"; }
log_info() { echo "[RAMAS INFO]  $*"; }

# Versión stderr — para usar dentro de subshells/captures
log_warn_err() { echo -e "${AMARILLO}[RAMAS WARN]${RESET}  $*" >&2; }

# -----------------------------------------------------------
# Cabecera de autenticación
# Prioridad: 1) variable GITHUB_TOKEN, 2) git credential store
# El token nunca se almacena en disco — se lee en runtime.
# -----------------------------------------------------------
AUTH_HEADER=""

resolve_token() {
    # Variable de entorno explícita (CI/cron)
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        echo "$GITHUB_TOKEN"
        return
    fi
    # Git credential store local (sesión interactiva)
    printf "protocol=https\nhost=github.com\n" | \
        git credential fill 2>/dev/null | \
        grep '^password=' | cut -d= -f2 || true
}

TOKEN=$(resolve_token)
if [[ -n "$TOKEN" ]]; then
    AUTH_HEADER="Authorization: Bearer ${TOKEN}"
    log_info "Token resuelto desde credential store."
else
    log_warn "Sin token — repos privados no serán verificables."
fi

# -----------------------------------------------------------
# Función: llamada a GitHub API
# Arg 1: endpoint (ej. /repos/owner/repo/branches)
# -----------------------------------------------------------
gh_api() {
    local endpoint="$1"
    local url="https://api.github.com${endpoint}"
    if [[ -n "$AUTH_HEADER" ]]; then
        curl -s -H "$AUTH_HEADER" \
             -H "Accept: application/vnd.github+json" \
             "$url"
    else
        curl -s \
             -H "Accept: application/vnd.github+json" \
             "$url"
    fi
}

# -----------------------------------------------------------
# Función: detectar ramas huérfanas en un repo
# Arg 1: owner (ej. Richard-IA86)
# Arg 2: repo  (ej. Planif_POSE)
# Arg 3: nombre local (ej. planif_pose)
# Retorna: lista de ramas huérfanas (una por línea), vacía si OK
# -----------------------------------------------------------
detectar_huerfanas() {
    local owner="$1"
    local repo="$2"
    local nombre_local="$3"

    # Todas las ramas remotas excepto main
    local ramas_json
    ramas_json=$(gh_api "/repos/${owner}/${repo}/branches?per_page=100")

    # Verificar que la respuesta sea un array JSON válido
    if ! echo "$ramas_json" | jq -e 'if type == "array" then . else error end' \
            &>/dev/null; then
        log_warn_err "[${nombre_local}] No se pudo consultar ramas (API)."
        return 0
    fi

    local ramas
    ramas=$(echo "$ramas_json" | \
        jq -r '.[].name' | grep -v '^main$' || true)

    if [[ -z "$ramas" ]]; then
        return 0
    fi

    # PRs en cualquier estado (open + closed) — incluye mergeados
    # Una rama con PR en cualquier estado ya fue gestionada
    local prs_json
    prs_json=$(gh_api \
        "/repos/${owner}/${repo}/pulls?state=all&per_page=100")

    local ramas_con_pr=""
    if echo "$prs_json" | jq -e 'if type == "array" then . else error end' \
            &>/dev/null; then
        ramas_con_pr=$(echo "$prs_json" | \
            jq -r '.[].head.ref' 2>/dev/null || true)
    fi

    # Ramas sin ningún PR (ni abierto, ni cerrado, ni mergeado)
    while IFS= read -r rama; do
        [[ -z "$rama" ]] && continue
        if ! echo "$ramas_con_pr" | grep -qxF "$rama"; then
            echo "$rama"
        fi
    done <<< "$ramas"
}

# -----------------------------------------------------------
# Procesamiento principal
# -----------------------------------------------------------
if [[ ! -f "$REPOS_FILE" ]]; then
    log_warn "No se encontró ${REPOS_FILE} — saltando verificación."
    exit 0
fi

if ! command -v jq &>/dev/null; then
    log_warn "jq no está instalado — saltando verificación de ramas."
    exit 0
fi

total_huerfanas=0
repos_con_huerfanas=()

log_info "Verificando ramas huérfanas en GitHub..."

while IFS= read -r linea || [[ -n "$linea" ]]; do
    [[ "$linea" =~ ^#.*$ || -z "$linea" ]] && continue

    url=$(echo "$linea" | awk '{print $1}')
    nombre_local=$(echo "$linea" | awk '{print $2}')

    # Extraer owner/repo de la URL
    # Soporta: https://github.com/owner/repo.git
    ruta=${url#https://github.com/}
    ruta=${ruta%.git}
    owner=$(echo "$ruta" | cut -d'/' -f1)
    repo=$(echo "$ruta"  | cut -d'/' -f2)

    [[ -z "$owner" || -z "$repo" ]] && continue
    [[ -z "$nombre_local" ]] && nombre_local="$repo"

    huerfanas=$(detectar_huerfanas "$owner" "$repo" "$nombre_local")

    if [[ -n "$huerfanas" ]]; then
        log_warn \
            "[${nombre_local}] Ramas sin PR detectadas:"
        while IFS= read -r rama; do
            echo "    → ${rama}"
            ((total_huerfanas++))
        done <<< "$huerfanas"
        repos_con_huerfanas+=("$nombre_local")
    else
        log_ok "[${nombre_local}] Sin ramas huérfanas."
    fi
done < "$REPOS_FILE"

echo ""
if [[ "$total_huerfanas" -eq 0 ]]; then
    log_ok "Todas las ramas tienen PR asociado o no existen."
    exit 0
else
    log_err "${total_huerfanas} rama(s) huérfana(s) en: " \
        "${repos_con_huerfanas[*]}"
    log_err "Acción requerida: crear PR o eliminar la(s) rama(s)."
    exit 1
fi
