# Guía Técnica — Agente Auditor Linux (El Ojo de Sauron)

## Descripción General

Este repositorio contiene la infraestructura de control de
calidad (QA), integración continua local y auditoría de código
para el ecosistema Multi-Root Workspace del proyecto EcoSauron.

**No desarrolla aplicaciones. Controla y asegura la calidad
estricta del código en los repositorios externos.**

---

## Estructura del Repositorio

```text
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
| safety       | opcional       | Auditoría de vulnerabilidades (**no bloquea el pipeline**, emite `WARN`)|

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

```text
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

> **Comportamiento de `safety`:** si detecta vulnerabilidades emite
> `[WARN]` en el log pero **no detiene el pipeline**. Se recomienda
> resolverlas en el sprint siguiente.

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

```text
logs/clone_repos_YYYYMMDD_HHMMSS.log
logs/setup_precommit_YYYYMMDD_HHMMSS.log
logs/validate_deps_YYYYMMDD_HHMMSS.log
logs/auditoria_YYYYMMDD_HHMMSS.log
```

Formato de cada línea:

```text
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

## Transferencia de Servicio

> Este apartado existe para que el sistema sobreviva
> independientemente de quién lo construyó.
> Si el responsable actual no estuviera disponible, esta
> sección es el punto de partida para que otra persona
> retome el control sin perder nada.

### Principio de diseño

Todo el sistema está construido sobre:

- **Código abierto** (sin dependencias propietarias críticas)
- **Git como única fuente de verdad** (GitHub — accesible con
  credenciales propias)
- **Infraestructura reproducible** (cualquier servidor Linux
  Ubuntu 24.04 puede alojar el sistema con los scripts del repo)

Cambiar de titular no requiere reescribir nada.
Solo requiere transferir el acceso a las cuentas.

---

### Cuentas a transferir

| Cuenta | Servicio | Acción |
|--------|----------|--------|
| **GitHub** `Richard-IA86` | Repos del ecosistema | Transferir repos o agregar co-owner como admin |
| **Hetzner Cloud** | VPS (API + BD + frontend) | Cambiar titular y email de facturación |
| **Cloudflare** | DNS + proxy + SSL | Cambiar email de la cuenta |
| **NIC Argentina** | Dominio `.com.ar` | Formulario de transferencia en nic.ar (requiere DNI) |
| **Dependabot / GH Actions** | CI/CD | Se transfiere automáticamente con el repo |

---

### Datos críticos que NO están en GitHub

Estos elementos no se versionar por seguridad.
Deben estar documentados en un gestor de contraseñas
(ej: Bitwarden, 1Password) accesible al nuevo titular:

| Ítem | Descripción |
|------|-------------|
| `conexion.template.json` | Credenciales de conexión a SQL Server (usuario + contraseña SA) |
| Claves SSH del servidor | Par de claves en `~/.ssh/` de la iMac — el servidor solo acepta esa clave pública |
| Pares de claves WireGuard | Generados en la iMac — `wg genkey` produce claves que NO se pushean |
| JWT secret key | Variable de entorno en FastAPI — no está en el repo |
| Hetzner API token | Para gestión del servidor por CLI |

**Acción recomendada:** exportar todos estos ítems a un
gestor de contraseñas compartido con el responsable de
continuidad antes de iniciar Sprint 17.

---

### Procedimiento mínimo de recuperación

Si se pierde acceso total y hay que reconstruir desde cero:

```bash
# 1. Clonar el orquestador (todo parte desde aquí)
git clone https://github.com/Richard-IA86/Auditoria_EcoSauron.git
cd Auditoria_EcoSauron

# 2. Clonar todos los repos del ecosistema
bash scripts/clone_repos.sh

# 3. Instalar dependencias Python
pip install black flake8 mypy pymarkdown

# 4. Ejecutar pipeline completo
bash scripts/run_audit.sh
```

El sistema vuelve a estar operativo en un servidor nuevo
en menos de 2 horas siguiendo la guía de infraestructura
del Sprint 17 (`docs/sprint17_arquitectura_pose.md`).

---

### Contactos de soporte por componente

| Componente | Documentación oficial |
|------------|----------------------|
| Ubuntu 24.04 | ubuntu.com/server/docs |
| PostgreSQL | postgresql.org/docs |
| FastAPI | fastapi.tiangolo.com |
| Next.js | nextjs.org/docs |
| WireGuard | wireguard.com/quickstart |
| Hetzner Cloud | docs.hetzner.com |
| Cloudflare | developers.cloudflare.com |
| Let's Encrypt | certbot.eff.org |

---

*Documento mantenido por el Agente Auditor Linux — El Ojo de
Sauron.*
