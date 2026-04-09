# Proyecto de Mejora — El Ojo de Sauron en Asus/Linux

> **Fecha de inicio:** 2026-04-09
> **Autor:** El Ojo de Sauron — Agente Auditor QA
> **Estado:** BORRADOR — en definición

---

## 1. Resumen Ejecutivo

El Ojo de Sauron ya opera en Asus/Linux como motor CI/CD principal
del ecosistema Grupo POSE. Sin embargo, su cobertura actual tiene
**tres brechas críticas** que limitan la solidez del pipeline:

1. **Sin integración real con SQLEXPRESS** — pyodbc instalado pero
   sin driver ODBC de Microsoft para Linux ni SQL Server local.
   Los tests de BD usan mocks.
2. **Scripts Windows fuera de auditoría** — 7 `.bat`, 7 `.ps1`,
   143 `.pq` no tienen lint en el pipeline QA.
3. **win32com excluido de mypy** — `Paso2_ActualizarPQ.py` está
   fuera del análisis estático por dependencia Windows-only.

Este documento define el plan para cerrar esas brechas y llevar
el pipeline a cobertura completa sobre Asus/Linux.

---

## 2. Arquitectura Actual — "Asus" vs "HP"

```text
┌──────────────────────────────────────────────┐
│  ASUS (Linux Ubuntu 24.04)                   │
│  Motor CI/CD Principal                       │
│                                              │
│  run_audit.sh (5 pasos — 33 s)               │
│  ├── PASO 1: verificar ramas                 │
│  ├── PASO 2: clonar/actualizar repos         │
│  ├── PASO 3: hooks pre-commit                │
│  ├── PASO 4: dependencias Python             │
│  └── PASO 5: black + flake8 + mypy + pytest  │
│                                              │
│  python3-pyodbc (apt) — sin msodbcsql        │
│  SQLEXPRESS: NO instalado localmente ← GAP   │
└──────────────────────────────────────────────┘
        │
        │ git push/pull (GitHub)
        ▼
┌──────────────────────────────────────────────┐
│  HP (Windows 10/11)                          │
│  Simulador de máquina de usuario final       │
│                                              │
│  SOLO para:                                  │
│  - demo_presentacion.bat → lanzar_demo.py    │
│  - Dashboard Streamlit (UX)                  │
│  - Power Query (.pq) en Excel                │
│  NO corre run_audit.sh ni el pipeline QA     │
└──────────────────────────────────────────────┘
```

**Regla de oro:**

- Asus audita, valida, ejecuta CI/CD, carga BD, corre tests.
- HP solo valida la experiencia del usuario final (UX manual).

---

## 3. Lo Que Ya Funciona en Asus (Inventario)

| Capacidad | Estado |
|---|---|
| black — formato Python 4 repos | ✅ |
| flake8 — linting Python PEP8 (79 chars) | ✅ |
| mypy — tipado estático Python | ✅ |
| pytest — 231 tests automatizados | ✅ |
| pre-commit hooks (4 repos) | ✅ |
| pymarkdown — linting Markdown docs | ✅ |
| Verificación de ramas (gobierno) | ✅ |
| Clonación automática workspaces | ✅ |
| Gestión dependencias pip | ✅ |
| Actas y bitácora automáticas | ✅ |

**Cobertura actual: ~75% del ecosistema.**
El 25% restante lo forman las brechas documentadas abajo.

---

## 4. GAPs Identificados

### GAP 1 — Driver ODBC sin configurar en Linux (CRÍTICO)

**Estado real (confirmado 2026-04-09):**

SQL Server Express **SÍ está instalado** en Asus, corriendo como
instancia Windows: `RICHARD_ASUS\SQLEXPRESS`.
La BD de producción es `DW_GrupoPOSE_Informes`.
SSMS está instalado en Asus (Windows) y conecta con autenticación Windows.

El problema es que el **lado Linux** (WSL2 / Ubuntu) no tiene el
driver ODBC de Microsoft instalado:

```bash
$ python3 -c "import pyodbc; print(pyodbc.drivers())"
[]   # ← msodbcsql18 no instalado
```

**Impacto:**

- `bd_pose_b52`: tests de BD usan mocks (`unittest.mock`).
  0 tests contra la BD real.
- `pendientes_carga.csv`: 420 rechazados sin poder diagnosticar
  con SQL real desde el entorno Linux/CI.
- `estado_proyecto.json` de BD_POSE_B52: `siguiente_accion`
  dice "ejecutar en SERVIDOR" — la instancia YA EXISTE, solo
  falta el driver en Linux.

**Solución — instalar msodbcsql18 en Linux/WSL2:**

```bash
# 1. Clave y repositorio Microsoft
curl -fsSL \
    https://packages.microsoft.com/keys/microsoft.asc \
    | sudo gpg --dearmor \
    -o /usr/share/keyrings/microsoft-prod.gpg

curl https://packages.microsoft.com/config/ubuntu/24.04/prod.list \
    | sudo tee /etc/apt/sources.list.d/mssql-release.list

# 2. Instalar driver ODBC 18 y herramientas
sudo apt-get update
ACCEPT_EULA=Y sudo apt-get install -y msodbcsql18 mssql-tools18
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc

# 3. Verificar
python3 -c "import pyodbc; print(pyodbc.drivers())"
# Esperado: ['ODBC Driver 18 for SQL Server']
```

**Cadena de conexión desde Linux (SQL Auth):**

```python
CONN_STR = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=RICHARD_ASUS\\SQLEXPRESS;"
    "DATABASE=DW_GrupoPOSE_Informes;"
    "UID=<usuario_sql>;"
    "PWD=<contraseña>;"
    "TrustServerCertificate=yes;"
)
```

