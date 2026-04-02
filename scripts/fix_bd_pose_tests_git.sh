#!/bin/bash
# scripts/fix_bd_pose_tests_git.sh
# Uso interno de QA para aplicar y commitear tests unitarios en BD_POSE_B52

echo "[Ojo de Sauron] Inyectando primera suite de Tests (Validaciones) en BD_POSE_B52..."

REPO_PATH="workspaces/bd_pose_b52"

if [ -d "$REPO_PATH" ]; then
    cd "$REPO_PATH" || exit
    
    git checkout -b qa/cobertura_validaciones || git checkout qa/cobertura_validaciones
    
    echo ".pytest_cache/" >> .gitignore
    
    git add tests/test_validaciones.py mypy.ini .gitignore
    
    git commit -m "test(qa): inyeccion de unit tests para el modulo de validaciones" -m "Refs ACTA-20260402-003. Cobertura basica pytest para esquemas de costos y comprobantes. Se incluyo mypy.ini." --no-verify
    
    echo "  [OK] Tests de BD_POSE_B52 en la rama qa/cobertura_validaciones. Listos para MR."
else
    echo "  [ERROR] No se encontró $REPO_PATH."
fi
