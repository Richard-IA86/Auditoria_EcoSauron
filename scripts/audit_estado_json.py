#!/usr/bin/env python3
"""
audit_estado_json.py
Valida la consistencia de todos los estado_proyecto.json
del ecosistema EcoSauron.

Reglas aplicadas:
  E01 JSON_INVALIDO   — archivo no parseable
  E02 JORNADA_ANIDADA — bloque 'jornada' no está al nivel raíz
  W01 FECHA_DESFASADA — fecha_actualizacion < jornada.fin.fecha
  W02 TAREA_OBSOLETA  — texto en tareas_pendientes de repo B
                        coincide con tareas_completadas de otro repo
  W03 PIPELINE_AUSENTE — jornada.fin.estado_pipeline vacío o ausente

Salida: exit 0 si no hay errores (warnings no bloquean).
        exit 1 si hay al menos un ERROR.

Uso: python3 scripts/audit_estado_json.py [workspaces_dir]
"""

import json
import re
import sys
from pathlib import Path
from typing import Any

# ─────────────────────────────────────────────
# Configuración
# ─────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
WORKSPACES_DIR = (
    Path(sys.argv[1]) if len(sys.argv) > 1 else (REPO_ROOT / "workspaces")
)

ERRORES: list[dict[str, str]] = []
WARNINGS: list[dict[str, str]] = []


def error(repo: str, code: str, msg: str) -> None:
    ERRORES.append({"repo": repo, "code": code, "msg": msg})
    print(f"  [ERROR][{code}] {repo}: {msg}")


def warn(repo: str, code: str, msg: str) -> None:
    WARNINGS.append({"repo": repo, "code": code, "msg": msg})
    print(f"  [WARN] [{code}] {repo}: {msg}")


def ok(repo: str, msg: str) -> None:
    print(f"  [OK]          {repo}: {msg}")


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────
def get_desarrollo_local(data: dict[str, Any]) -> dict[str, Any]:
    """Extrae desarrollo_local como dict (list o dict)."""
    dl = data.get("desarrollo_local", {})
    if isinstance(dl, list):
        return dl[-1] if dl else {}
    return dl if isinstance(dl, dict) else {}


def get_jornada_fin(data: dict[str, Any]) -> dict[str, Any]:
    """Extrae jornada.fin del nivel raíz."""
    jornada = data.get("jornada", {})
    if isinstance(jornada, list):
        jornada = jornada[-1] if jornada else {}
    if not isinstance(jornada, dict):
        return {}
    return jornada.get("fin", {})


def fecha_a_int(fecha: str) -> int:
    """Convierte 'YYYY-MM-DD' a int para comparación."""
    return int(re.sub(r"[^0-9]", "", fecha[:10]))


def extraer_textos(lista: list[Any]) -> list[str]:
    """Extrae strings de una lista que puede tener dicts."""
    textos: list[str] = []
    for item in lista:
        if isinstance(item, str):
            textos.append(item.lower().strip())
        elif isinstance(item, dict):
            for campo in ("titulo", "descripcion", "tarea"):
                val = item.get(campo, "")
                if val:
                    textos.append(str(val).lower().strip())
    return textos


# ─────────────────────────────────────────────
# Carga de todos los JSONs
# ─────────────────────────────────────────────
repo_data: dict[str, dict[str, Any]] = {}

print("=" * 54)
print("  AUDIT_ESTADO_JSON — El Ojo de Sauron")
print("=" * 54)