> **Nota:** Autenticación Windows (Kerberos) desde WSL2 es compleja.
> Crear un login SQL dedicado para el pipeline CI es más robusto.

**Prerequisito en SQLEXPRESS:** verificar que TCP/IP esté
habilitado en SQL Server Configuration Manager y el puerto 1433
esté abierto en el firewall de Windows.

---

### GAP 2 — Scripts Windows sin auditoría (ALTA)

**Inventario actual (4 repos):**

| Repo | .bat | .ps1 | .pq |
|---|---|---|---|
| richard_ia86_dev | 3 | 4 | 143 |
| bd_pose_b52 | 1 | 1 | 0 |
| planif_pose | 2 | 1 | 0 |
| data_analytics | 1 | 1 | 0 |

**Problema:** Ninguno de estos archivos pasa lint en el pipeline.
Un `.bat` roto en HP no lo detecta run_audit.sh.

**Resolución propuesta:**

- **ShellCheck** (disponible en Linux) valida `.bat` parcialmente.
- **PSScriptAnalyzer** requiere PowerShell for Linux (`pwsh`).
- **Mínimo viable:** verificar que los `.bat`/`.ps1` existen,
  son legibles y tienen codificación UTF-8 sin BOM.

---

### GAP 3 — win32com excluido de mypy (MEDIA)

`richard_ia86_dev/Paso2_ActualizarPQ.py` usa `win32com.client`
y está excluido de mypy vía `mypy.ini`.

**Impacto:** Errores de tipo en ese archivo no se detectan.

**Resolución:** Crear stub `win32com/__init__.pyi` mínimo o
reemplazar la dependencia real por `subprocess` + `xlwings`.
Si el script es sólo para HP, moverlo a `projects/windows_only/`
y documentarlo explícitamente como "no auditado en Asus".

---

## 5. Plan de Implementación

### Semana 1 — Integración SQLEXPRESS en Asus

| # | Tarea | Tiempo |
|---|---|---|
| W1-01 | Instalar msodbcsql18 en Linux/WSL2 (driver ODBC) | 30 min |
| W1-02 | Crear login SQL en RICHARD_ASUS\SQLEXPRESS para CI | 15 min |
| W1-03 | Validar conexión desde `bd_pose_b52/config/` | 30 min |
| W1-04 | Reemplazar mocks pyodbc por BD real en tests | 2 h |
| W1-05 | Agregar PASO 7 en run_audit.sh (smoke BD) | 1 h |

**PASO 7 propuesto para run_audit.sh:**

```bash
run_smoke_bd() {
    log_section "PASO 7 — Smoke Test BD Real (Asus)"
    local conn_script
    conn_script="$(
        find "$WORKSPACE_ROOT"/workspaces/bd_pose_b52 \
        -name "00_validar_prerequisitos.py" | head -1
    )"
    if [[ -z "$conn_script" ]]; then
        log_warn "No se encontró script de validación BD"
        return
    fi
    if python3 "$conn_script" &>>"$LOG_FILE"; then
        log_ok "BD accesible — conexión verificada"
    else
        log_fail "BD inaccesible — revisar SQLEXPRESS"
        GLOBAL_STATUS=1
    fi
}
```

---

### Semana 2 — Auditoría Scripts Windows (desde Asus)

| # | Tarea | Tiempo |
|---|---|---|
| W2-01 | Instalar `pwsh` (PowerShell for Linux) en Asus | 30 min |
| W2-02 | Instalar `shellcheck` | 10 min |
| W2-03 | Agregar paso `.ps1` en run_audit.sh (PSScriptAnalyzer) | 1 h |
| W2-04 | Auditar 7 `.ps1` existentes — fix errores | 2 h |
| W2-05 | Documentar exclusión explícita de `.pq` (Power Query) | 30 min |

---

### Semana 3 — Cobertura Total + Dashboard CI

| # | Tarea | Tiempo |
|---|---|---|
| W3-01 | Resolver GAP 3 (win32com / mypy) | 1 h |
| W3-02 | Tests integración BD real (pytest + pyodbc) | 3 h |
| W3-03 | Dashboard HTML del pipeline (reporte por repo) | 2 h |
| W3-04 | Cron nocturno con reporte por email al dev | 1 h |

---

## 6. Criterio de Éxito — Pipeline 6/6

Al finalizar el proyecto, `run_audit.sh` reportará 6/6:

```text
PASO 1: Verificar ramas .............. OK
PASO 2: Clonar repos ................. OK
PASO 3: Hooks pre-commit ............. OK
PASO 4: Dependencias ................. OK
PASO 5: Análisis estático + tests .... OK
PASO 6: Markdown lint ................ OK
PASO 7: Smoke test BD real ........... OK  ← NUEVO
```

Métricas objetivo:

- Tests totales: > 260 (hoy: 231)
- Cobertura BD real: > 0 (hoy: 0)
- Scripts .ps1 con lint: 7/7 (hoy: 0/7)
- win32com en mypy: ✅ (hoy: excluido)

---

## 7. Notas de Transición

- Durante W1, los tests de BD usan mock. No bloquear el pipeline.
- Si SQL Server for Linux no es viable, usar SQLite + esquema
  compatible para CI (mock estructural, no de datos reales).
- Los `.pq` (Power Query) son archivos binarios Excel —
  excluirlos permanentemente del lint estático es correcto.
- HP mantiene su rol de simulador UX. run_audit.sh nunca corre
  en HP, sólo en Asus.
