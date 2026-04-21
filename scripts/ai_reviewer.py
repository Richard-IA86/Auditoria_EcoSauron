#!/usr/bin/env python3
"""Revisor de PRs via Gemini API — Sauron QA Orquestador."""

import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

_BASE = Path(__file__).parent.parent
CONFIG_PATH = _BASE / "config" / "sauron_rules.json"
_GEMINI_URL = (
    "https://generativelanguage.googleapis.com"
    "/v1beta/models/{model}:generateContent"
)


def cargar_config() -> dict[str, Any]:
    """Carga sauron_rules.json desde config/."""
    with open(CONFIG_PATH, encoding="utf-8") as fh:
        data: dict[str, Any] = json.load(fh)
    return data


def buscar_bloqueados(diff: str, patrones: list[str]) -> list[str]:
    """Retorna patrones de seguridad hallados en el diff."""
    return [p for p in patrones if re.search(p, diff, re.IGNORECASE)]


def es_solo_markdown(diff: str) -> bool:
    """True si el diff solo modifica archivos .md."""
    archivos = [ln for ln in diff.splitlines() if ln.startswith("diff --git")]
    return bool(archivos) and all(".md" in ln for ln in archivos)


def llamar_gemini(
    diff: str,
    config: dict[str, Any],
    api_key: str,
) -> dict[str, Any]:
    """Envía diff a Gemini Flash y retorna respuesta raw."""
    modelo = str(config.get("gemini_model", "gemini-1.5-flash"))
    url = _GEMINI_URL.format(model=modelo)
    instruccion = str(config.get("prompt_system", "Revisa este diff de PR."))
    prompt = (
        f"{instruccion}\n\n"
        "Responde SOLO con este JSON (sin bloques markdown):\n"
        '{"verdict":"APPROVE","body":"comentario"}\n'
        "o\n"
        '{"verdict":"REQUEST_CHANGES","body":"comentario"}\n\n'
        f"DIFF:\n{diff}"
    )
    payload = {"contents": [{"parts": [{"text": prompt}]}]}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": api_key,
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw: dict[str, Any] = json.loads(resp.read().decode("utf-8"))
    return raw


def parsear_respuesta(raw: dict[str, Any]) -> dict[str, str]:
    """Extrae veredicto JSON de la respuesta de Gemini."""
    try:
        texto: str = raw["candidates"][0]["content"]["parts"][0]["text"]
        inicio = texto.find("{")
        fin = texto.rfind("}") + 1
        if inicio != -1 and fin > inicio:
            resultado: dict[str, str] = json.loads(texto[inicio:fin])
            return resultado
    except (KeyError, IndexError, json.JSONDecodeError):
        pass
    return {
        "verdict": "REQUEST_CHANGES",
        "body": "No se pudo parsear la respuesta de Gemini.",
    }


def main() -> int:
    """Punto de entrada principal del revisor."""
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        print("GEMINI_API_KEY no configurada. Omitiendo.")
        return 0

    diff = sys.stdin.read()
    if not diff.strip():
        print(json.dumps({"verdict": "APPROVE", "body": "Diff vacío."}))
        return 0

    config = cargar_config()

    # 1 — Seguridad: patrones bloqueados
    patrones: list[str] = config.get("blocked_patterns", [])
    encontrados = buscar_bloqueados(diff, patrones)
    if encontrados:
        print(
            json.dumps(
                {
                    "verdict": "REQUEST_CHANGES",
                    "body": (
                        "Patrones de seguridad detectados: "
                        + ", ".join(encontrados)
                    ),
                }
            )
        )
        return 0

    # 2 — Auto-aprobar si solo hay cambios .md
    if es_solo_markdown(diff):
        print(
            json.dumps(
                {
                    "verdict": "APPROVE",
                    "body": (
                        "Solo cambios Markdown. " "Auto-aprobado por Sauron."
                    ),
                }
            )
        )
        return 0

    # 3 — Límite de tamaño del diff
    max_lines = int(config.get("max_diff_lines", 300))
    n_lines = len(diff.splitlines())
    if n_lines > max_lines:
        print(
            json.dumps(
                {
                    "verdict": "REQUEST_CHANGES",
                    "body": (
                        f"Diff muy grande ({n_lines} líneas)."
                        f" Máximo permitido: {max_lines}."
                    ),
                }
            )
        )
        return 0

    # 4 — Revisión por Gemini
    try:
        raw = llamar_gemini(diff, config, api_key)
        resultado = parsear_respuesta(raw)
    except urllib.error.HTTPError as exc:
        print(
            f"HTTP {exc.code} desde Gemini: {exc.reason}",
            file=sys.stderr,
        )
        return 1
    except urllib.error.URLError as exc:
        print(
            f"Error de conexión Gemini: {exc}",
            file=sys.stderr,
        )
        return 1

    print(json.dumps(resultado))
    return 0


if __name__ == "__main__":
    sys.exit(main())