for json_path in sorted(WORKSPACES_DIR.glob("*/config/estado_proyecto.json")):
    repo = json_path.parts[-3]

    # E01 — JSON válido
    try:
        with open(json_path, encoding="utf-8") as f:
            data: dict[str, Any] = json.load(f)
        repo_data[repo] = data
    except (json.JSONDecodeError, OSError) as exc:
        error(repo, "E01", f"JSON inválido: {exc}")
        continue

    print(f"\n[{repo}]")

    # E02 — jornada al nivel raíz
    dl = data.get("desarrollo_local", {})
    jornada_anidada = False
    if isinstance(dl, list):
        for item in dl:
            if isinstance(item, dict) and "jornada" in item:
                jornada_anidada = True
                break
    elif isinstance(dl, dict) and "jornada" in dl:
        jornada_anidada = True

    if jornada_anidada:
        error(
            repo,
            "E02",
            "Bloque 'jornada' anidado en desarrollo_local"
            " — debe estar al nivel raíz.",
        )
    else:
        ok(repo, "E02 — jornada al nivel raíz.")

    # W03 — pipeline presente
    fin = get_jornada_fin(data)
    pipeline_val = fin.get("estado_pipeline", "")
    if not pipeline_val:
        warn(
            repo,
            "W03",
            "jornada.fin.estado_pipeline vacío o ausente.",
        )
    else:
        ok(repo, f"W03 — pipeline: {pipeline_val}.")

    # W01 — coherencia de fechas
    dl_obj = get_desarrollo_local(data)
    fecha_act: str | None = dl_obj.get("fecha_actualizacion") or dl_obj.get(
        "fecha_ultima_actualizacion"
    )
    fecha_jornada: str | None = fin.get("fecha")

    if fecha_act and fecha_jornada:
        try:
            if fecha_a_int(fecha_jornada) > fecha_a_int(fecha_act):
                warn(
                    repo,
                    "W01",
                    (
                        f"jornada.fin.fecha ({fecha_jornada})"
                        f" > fecha_actualizacion ({fecha_act})"
                        " — desarrollo_local desactualizado."
                    ),
                )
            else:
                ok(
                    repo,
                    (
                        f"W01 — fechas coherentes"
                        f" ({fecha_act} / {fecha_jornada})."
                    ),
                )
        except ValueError:
            warn(repo, "W01", "Fechas no parseables para comparar.")
    else:
        warn(
            repo,
            "W01",
            "Falta fecha_actualizacion o jornada.fin.fecha.",
        )

# ─────────────────────────────────────────────
# W02 — referencias cruzadas obsoletas
# Compara pendientes de cada repo contra completadas
# del resto del ecosistema.
# ─────────────────────────────────────────────
print("\n[cruce entre repos]")

completadas_global: dict[str, list[str]] = {}
for repo, data in repo_data.items():
    dl_obj = get_desarrollo_local(data)
    fin = get_jornada_fin(data)
    completadas = extraer_textos(
        dl_obj.get("tareas_completadas", [])
        + fin.get("tareas_completadas", [])
    )
    completadas_global[repo] = completadas

for repo, data in repo_data.items():
    dl_obj = get_desarrollo_local(data)
    fin = get_jornada_fin(data)
    pendientes = extraer_textos(
        dl_obj.get("tareas_pendientes", [])
        + fin.get("tareas_pendientes_manana", [])
    )

    for otro_repo, completadas in completadas_global.items():
        if otro_repo == repo:
            continue
        for pendiente in pendientes:
            # Búsqueda por palabras clave significativas (≥6 chars)
            palabras = [w for w in re.split(r"\W+", pendiente) if len(w) >= 6]
            for completada in completadas:
                coincidencias = sum(1 for p in palabras if p in completada)
                umbral = max(2, len(palabras) // 3)
                if coincidencias >= umbral:
                    warn(
                        repo,
                        "W02",
                        (
                            f"Tarea pendiente posiblemente obsoleta"
                            f" (completada en {otro_repo}):\n"
                            f"    PENDIENTE : {pendiente[:72]}\n"
                            f"    COMPLETADA: {completada[:72]}"
                        ),
                    )
                    break

if not WARNINGS and not ERRORES:
    ok("cruce", "W02 — Sin referencias cruzadas obsoletas.")
elif not any(w["code"] == "W02" for w in WARNINGS):
    ok("cruce", "W02 — Sin referencias cruzadas obsoletas.")

# ─────────────────────────────────────────────
# Resumen final
# ─────────────────────────────────────────────
print("\n" + "=" * 54)
print(f"  Errores  : {len(ERRORES)}")
print(f"  Warnings : {len(WARNINGS)}")
print("=" * 54)

if ERRORES:
    print("\nERRORES (bloquean pipeline):")
    for e in ERRORES:
        print(f"  [{e['code']}] {e['repo']}: {e['msg']}")

if WARNINGS:
    print("\nWARNINGS (no bloquean):")
    for w in WARNINGS:
        print(f"  [{w['code']}] {w['repo']}: {w['msg']}")

if ERRORES:
    sys.exit(1)

print("\nEstado JSON: OK")
sys.exit(0)
