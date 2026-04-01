# Auditoria_EcoSauron

![Última actualización](https://img.shields.io/github/last-commit/Richard-IA86/Auditoria_EcoSauron)
![Licencia](https://img.shields.io/github/license/Richard-IA86/Auditoria_EcoSauron)
![Bash](https://img.shields.io/badge/shell-bash%20%E2%89%A54.x-blue)
![Python](https://img.shields.io/badge/python-3.9%2B-blue)

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

# 3. (Opcional) Corregir violaciones en BD_POSE_B52
bash scripts/fix_bd_pose_b52.sh
```

### Auditoría automática diaria

El cron ejecuta el pipeline cada día a las 06:00:

```
0 6 * * * /home/richard/Dev/auditoria_ecosauron/scripts/cron_auditoria.sh
```

Log del sistema: `/var/log/ecosauron_auditoria.log`  
Si la auditoría falla, aparece una alerta al abrir la terminal.

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
│   ├── run_audit.sh         # Orquestador del pipeline
│   ├── cron_auditoria.sh    # Wrapper para ejecución por cron
│   └── fix_bd_pose_b52.sh   # Corrección de violaciones BD_POSE_B52
└── workspaces/              # Repos clonados (auto-generado)
```

---

## Estado del Ecosistema

| Repositorio | flake8 | black | mypy | Estado |
|-------------|--------|-------|------|--------|
| bd_pose_b52 | ⚠️ | ✅ | ⚠️ merge incompleto | REQUIERE ACCIÓN |
| data_analytics | ✅ | ✅ | ✅ | APROBADO |
| planif_pose | ✅ | ✅ | ✅ | APROBADO |
| richard_ia86_dev | ✅ | ✅ | ✅ | APROBADO |

*Última auditoría: 2026-04-01*

---

## Documentación

Consulta [`docs/guia_tecnica.md`](docs/guia_tecnica.md) para la
referencia completa de scripts, convenciones y configuración CI.

| Documento | Descripción |
|-----------|-------------|
| [docs/guia_tecnica.md](docs/guia_tecnica.md) | Referencia técnica de scripts |
| [docs/bitacora_trazabilidad.md](docs/bitacora_trazabilidad.md) | Historial de ejecuciones |
| [docs/actas/ACTA-20260401-001.md](docs/actas/ACTA-20260401-001.md) | Acta Sprint 1 |
| [docs/actas/ACTA-20260401-002.md](docs/actas/ACTA-20260401-002.md) | Acta Sprint 2 |

---

## Convenciones

- Nombres de archivos y carpetas: `snake_case`
- Líneas de código: máximo 79 caracteres (PEP 8)
- Sistema operativo: Linux (bash nativo)

