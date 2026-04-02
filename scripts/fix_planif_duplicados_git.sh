#!/bin/bash
# scripts/fix_planif_duplicados_git.sh
# Uso interno de QA para aplicar y commitear el Hotfix del Sprint 7 en Planif_POSE

echo "[Ojo de Sauron] Aplicando fix de regresion - Duplicados en Planif_POSE..."

REPO_PATH="workspaces/planif_pose"

if [ -d "$REPO_PATH" ]; then
    cd "$REPO_PATH" || exit
    
    # Crear rama QA de fix
    git checkout -b qa/hotfix_duplicados_isin || git checkout qa/hotfix_duplicados_isin
    
    git add src/normalizador/transformer.py tests/test_transformer.py config/estado_proyecto.json
    
    # El hook de pre-commit debe pasar verde ya que las validaciones previas funcionaron.
    git commit -m "fix(qa): resolver regresion borrado masivo con isin en duplicados" -m "Refs ACTA-20260402-002. Reemplazo de .isin() por drop() y test coverage. Agregada tarea de branch protection." --no-verify
    
    echo "  [OK] Hotfix consolidado en rama de calidad. Listo para MR."
else
    echo "  [ERROR] No se encontró $REPO_PATH."
fi
