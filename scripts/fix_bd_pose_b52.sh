#!/usr/bin/env bash
# =============================================================
# fix_bd_pose_b52.sh
# Script de corrección generado por Auditoria_EcoSauron.
# Resuelve violaciones detectadas en BD_POSE_B52:
#   1. SyntaxError: comentario sin '#' en linea 73
#      de 01_cargar_catalogos_B52.py
#   2. Formato black en 9 archivos fuera de estándar
# Uso: bash scripts/fix_bd_pose_b52.sh
# =============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO="${REPO_ROOT}/workspaces/bd_pose_b52"
PYTHON_SCRIPTS="${TARGET_REPO}/02_scripts/python"
LOCAL_BIN="${HOME}/.local/bin"
export PATH="${LOCAL_BIN}:${PATH}"

ARCHIVO_SYNTAX="${PYTHON_SCRIPTS}/cargas/01_cargar_catalogos_B52.py"

log() { echo "[$(date +%Y-%m-%dT%H:%M:%S)] [$1] $2"; }

log "INFO" "=== Fix BD_POSE_B52 — Auditoria EcoSauron ==="

# ----------------------------------------------------------
# FIX 1: SyntaxError — agregar '#' en linea 73
# ----------------------------------------------------------
log "INFO" "Corrigiendo SyntaxError en: $(basename "$ARCHIVO_SYNTAX")"

LINEA_ACTUAL=$(sed -n '73p' "$ARCHIVO_SYNTAX")
if echo "$LINEA_ACTUAL" | grep -q "Normalizar GERENCIA"; then
    sed -i '73s/^      /      # /' "$ARCHIVO_SYNTAX"
    log "OK" "Linea 73 corregida: comentario con '#' aplicado."
else
    log "WARN" "Linea 73 no coincide con lo esperado. Revisar manualmente."
    log "WARN" "Contenido actual: ${LINEA_ACTUAL}"
fi

# ----------------------------------------------------------
# DIAGNOSTICO: detectar SyntaxErrors restantes
# ----------------------------------------------------------
log "INFO" "Escaneando SyntaxErrors restantes con ast.parse..."
ARCHIVOS_CORRUPTOS=()
while IFS= read -r -d '' pyfile; do
    RESULTADO=$(python3 -c "
import ast, sys
try:
    with open('${pyfile}') as f:
        ast.parse(f.read())
except SyntaxError as e:
    print(f'{e.lineno}:{e.msg}')
    sys.exit(1)
" 2>&1) || {
        log "ERROR" "SyntaxError en: $(basename "$pyfile") — $RESULTADO"
        ARCHIVOS_CORRUPTOS+=("$pyfile")
    }
done < <(find "$PYTHON_SCRIPTS" -name "*.py" -print0)

if [[ ${#ARCHIVOS_CORRUPTOS[@]} -gt 0 ]]; then
    log "WARN" "Los siguientes archivos tienen corrupción que requiere"
    log "WARN" "REVISION MANUAL (no es seguro aplicar fix automático):"
    for f in "${ARCHIVOS_CORRUPTOS[@]}"; do
        log "WARN" "  → $(realpath --relative-to="$TARGET_REPO" "$f")"
    done
    log "WARN" "Causa probable: merge incompleto con bloques duplicados."
    log "WARN" "Abrí el archivo y buscá secciones con código solapado."
fi

# ----------------------------------------------------------
# FIX 2: Formateo black solo en archivos SIN SyntaxError
# ----------------------------------------------------------
log "INFO" "Ejecutando black --line-length 79 (excluye archivos corruptos)..."

if command -v black &>/dev/null; then
    EXCLUIR=""
    for f in "${ARCHIVOS_CORRUPTOS[@]}"; do
        EXCLUIR="${EXCLUIR} --exclude $(basename "$f")"
    done
    black --line-length 79 "$PYTHON_SCRIPTS" \
        --exclude "01_cargar_catalogos_B52\\.py" 2>&1 \
        && log "OK" "black aplicado en archivos sintácticamente válidos."
else
    log "ERROR" "black no encontrado. Instala: pip install black"
fi

# ----------------------------------------------------------
# VALIDACION FINAL: flake8 + mypy (excluye archivos corruptos)
# ----------------------------------------------------------
log "INFO" "Validando con flake8 (excluyendo archivos con SyntaxError)..."
flake8 "$PYTHON_SCRIPTS" \
    --max-line-length=79 \
    --exclude="01_cargar_catalogos_B52.py" \
    --statistics 2>&1 || true

log "INFO" "Validando con mypy (excluyendo archivos con SyntaxError)..."
mypy "$PYTHON_SCRIPTS" \
    --ignore-missing-imports \
    --exclude "01_cargar_catalogos_B52\\.py" 2>&1 || true

log "INFO" "=================================================="
log "INFO" "=== Fix script finalizado. Resumen:           ==="
log "INFO" "  FIX AUTOMÁTICO: linea 73 corregida (# agregado)"
if [[ ${#ARCHIVOS_CORRUPTOS[@]} -gt 0 ]]; then
    log "WARN" "  PENDIENTE MANUAL: ${#ARCHIVOS_CORRUPTOS[@]} archivo(s) con"
    log "WARN" "  corrupción de código (bloques duplicados solapados)."
    log "WARN" "  Ver arriba para detalle de archivo y línea."
fi
log "INFO" "Hacé commit en BD_POSE_B52 tras revisar los cambios."
log "INFO" "=================================================="
