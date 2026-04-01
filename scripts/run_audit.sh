#!/usr/bin/env bash
# =============================================================
# run_audit.sh
# Orquestador principal del Pipeline de Auditoría EcoSauron.
# Ejecuta en secuencia: clonación, setup de hooks,
# validación de dependencias y análisis estático de código.
# Rol: Agente Auditor Linux (El Ojo de Sauron)
# Uso: bash scripts/run_audit.sh [directorio_workspaces]
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACES_DIR="${1:-${REPO_ROOT}/workspaces}"
LOG_DIR="${REPO_ROOT}/logs"
AUDIT_LOG="${LOG_DIR}/auditoria_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="${REPO_ROOT}/docs/reportes"

# Herramientas en ~/.local/bin (instaladas por pip --user)
# No siempre están en PATH en entornos no-interactivos (cron)
LOCAL_BIN="${HOME}/.local/bin"
export PATH="${LOCAL_BIN}:${PATH}"

# -----------------------------------------------------------
# Funciones auxiliares
# -----------------------------------------------------------
log() {
    local nivel="$1"
    shift
    echo "[$(date +%Y-%m-%dT%H:%M:%S)] [${nivel}] $*" | \
        tee -a "$AUDIT_LOG"
}

banner() {
    echo "============================================" | \
        tee -a "$AUDIT_LOG"
    echo "  EL OJO DE SAURON — PIPELINE DE AUDITORÍA " | \
        tee -a "$AUDIT_LOG"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')" | \
        tee -a "$AUDIT_LOG"
    echo "============================================" | \
        tee -a "$AUDIT_LOG"
}

run_step() {
    local paso="$1"
    local script="$2"
    shift 2
    log "INFO" "=== PASO: ${paso} ==="
    if bash "$script" "$@" >> "$AUDIT_LOG" 2>&1; then
        log "OK" "PASO [${paso}] completado."
        return 0
    else
        log "ERROR" "PASO [${paso}] FALLÓ. Pipeline detenido."
        return 1
    fi
}

run_static_analysis() {
    local repo_path="$1"
    local nombre
    nombre=$(basename "$repo_path")
    local errores=0

    log "INFO" "[${nombre}] Análisis estático iniciado."

    # flake8
    if command -v flake8 &>/dev/null; then
        log "INFO" "[${nombre}] flake8..."
        flake8 "$repo_path" \
            --max-line-length=79 \
            --statistics \
            >> "$AUDIT_LOG" 2>&1 || ((errores++))
    fi

    # black --check
    if command -v black &>/dev/null; then
        log "INFO" "[${nombre}] black --check..."
        black --check --line-length 79 "$repo_path" \
            >> "$AUDIT_LOG" 2>&1 || ((errores++))
    fi

    # mypy
    if command -v mypy &>/dev/null; then
        log "INFO" "[${nombre}] mypy..."
        mypy "$repo_path" \
            --ignore-missing-imports \
            >> "$AUDIT_LOG" 2>&1 || ((errores++))
    fi

    if [[ "$errores" -gt 0 ]]; then
        log "ERROR" \
            "[${nombre}] Análisis: ${errores} herramienta(s) KO."
        return 1
    fi

    log "OK" "[${nombre}] Análisis estático: APROBADO."
    return 0
}

