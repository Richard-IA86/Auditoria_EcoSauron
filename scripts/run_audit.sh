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

# python3 del sistema para ejecutar los tests de los repos.
# Se fija explícitamente para que el venv del auditor
# (si está activo) no interfiera con pytest de los repos.
SYS_PYTHON3="/usr/bin/python3"

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

    # flake8 — cd al repo para leer setup.cfg local (extend-ignore, etc.)
    if command -v flake8 &>/dev/null; then
        log "INFO" "[${nombre}] flake8..."
        (cd "$repo_path" && flake8 . \
            --max-line-length=79 \
            --statistics \
            >> "$AUDIT_LOG" 2>&1) || ((errores++))
    fi

    # black --check — cd al repo para leer pyproject.toml local
    if command -v black &>/dev/null; then
        log "INFO" "[${nombre}] black --check..."
        (cd "$repo_path" && black --check --line-length 79 . \
            >> "$AUDIT_LOG" 2>&1) || ((errores++))
    fi

    # mypy
    if command -v mypy &>/dev/null; then
        log "INFO" "[${nombre}] mypy..."
        (cd "$repo_path" && mypy . \
            --ignore-missing-imports \
            >> "$AUDIT_LOG" 2>&1) || ((errores++))
    fi

    # pymarkdown — linting de archivos .md en docs/
    if command -v pymarkdown &>/dev/null; then
        local md_dir="${repo_path}/docs"
        if [[ -d "$md_dir" ]]; then
            log "INFO" "[${nombre}] pymarkdown (docs/)..."
            local md_cfg="${REPO_ROOT}/config/markdownlint.json"
            local md_args=()
            [[ -f "$md_cfg" ]] && md_args=("-c" "$md_cfg")
            if ! pymarkdown "${md_args[@]}" scan \
                    --recurse "$md_dir" \
                    >> "$AUDIT_LOG" 2>&1; then
                log "WARN" \
                    "[${nombre}] pymarkdown: infracciones .md en docs/."
            else
                log "INFO" \
                    "[${nombre}] pymarkdown docs/: OK."
            fi
        fi
    fi

    if [[ "$errores" -gt 0 ]]; then
        log "ERROR" \
            "[${nombre}] Análisis: ${errores} herramienta(s) KO."
        return 1
    fi

    log "OK" "[${nombre}] Análisis estático: APROBADO."
    return 0
}

run_tests() {
    local repo_path="$1"
    local nombre
    nombre=$(basename "$repo_path")

    if [[ ! -d "${repo_path}/tests" ]]; then
        log "INFO" "[${nombre}] Sin directorio tests/ — saltando."
        return 0
    fi

    log "INFO" "[${nombre}] pytest..."
    if (cd "$repo_path" && "$SYS_PYTHON3" -m pytest tests/ \
            --tb=short -q >> "$AUDIT_LOG" 2>&1); then
        log "OK" "[${nombre}] Tests: APROBADO."
        return 0
    else
        log "ERROR" "[${nombre}] Tests: FALLIDO."
        return 1
    fi
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
| Ramas GitHub      | ${estado_ramas}  |
| Clonación         | ${estado_clone}  |
| Pre-commit Hooks  | ${estado_hooks}  |
| Dependencias      | ${estado_deps}   |
| Análisis Estático | ${estado_static} |
| Tests Unitarios   | ${estado_tests}  |
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
|--------------------|---------|| Ramas GitHub       | ${estado_ramas}  || Clonación          | ${estado_clone}  |
| Pre-commit Hooks   | ${estado_hooks}  |
| Dependencias       | ${estado_deps}   |
| Análisis Estático  | ${estado_static} |
| Tests Unitarios    | ${estado_tests}  |

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

estado_ramas="⏳"
estado_clone="⏳"
estado_hooks="⏳"
estado_deps="⏳"
estado_static="⏳"
estado_tests="⏳"

# -----------------------------------------------------------
# PASO 0: Verificación de ramas huérfanas (no bloqueante)
# Detecta ramas remotas sin PR en GitHub. Solo emite WARN;
# no detiene el pipeline para no bloquear CI/cron.
# -----------------------------------------------------------
log "INFO" "=== PASO: VERIFICAR_RAMAS ==="
if bash "${SCRIPT_DIR}/verificar_ramas.sh" >> "$AUDIT_LOG" 2>&1; then
    estado_ramas="✅ OK"
    log "OK" "PASO [VERIFICAR_RAMAS] Sin ramas huérfanas."
else
    estado_ramas="⚠️  WARN"
    log "WARN" \
        "PASO [VERIFICAR_RAMAS] Ramas sin PR detectadas — revisar."
fi

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
# PASO 5: Tests unitarios por repositorio
# -----------------------------------------------------------
errores_tests=0
for repo_path in "${WORKSPACES_DIR}"/*/; do
    repo_path="${repo_path%/}"
    run_tests "$repo_path" || ((errores_tests++))
done

if [[ "$errores_tests" -eq 0 ]]; then
    estado_tests="✅ OK"
else
    estado_tests="❌ ${errores_tests} repo(s) con errores"
fi

# -----------------------------------------------------------
# PASO 6: pymarkdown — actas del orquestador (solo WARN)
# -----------------------------------------------------------
estado_markdown="✅ OK"
if command -v pymarkdown &>/dev/null; then
    local_actas="${REPO_ROOT}/docs/actas"
    md_cfg="${REPO_ROOT}/config/markdownlint.json"
    md_args=()
    [[ -f "$md_cfg" ]] && md_args=("-c" "$md_cfg")
    if [[ -d "$local_actas" ]]; then
        log "INFO" "[orquestador] pymarkdown actas..."
        if ! pymarkdown "${md_args[@]}" scan \
                --recurse "$local_actas" \
                >> "$AUDIT_LOG" 2>&1; then
            estado_markdown="⚠️  WARN (deuda en actas)"
            log "WARN" \
                "[orquestador] pymarkdown: actas con infracciones."
        fi
    fi
fi

# -----------------------------------------------------------
# Reporte final + bitácora
# -----------------------------------------------------------
generate_report

if [[ "${estado_clone}" == *FALLO* ]] || \
   [[ "${estado_deps}" == *FALLO* ]] || \
   [[ "${estado_static}" == *errores* ]] || \
   [[ "${estado_tests}" == *errores* ]]; then
    resultado_general="❌ FALLIDO"
else
    resultado_general="✅ APROBADO"
fi

update_bitacora "$resultado_general"

log "INFO" "Pipeline completado."
log "INFO" "Ramas:      ${estado_ramas}"
log "INFO" "Clonación:  ${estado_clone}"
log "INFO" "Hooks:      ${estado_hooks}"
log "INFO" "Deps:       ${estado_deps}"
log "INFO" "Estático:   ${estado_static}"
log "INFO" "Tests:      ${estado_tests}"

if [[ "$resultado_general" == *FALLIDO* ]]; then
    log "ERROR" "AUDITORÍA FALLIDA. Revisa los reportes."
    exit 1
fi

log "OK" "AUDITORÍA APROBADA. Ecosistema saludable."
exit 0
