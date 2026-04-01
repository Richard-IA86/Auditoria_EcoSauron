# Guía Técnica — Agente Auditor Linux (El Ojo de Sauron)

## Descripción General

Este repositorio contiene la infraestructura de control de
calidad (QA), integración continua local y auditoría de código
para el ecosistema Multi-Root Workspace del proyecto EcoSauron.

**No desarrolla aplicaciones. Controla y asegura la calidad
estricta del código en los repositorios externos.**

---

## Estructura del Repositorio

```
Auditoria_EcoSauron/
├── config/
│   └── repos.txt            # Lista de repos a auditar
├── docs/
│   ├── guia_tecnica.md      # Este documento
│   ├── bitacora_trazabilidad.md
│   ├── acta_auditoria.md
│   └── reportes/            # Reportes auto-generados
├── hooks/
│   └── pre_commit_hook.sh   # Hook de pre-commit reutilizable
├── logs/                    # Logs de ejecución (auto-generados)
├── scripts/
│   ├── clone_repos.sh       # Clonación masiva
│   ├── setup_pre_commit.sh  # Instalación de hooks
│   ├── validate_deps.sh     # Validación de dependencias
│   └── run_audit.sh         # Orquestador principal
└── workspaces/              # Repos clonados (auto-generado)
```

---

## Requisitos del Sistema

| Herramienta  | Versión mínima | Propósito                    |
|--------------|----------------|------------------------------|
| bash         | 4.x            | Ejecución de scripts         |
| git          | 2.x            | Control de versiones         |
| python3      | 3.9+           | Entorno de análisis          |
| pip          | 23+            | Gestión de paquetes          |
| black        | 24.x           | Formateo PEP 8               |
| flake8       | 7.x            | Análisis estático PEP 8      |
| mypy         | 1.x            | Verificación de tipos        |
| pre-commit   | 3.x            | Orquestación de hooks        |
| safety       | opcional       | Auditoría de vulnerabilidades|

### Instalación rápida de herramientas Python

```bash
pip install --upgrade black flake8 mypy pre-commit safety
```

---

## Scripts — Referencia Rápida

### `scripts/clone_repos.sh`

Clona o actualiza todos los repositorios listados en
`config/repos.txt`.

```bash
# Uso básico (clona en ./workspaces/)
bash scripts/clone_repos.sh

# Directorio personalizado
bash scripts/clone_repos.sh /ruta/workspaces
```

**Formato de `config/repos.txt`:**
```
# Comentario
https://github.com/org/repo_uno
https://github.com/org/repo_dos  alias_local
```

---

### `scripts/setup_pre_commit.sh`

Instala el hook `pre_commit_hook.sh` en cada repo del workspace
y crea `.pre-commit-config.yaml` si no existe.

```bash
bash scripts/setup_pre_commit.sh [directorio_workspaces]
```

---

### `scripts/validate_deps.sh`

Verifica cobertura de dependencias al 100% usando `pip check`
y (si está disponible) `safety check`.

```bash
bash scripts/validate_deps.sh [directorio_workspaces]
```

**Archivos detectados automáticamente:**
- `requirements.txt`
- `pyproject.toml`
- `setup.cfg`

---

### `scripts/run_audit.sh`

Orquestador completo del pipeline. Ejecuta los 4 pasos en
secuencia y genera un reporte Markdown en `docs/reportes/`.

```bash
bash scripts/run_audit.sh [directorio_workspaces]
```

**Pasos del pipeline:**
1. Clonación masiva
2. Setup de pre-commit hooks
3. Validación de dependencias
4. Análisis estático (black, flake8, mypy)

---

## Convenciones Obligatorias

| Regla                        | Estándar       |
|------------------------------|----------------|
| Nombres de archivos          | snake_case     |
| Líneas de código             | ≤ 79 caracteres|
| Estilo Python                | PEP 8          |
| Sistema operativo            | Linux (bash)   |

---

## Logs

Todos los scripts generan logs con timestamp en `logs/`:

```
logs/clone_repos_YYYYMMDD_HHMMSS.log
logs/setup_precommit_YYYYMMDD_HHMMSS.log
logs/validate_deps_YYYYMMDD_HHMMSS.log
logs/auditoria_YYYYMMDD_HHMMSS.log
```

Formato de cada línea:
```
[YYYY-MM-DDTHH:MM:SS] [NIVEL] Mensaje
```

Niveles: `INFO` | `OK` | `WARN` | `ERROR`

---

## Integración CI/CD Local

Para ejecutar el pipeline completo desde cron o CI local:

```bash
# Auditoría diaria a las 03:00
0 3 * * * /ruta/scripts/run_audit.sh >> /var/log/sauron.log 2>&1
```

---

*Documento mantenido por el Agente Auditor Linux — El Ojo de
Sauron.*
