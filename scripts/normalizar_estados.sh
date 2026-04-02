#!/bin/bash
# scripts/normalizar_estados.sh
# El Ojo de Sauron - Normalización de JSON de tareas al nuevo estándar de gobierno

echo "[Ojo de Sauron] Iniciando normalización de estados QA en Workspaces..."

python3 -c '
import os, json, glob

workspaces = glob.glob("workspaces/*/")

nuevo_esquema = {"auditoria_qa": [], "desarrollo_local": []}

for ws in workspaces:
    print(f"\n=> Analizando Workspace: {ws}")
    config_dir = os.path.join(ws, "config")
    os.makedirs(config_dir, exist_ok=True)
    
    target = os.path.join(config_dir, "estado_proyecto.json")
    
    archivos_viejos = [
        os.path.join(ws, "estado_implementacion.json"),
        os.path.join(ws, "estado_tareas.json"),
        os.path.join(ws, "config", "estado_tareas.json"),
        os.path.join(ws, "punto_de_partida.json")
    ]
    
    tareas_viejas = []
    for old_f in archivos_viejos:
        if os.path.exists(old_f):
            print(f"  [+] Migrando datos heredados de: {old_f}")
            try:
                with open(old_f, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        tareas_viejas.append(data)
                    elif isinstance(data, list):
                        tareas_viejas.extend(data)
            except Exception as e:
                print(f"  [!] Error leyendo {old_f}: {e}")
            
            # Renombrar para no interrumpir el pipeline si alguien lo busca, pero marcarlo obsoleto
            os.rename(old_f, old_f + ".bak")
            print(f"  [OBSOLETO] renombrado a {old_f}.bak")
    
    # Crear o actualizar el nuevo esquema
    esquema_actual = {"auditoria_qa": [], "desarrollo_local": []}
    if os.path.exists(target):
        with open(target, "r", encoding="utf-8") as f:
            try:
                esquema_actual = json.load(f)
            except json.JSONDecodeError:
                pass
                
    if tareas_viejas and not esquema_actual.get("desarrollo_local"):
        esquema_actual["desarrollo_local"] = tareas_viejas
        
    with open(target, "w", encoding="utf-8") as f:
        json.dump(esquema_actual, f, indent=4, ensure_ascii=False)
        
    print(f"  [OK] Creado estándar: {target}")

print("\n[Ojo de Sauron] Normalización JSON completada.")
'
