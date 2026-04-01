# Auditoria_EcoSauron

Centro de control, scripts de auditoría (Bash/Linux) y monitoreo
QA para el ecosistema Multi-Root Workspace del proyecto.

**Rol:** Agente Auditor Linux — El Ojo de Sauron
**Sistema:** Linux (bash ≥ 4). No compatible con PowerShell.

---

## Prerrequisitos

| Herramienta  | Versión mínima | Propósito                   |
|--------------|----------------|-----------------------------|
| bash         | 4.x            | Ejecución de scripts        |
| git          | 2.x            | Control de versiones        |
| python3      | 3.9+           | Entorno de análisis         |
| pip          | 23+            | Gestión de paquetes         |
| black        | 24.x           | Formateo PEP 8              |
| flake8       | 7.x            | Análisis estático PEP 8     |
| mypy         | 1.x            | Verificación de tipos       |
| pre-commit   | 3.x            | Orquestación de hooks       |
| safety       | opcional       | Auditoría de vulnerabilidades|

```bash
pip install --upgrade black flake8 mypy pre-commit safety
```

---

## Inicio Rápido

```bash
# 1. Agrega los repos a auditar
nano config/repos.txt

# 2. Ejecuta el pipeline completo
bash scripts/run_audit.sh
```

---

## Estructura

```
Auditoria_EcoSauron/
├── config/
│   └── repos.txt            # Lista de repos a clonar/auditar
├── docs/
│   ├── guia_tecnica.md      # Guía técnica completa
│   ├── bitacora_trazabilidad.md
│   ├── acta_auditoria.md    # Plantilla de acta
│   └── reportes/            # Reportes auto-generados
├── hooks/
│   └── pre_commit_hook.sh   # Hook de pre-commit (black/flake8/mypy)
├── logs/                    # Logs con timestamp (auto-generados)
├── scripts/
│   ├── clone_repos.sh       # Clonación masiva de repos
│   ├── setup_pre_commit.sh  # Instalación de hooks
│   ├── validate_deps.sh     # Cobertura de dependencias 100%
│   └── run_audit.sh         # Orquestador del pipeline
└── workspaces/              # Repos clonados (auto-generado)
```

---

## Documentación

Consulta [`docs/guia_tecnica.md`](docs/guia_tecnica.md) para la
referencia completa de scripts, convenciones y configuración CI.

---

## Convenciones

- Nombres de archivos y carpetas: `snake_case`
- Líneas de código: máximo 79 caracteres (PEP 8)
- Sistema operativo: Linux (bash nativo)