update_bitacora() {
    local resultado="$1"
    local bitacora="${REPO_ROOT}/docs/bitacora_trazabilidad.md"
    local marker="<!-- Inserta nuevas entradas debajo de esta línea -->"

    # Lista de repos auditados
    local repos_lista=""
    for repo_path in "${WORKSPACES_DIR}"/*/; do
        repo_path="${repo_path%/}"
        repos_lista+="  - $(basename "$repo_path")"$'\n'
    done
    [[ -z "$repos_lista" ]] && repos_lista="  - (ninguno)"$'\n'

    # Anomalías del log (líneas ERROR/WARN)
    local anomalias=""
    anomalias=$(grep -E '\[ERROR\]|\[WARN\]' "$AUDIT_LOG" \
        | sed 's/^/  - /' || true)
    [[ -z "$anomalias" ]] && anomalias="  - Sin anomalías"

    # Bloque a insertar
    local entrada
    entrada=$(cat <<EOF

---
**Fecha y hora:** $(date '+%Y-%m-%d %H:%M:%S')
**Ejecutado por:** $(whoami)@$(hostname)
**Script ejecutado:** scripts/run_audit.sh
**Workspaces auditados:**
${repos_lista}**Resultado general:** ${resultado}
**Pasos:**
| Etapa             | Estado                     |
|-------------------|----------------------------|
| Clonación         | ${estado_clone}  |
| Pre-commit Hooks  | ${estado_hooks}  |
| Dependencias      | ${estado_deps}   |
| Análisis Estático | ${estado_static} |
**Anomalías detectadas:**
${anomalias}
**Acciones tomadas:**
  - (pendiente)
**Log referenciado:**
  \`${AUDIT_LOG}\`
---
EOF
)

    # Insertar después del marcador
    if grep -qF "$marker" "$bitacora" 2>/dev/null; then
        local tmp
        tmp=$(mktemp)
        awk -v bloque="$entrada" \
            -v marker="$marker" \
            '{print} $0 == marker {print bloque}' \
            "$bitacora" > "$tmp" && mv "$tmp" "$bitacora"
        log "INFO" "Bitácora actualizada: ${bitacora}"
    else
        log "WARN" "Marcador no encontrado en bitácora."
    fi
}

generate_report() {
    local reporte="${REPORT_DIR}/reporte_$(date +%Y%m%d_%H%M%S).md"
    mkdir -p "$REPORT_DIR"

    cat > "$reporte" <<EOF
# Reporte de Auditoría EcoSauron

**Fecha:** $(date '+%Y-%m-%d %H:%M:%S')
**Auditado por:** Agente Auditor Linux (El Ojo de Sauron)
**Log completo:** \`${AUDIT_LOG}\`

## Resumen Ejecutivo

| Etapa              | Estado  |
|--------------------|---------|
| Clonación          | ${estado_clone}  |
| Pre-commit Hooks   | ${estado_hooks}  |
| Dependencias       | ${estado_deps}   |
| Análisis Estático  | ${estado_static} |

## Repositorios Auditados

\`\`\`
$(ls -1 "${WORKSPACES_DIR}" 2>/dev/null || echo "Sin workspaces")
\`\`\`

## Log de Errores

\`\`\`
$(grep -E '\[ERROR\]|\[WARN\]' "$AUDIT_LOG" || echo "Sin errores.")
\`\`\`
EOF

    log "INFO" "Reporte generado: ${reporte}"
}

# -----------------------------------------------------------
# Inicialización
# -----------------------------------------------------------
mkdir -p "$LOG_DIR" "$WORKSPACES_DIR"
banner

estado_clone="⏳"
estado_hooks="⏳"
estado_deps="⏳"
estado_static="⏳"

# -----------------------------------------------------------
# PASO 1: Clonación
# -----------------------------------------------------------
if run_step "CLONACION" \
    "${SCRIPT_DIR}/clone_repos.sh" "$WORKSPACES_DIR"; then
    estado_clone="✅ OK"
else
    estado_clone="❌ FALLO"
fi

# -----------------------------------------------------------
# PASO 2: Setup de pre-commit hooks
# -----------------------------------------------------------
if run_step "SETUP_HOOKS" \
    "${SCRIPT_DIR}/setup_pre_commit.sh" "$WORKSPACES_DIR"; then
    estado_hooks="✅ OK"
else
    estado_hooks="❌ FALLO"
fi

# -----------------------------------------------------------
# PASO 3: Validación de dependencias
# -----------------------------------------------------------
if run_step "VALIDAR_DEPS" \
    "${SCRIPT_DIR}/validate_deps.sh" "$WORKSPACES_DIR"; then
    estado_deps="✅ OK"
else
    estado_deps="❌ FALLO"
fi

# -----------------------------------------------------------
# PASO 4: Análisis estático por repositorio
# -----------------------------------------------------------
errores_static=0
shopt -s nullglob
for repo_path in "${WORKSPACES_DIR}"/*/; do
    repo_path="${repo_path%/}"
    run_static_analysis "$repo_path" || ((errores_static++))
done

if [[ "$errores_static" -eq 0 ]]; then
    estado_static="✅ OK"
else
    estado_static="❌ ${errores_static} repo(s) con errores"
fi

# -----------------------------------------------------------
# Reporte final + bitácora
# -----------------------------------------------------------
generate_report

if [[ "${estado_clone}" == *FALLO* ]] || \
   [[ "${estado_deps}" == *FALLO* ]] || \
   [[ "${estado_static}" == *errores* ]]; then
    resultado_general="❌ FALLIDO"
else
    resultado_general="✅ APROBADO"
fi

update_bitacora "$resultado_general"

log "INFO" "Pipeline completado."
log "INFO" "Clonación:  ${estado_clone}"
log "INFO" "Hooks:      ${estado_hooks}"
log "INFO" "Deps:       ${estado_deps}"
log "INFO" "Estático:   ${estado_static}"

if [[ "$resultado_general" == *FALLIDO* ]]; then
    log "ERROR" "AUDITORÍA FALLIDA. Revisa los reportes."
    exit 1
fi

log "OK" "AUDITORÍA APROBADA. Ecosistema saludable."
exit 0
