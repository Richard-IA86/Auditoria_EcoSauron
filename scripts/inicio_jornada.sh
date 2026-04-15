#!/usr/bin/env bash
# =============================================================
# inicio_jornada.sh
# Briefing matutino del ecosistema Grupo POSE.
#
# 1) Sincroniza orquestador y repos via git pull
# 2) Verifica estado de ramas (verificar_ramas.sh)
# 3) Lee config/estado_proyecto.json de cada repo y
#    presenta los pendientes del día.
#
# Uso:   bash scripts/inicio_jornada.sh
# Salida: 0 = briefing OK | >0 = repos con onboarding incompleto
# Rol:   Agente Auditor Linux (El Ojo de Sauron)
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACES_DIR="${REPO_ROOT}/workspaces"
REPOS_FILE="${REPO_ROOT}/config/repos.txt"

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
    echo -e \
        "${BOLD}──────────────────────────────────────────${RESET}"
}

HOY=$(date '+%Y-%m-%d')
errores=0

# -----------------------------------------------------------
# Banner
# -----------------------------------------------------------
echo ""
echo -e \
    "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e \
    "${BOLD}║   EL OJO DE SAURON — INICIO DE JORNADA  ║${RESET}"
echo -e \
    "${BOLD}║   ${HOY}                               ║${RESET}"
echo -e \
    "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""

# -----------------------------------------------------------
# BLOQUE 1: Sync orquestador
# -----------------------------------------------------------
separador
echo -e "${BOLD}[1/4] Sincronizando orquestador${RESET}"
separador

cd "$REPO_ROOT"
if git pull --ff-only --quiet 2>/dev/null; then
    ok "Orquestador sincronizado."
else
    warn "Pull del orquestador falló (sin internet o conflictos)."
fi

# -----------------------------------------------------------
# BLOQUE 2: Sync repos del ecosistema
# -----------------------------------------------------------
echo ""
separador
echo -e "${BOLD}[2/4] Sincronizando repos del ecosistema${RESET}"
separador

if [[ ! -f "$REPOS_FILE" ]]; then
    warn "No se encontró ${REPOS_FILE}"
    errores=$(( errores + 1 ))
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
        warn "No clonado — ejecuta clone_repos.sh"
        errores=$(( errores + 1 ))
        continue
    fi

    cd "$repo_path"
    if git pull --ff-only --quiet 2>/dev/null; then
        ok "Sincronizado."
    else
        warn "Pull fallido (conflictos o rama sin upstream)."
    fi
    cd "$REPO_ROOT"

done < "$REPOS_FILE"

# -----------------------------------------------------------
# BLOQUE 3: Estado de ramas
# -----------------------------------------------------------
echo ""
separador
echo -e "${BOLD}[3/4] Estado de ramas${RESET}"
separador
echo ""

if bash "${SCRIPT_DIR}/verificar_ramas.sh" 2>/dev/null; then
    ok "Todas las ramas tienen PR o no hay ramas extra."
else
    warn "Existen ramas sin PR — revisar antes de desarrollar."
    errores=$(( errores + 1 ))
fi

# -----------------------------------------------------------
# BLOQUE 4: Briefing por repositorio
# (lee jornada.fin del estado_proyecto.json de cada repo)
# -----------------------------------------------------------
echo ""
separador
echo -e "${BOLD}[4/4] Pendientes por repositorio${RESET}"
separador
echo ""

# Parser Python inline: extrae datos de jornada del JSON
read -r -d '' PY_JORNADA << 'PYEOF' || true
import sys
import json
import os

repo_path = sys.argv[1]
fp = os.path.join(
    repo_path, "config", "estado_proyecto.json"
)
if not os.path.exists(fp):
    print("SIN_JSON")
    sys.exit(0)
with open(fp, encoding="utf-8") as fh:
    data = json.load(fh)
fin = data.get("jornada", {}).get("fin", {})
dev = data.get("desarrollo_local", {})
if isinstance(dev, list):
    dev = dev[-1] if dev else {}
if not isinstance(dev, dict):
    dev = {}
pendientes = fin.get("tareas_pendientes_manana", [])
if not pendientes:
    punto = dev.get("punto_de_partida_manana", "")
    if punto and "Sin deuda" not in str(punto):
        pendientes = [punto]
print("FECHA:" + str(fin.get("fecha", "")))
print("PIPELINE:" + str(fin.get("estado_pipeline", "")))
print("NOTAS:" + str(fin.get("notas_qa", "")))
for tarea in pendientes:
    print("TAREA:" + str(tarea))
PYEOF

while IFS= read -r linea || [[ -n "$linea" ]]; do
    [[ "$linea" =~ ^#.*$ || -z "$linea" ]] && continue

    url=$(echo "$linea" | awk '{print $1}')
    nombre=$(echo "$linea" | awk '{print $2}')
    [[ -z "$nombre" ]] && nombre=$(basename "$url" .git)
    repo_path="${WORKSPACES_DIR}/${nombre}"

    echo -e "  ${BOLD}${nombre}${RESET}"

    if [[ ! -d "${repo_path}/.git" ]]; then
        warn "No clonado"
        echo ""
        continue
    fi

    salida=$(python3 -c "$PY_JORNADA" "$repo_path" 2>/dev/null \
        || echo "ERROR_PARSE")

    if [[ "$salida" == "SIN_JSON" ]]; then
        err "Sin config/estado_proyecto.json — repo sin onboarding"
        errores=$(( errores + 1 ))
        echo ""
        continue
    fi

    if [[ "$salida" == "ERROR_PARSE" ]]; then
        warn "Error leyendo JSON"
        errores=$(( errores + 1 ))
        echo ""
        continue
    fi

    fecha_cierre=$(
        echo "$salida" | grep "^FECHA:" | cut -d: -f2-
    )
    pipeline=$(
        echo "$salida" | grep "^PIPELINE:" | cut -d: -f2-
    )
    notas=$(
        echo "$salida" | grep "^NOTAS:" | cut -d: -f2-
    )
    tareas=$(
        echo "$salida" | grep "^TAREA:" | cut -d: -f2- || true
    )

    if [[ -n "$fecha_cierre" ]]; then
        info "Último cierre: ${fecha_cierre}  |  pipeline: ${pipeline:-?}"
    else
        warn "Sin registro de cierre de jornada previo."
    fi

    if [[ -n "$notas" && "$notas" != " " ]]; then
        info "QA: ${notas}"
    fi

    if [[ -n "$tareas" ]]; then
        echo -e "  ${AMARILLO}▶ Pendientes:${RESET}"
        while IFS= read -r tarea; do
            [[ -z "$tarea" ]] && continue
            echo -e "    • ${tarea}"
        done <<< "$tareas"
    else
        ok "Sin tareas pendientes registradas."
    fi

    echo ""

done < "$REPOS_FILE"

# -----------------------------------------------------------
# Footer
# -----------------------------------------------------------
separador
echo ""

if [[ "$errores" -eq 0 ]]; then
    echo -e \
        "${VERDE}${BOLD}  ✔  Briefing completo — ecosistema listo.${RESET}"
else
    echo -e \
        "${AMARILLO}${BOLD}  ⚠  ${errores} repo(s) con onboarding incompleto.${RESET}"
fi

echo ""
echo -e "  Siguiente paso recomendado:"
echo -e "    ${BOLD}bash scripts/run_audit.sh${RESET}"
echo ""

exit "$errores"
