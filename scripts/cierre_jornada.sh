#!/usr/bin/env bash
# =============================================================
# cierre_jornada.sh
# Checklist automatizado de fin de jornada.
# Verifica que ningún repo quede con trabajo sin publicar
# y que toda rama activa tenga un PR formal en GitHub.
#
# Uso:  bash scripts/cierre_jornada.sh
# Salida: 0 = jornada limpia | 1 = pendientes detectados
# Rol:  Agente Auditor Linux (El Ojo de Sauron)
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACES_DIR="${REPO_ROOT}/workspaces"
REPOS_FILE="${REPO_ROOT}/config/repos.txt"

# Herramientas en ~/.local/bin
export PATH="${HOME}/.local/bin:${PATH}"

# -----------------------------------------------------------
# Colores
# -----------------------------------------------------------
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { echo -e "  ${VERDE}✔${RESET} $*"; }
warn() { echo -e "  ${AMARILLO}⚠${RESET}  $*"; }
err()  { echo -e "  ${ROJO}✘${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }

separador() {
    echo -e "${BOLD}──────────────────────────────────────────${RESET}"
}

# -----------------------------------------------------------
# Banner
# -----------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   EL OJO DE SAURON — CIERRE DE JORNADA  ║${RESET}"
echo -e "${BOLD}║   $(date '+%Y-%m-%d %H:%M:%S')               ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""

pendientes=0

# -----------------------------------------------------------
# BLOQUE 1: Orquestador (auditoria_ecosauron)
# -----------------------------------------------------------
separador
echo -e "${BOLD}[1/3] Orquestador (auditoria_ecosauron)${RESET}"
separador

cd "$REPO_ROOT"

# Cambios sin commit
sin_commit=$(git status --porcelain)
if [[ -n "$sin_commit" ]]; then
    warn "Cambios sin commit en el orquestador:"
    git status --short | sed 's/^/       /'
    pendientes=$(( pendientes + 1 ))
else
    ok "Sin cambios pendientes."
fi

# Commits sin push
sin_push=$(git log --oneline @{u}..HEAD 2>/dev/null || true)
if [[ -n "$sin_push" ]]; then
    warn "Commits locales sin push:"
    echo "$sin_push" | sed 's/^/       /'
    pendientes=$(( pendientes + 1 ))
else
    ok "Rama sincronizada con origin."
fi

# -----------------------------------------------------------
# BLOQUE 2: Repos auditados — estado local
# -----------------------------------------------------------
echo ""
separador
echo -e "${BOLD}[2/3] Repositorios del ecosistema${RESET}"
separador

if [[ ! -f "$REPOS_FILE" ]]; then
    warn "No se encontró ${REPOS_FILE}"
    pendientes=$(( pendientes + 1 ))
fi

while IFS= read -r linea || [[ -n "$linea" ]]; do
    [[ "$linea" =~ ^#.*$ || -z "$linea" ]] && continue

    url=$(echo "$linea" | awk '{print $1}')
    nombre=$(echo "$linea" | awk '{print $2}')
    [[ -z "$nombre" ]] && nombre=$(basename "$url" .git)

    repo_path="${WORKSPACES_DIR}/${nombre}"

    echo ""
    info "${nombre}"

    if [[ ! -d "${repo_path}/.git" ]]; then
        warn "Repo no clonado localmente — ejecuta clone_repos.sh"
        pendientes=$(( pendientes + 1 ))
        continue
    fi

    cd "$repo_path"

    # Cambios sin commit
    cambios=$(git status --porcelain)
    if [[ -n "$cambios" ]]; then
        warn "Cambios sin commit:"
        git status --short | sed 's/^/       /'
        pendientes=$(( pendientes + 1 ))
    else
        ok "Working tree limpio."
    fi

    # Commits sin push
    rama_activa=$(git branch --show-current)
    upstream=$(git rev-parse --abbrev-ref \
        "${rama_activa}@{upstream}" 2>/dev/null || true)

    if [[ -n "$upstream" ]]; then
        atras=$(git log --oneline "${upstream}".."${rama_activa}" \
            2>/dev/null | wc -l)
        if [[ "$atras" -gt 0 ]]; then
            warn "${atras} commit(s) sin push en '${rama_activa}'."
            pendientes=$(( pendientes + 1 ))
        else
            ok "Rama '${rama_activa}' sincronizada."
        fi
    else
        warn "Rama '${rama_activa}' sin upstream configurado."
        pendientes=$(( pendientes + 1 ))
    fi

    cd "$REPO_ROOT"

done < "$REPOS_FILE"

# -----------------------------------------------------------
# BLOQUE 3: Ramas huérfanas en GitHub
# -----------------------------------------------------------
echo ""
separador
echo -e "${BOLD}[3/3] Ramas huérfanas en GitHub (sin PR)${RESET}"
separador
echo ""

if bash "${SCRIPT_DIR}/verificar_ramas.sh"; then
    ok "Todas las ramas tienen PR o no existen ramas extra."
else
    warn "Existen ramas sin PR — jornada INCOMPLETA."
    info "Crea el PR antes de cerrar:"
    info "  1. Ve a GitHub → repositorio correspondiente"
    info "  2. Crea un PR desde la rama identificada a main"
    info "  3. Vuelve a ejecutar este script para confirmar"
    pendientes=$(( pendientes + 1 ))
fi

# -----------------------------------------------------------
# Resumen final
# -----------------------------------------------------------
echo ""
separador
echo ""

if [[ "$pendientes" -eq 0 ]]; then
    echo -e "${VERDE}${BOLD}  ✔  JORNADA COMPLETA — el ecosistema está limpio.${RESET}"
    echo -e "     Puedes cerrar con confianza."
else
    echo -e "${ROJO}${BOLD}  ✘  JORNADA INCOMPLETA — ${pendientes} punto(s) sin resolver.${RESET}"
    echo -e "     Resuelve los ítems marcados con ⚠ antes de cerrar."
fi

echo ""
exit "$pendientes"
