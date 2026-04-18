# Mapa del Ecosistema — Grupo POSE

**Emisor:** El Ojo de Sauron — Agente Auditor QA
**Creado:** 2026-04-18
**Última actualización:** 2026-04-18
**Propósito:** Lectura obligatoria antes de cualquier jornada de trabajo.
Visión global de los proyectos, su estado actual y sus interdependencias.

> Este documento NO reemplaza los `config/estado_proyecto.json` de cada repo.
> Los complementa con la perspectiva estratégica que solo Sauron necesita.

---

## 1. Arquitectura de Máquinas

```text
┌─────────────────────────────────────┐
│  ASUS — Linux (Ubuntu 24.04)        │
│  Motor CI/CD principal              │
│  run_audit.sh — pipeline QA 6 pasos │
│  Todo el análisis estático + pytest │
└──────────────┬──────────────────────┘
               │ git push/pull (GitHub)
               ▼
         ┌─────────────────────────┐
         │  GitHub (main inmutable) │
         └───────────┬─────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
┌──────────────────┐   ┌──────────────────────────────┐
│ ASUS — Windows   │   │  HP — Windows                │
│ SQL Express local│   │  Simulador usuario final     │
│ SSMS (manual)    │   │  demo_presentacion.bat       │
│ win32com (PQ)    │   │  Dashboard Streamlit (UX)    │
└──────────────────┘   └──────────────────────────────┘
                                   (Sprint 17 reemplaza HP)
                     ▼
        ┌──────────────────────────────┐
        │  Hetzner CX33 — Ubuntu 24.04 │  ← Sprint 17
        │  PostgreSQL 16               │
        │  FastAPI + JWT               │
        │  Next.js / React             │
        │  nginx + Let's Encrypt       │
        │  gestionpose.com.ar          │
        └──────────────────────────────┘
```

**Regla de oro:** Asus Linux audita, valida, carga BD, corre CI/CD.
HP solo valida UX manual. Todo pipeline QA es exclusivo de Asus Linux.

---

## 2. Repositorios del Ecosistema

### 2.1 `richard_ia86_dev` — ETL & Reporting

**Propósito:** Pipeline ETL completo de costos POSE + Dashboard Director Financiero.

**Módulos activos:**

| Sub-pipeline | Fuentes | Staging generado |
|---|---|---|
| DESPACHOS | Excel crudo | `staging_despachos.csv` |
| GG FDL | `MM-YYYY.xlsx` (filtro OBRA) | `staging_fdl.csv` |
| FACTURACION FDL | `MM-YYYY.xlsx` (filtro VENTA*) | `staging_fdl.csv` |
| MENSUALES | `MM-YYYY.xlsx` (tabla/hoja M-yy) | `staging_mensuales.csv` |
| QUINCENAS | `QUINCENAS MM-YYYY.xlsx` | `staging_quincenas.csv` |

**Arquitectura buzón único (implementada 2026-04-18):**

```text
input_raw/ (raíz, sin subcarpetas)
    → clasificador_fuentes.py (maestro_fuentes.xlsx)
    → run_todas_fuentes.py (orquestador)
    → runners individuales
```

**Dashboard:** Streamlit `:8502` — tabs Resumen / Despachos / Pendientes.
Launcher: `lanzar_demo.py` → menú interactivo [1-4] + opción [5] TODAS (pendiente).

**Estado QA:** Sprint 15 activo | 210 tests / 1 skipped | pipeline VERDE
**Pendientes próxima jornada:**

- Tests clasificador + orquestador (**completados 2026-04-18** — 210 total)
- UI Dashboard: formato ARS + fechas `dd/mm/yyyy`
- (Asus) Mover xlsx de subcarpetas a `input_raw/` raíz
- `lanzar_demo.py`: opción [5] TODAS LAS FUENTES

---

### 2.2 `bd_pose_b52` — Data Warehouse SQL Server → PostgreSQL

**Propósito:** DW del Grupo POSE. Almacena costos, comprobantes,
catálogos, dimensiones y datos históricos desde 2019.

**BD actual:** `DW_GrupoPOSE_B52` en `DEV-DIRECTORIO\SQLEXPRESS` (Asus Windows)

**Fases de implementación:**

| Fase | Estado | Descripción |
|---|---|---|
| FASE 0 — Prerrequisitos | ✅ Completa | Python, sqlcmd, instancia SQL OK |
| FASE 1 — Estructura | ✅ En validación | 5 esquemas, 18 tablas, índices, semilla |
| FASE 2 — Catálogos | ⏳ Pendiente (SERVIDOR) | Gerencias, obras, proveedores, fuentes |
| FASE 3 — Histórico | ⏳ Pendiente (SERVIDOR) | Costos/comprobantes 2019-2024 |
| FASE 4 — BD producción | ⏳ Pendiente | Carga continua + incrementales |

**Migración activa (Sprint 17):** Rama `feature/postgresql-migration` —
PR #7 WIP. Migración de SQL Server Express → PostgreSQL 16 (Hetzner).

**Estado QA:** 7 tests | pipeline VERDE
**Pendiente estratégico:** Resolver PR #7 — decisión de merge cuando
Hetzner CX33 esté disponible.

---

### 2.3 `planif_pose` — ETL Planillas de Costos

**Propósito:** Normalización automática de planillas Excel de costos POSE.
Transforma archivos crudos → staging validado → carga incremental en BD.

**Stack técnico:** `reader.py` → `transformer.py` → `writer.py` →
`ExcelWriter` + `schema_contract.py` + política de duplicados.

**Capacidades clave:**
- Schema Contract: valida columnas canónicas antes de escritura
- Detección duplicados: modo `strict` y `soft`
- Diferencia `importe_sin_dato` vs `importe_costo_cero`
- BD actualizada: 455.675 filas al día con 2026-03
- Soporte formatos 2023 / 2025 / 2026 (distintos headers por año)

**Estado QA:** Sprint 14-sync | 47 tests | pipeline VERDE | sin deuda activa

---

### 2.4 `gestion_comp` — Gestión de Compensaciones

**Propósito:** Automatización de descarga, procesamiento y generación
de informes de compensaciones POSE usando Playwright + pandas + xlsxwriter.

**Estado QA:** 36 tests | pipeline VERDE | onboarding completado 2026-04-16
**Pendientes:**
- `vpn_check.py` (FortiClient): solo verificable en Asus Windows con VPN activa
- Prueba end-to-end flujo completo con VPN activa

---

### 2.5 `data_analytics` — Workspace de Análisis de Datos

**Propósito:** Repositorio de aprendizaje del curso de análisis de datos
(TP1 → TP4). Funciones estadísticas, herramientas de análisis, notebooks.

**Módulos:** `Herramientas/mis_funciones.py` —
media, mediana, varianza, desviación estándar, limpieza nulos,
frecuencias, normalización, aplanar listas.

**Estado QA:** Sprint 13 | 46 tests | pipeline VERDE | sin deuda activa
**Próxima acción:** Avanzar TP3/TP4 del curso (sin dependencias del ecosistema).

---

### 2.6 `auditoria_ecosauron` — El Ojo de Sauron

**Propósito:** Motor CI/CD y auditoría del ecosistema. No desarrolla
aplicaciones — controla la calidad estricta de todos los repos hermanos.

**Pipeline `run_audit.sh`:**
1. PASO 0 — Verificar ramas (gobierno)
2. PASO 1 — Clonar/actualizar repos
3. PASO 2 — Configurar pre-commit hooks
4. PASO 3 — Validar dependencias pip
5. PASO 4 — black + flake8 + mypy
6. PASO 5 — pytest (por repo)
7. PASO 6 — pymarkdown (docs) — WARN-only

**Estado:** Pipeline 6/6 APROBADO (última ejecución 2026-04-16)
**Tests totales en el ecosistema:** 210 + 47 + 7 + 36 + 46 = **346 tests**

---

## 3. Dependencias entre Repos

```text
planif_pose ──────────────────────────────────────────────────────┐
  Lee Excel crudos costos → genera staging → carga BD             │
                                                                   ▼
richard_ia86_dev ─────────────────────────────────────────────── bd_pose_b52
  Lee Excel FDL/MENSUALES/QUINCENAS/DESPACHOS → staging → carga  (DW_GrupoPOSE_B52)
  Dashboard Streamlit lee desde staging CSV (no BD directa)       ▲
                                                                   │
gestion_comp ─────────────────────────────────────────────────────┘
  Descarga compensaciones → eventual carga BD (fase futura)

data_analytics ── autónomo (curso — sin dependencias de BD ni de otros repos)

auditoria_ecosauron ── audita los 5 repos anteriores (no tiene dependencias de negocio)
```

---

## 4. Arquitectura Objetivo — Sprint 17

> Estado: PLANIFICADO. Bloqueado por: activación cuenta Hetzner CX33.

**Cambio central:** reemplazar la dupla
`SQL Server Express (Windows) + Streamlit (local)`
por un stack web profesional accesible por internet.

```text
ETL Python          PostgreSQL 16      FastAPI + JWT
(sin cambios)   →   (Hetzner CX33)  →  (nuevo)
                                            ↓
                                      Next.js / React
                                      nginx + Let's Encrypt
                                      Cloudflare DNS
                                      https://gestionpose.com.ar
```

**Impacto por repo:**

| Repo | Cambio requerido |
|---|---|
| `bd_pose_b52` | Migración SQL Server → PostgreSQL 16 (PR #7 activo) |
| `richard_ia86_dev` | Cambiar conexión BD: pyodbc MSSQL → psycopg2 PostgreSQL |
| `planif_pose` | Cambiar conexión BD idem |
| `gestion_comp` | Sin impacto inmediato (carga local) |
| `data_analytics` | Sin impacto (autónomo) |

**Decisiones cerradas:**

| Componente | Decisión |
|---|---|
| BD | PostgreSQL 16 en Linux |
| Auth | FastAPI + JWT (python-jose) |
| VPN admin | WireGuard nativo (kernel Linux) |
| Dominio | `gestionpose.com.ar` (NIC Argentina) |
| DNS | Cloudflare Free — Full strict + proxy |
| SSL | Let's Encrypt + certbot |
| Servidor | Hetzner CX33 — €6.99/mes (cuenta creada, verificando) |
| OS servidor | Ubuntu 24.04 LTS |
| Frontend | Next.js + TypeScript |
| SSH | Ed25519 (`Richard.r.ia86@gmail.com`) |

---

## 5. Procedimiento de Actualización

Este documento tiene valor estratégico solo si se mantiene al día.
Las siguientes reglas son **obligatorias**.

### 5.1 Quién actualiza

| Actor | Puede actualizar | No puede |
|---|---|---|
| **Sauron (QA)** | §2 (estado QA, tests, pipeline), §3, §4 | §5 (este procedimiento) |
| **Dev (Richard)** | §2 (pendientes negocio, módulos), §4 (decisiones nuevas) | Campos de estado QA |

### 5.2 Cuándo actualizar — Triggers obligatorios

| Trigger | Secciones afectadas | Quién |
|---|---|---|
| Cierre de sprint en cualquier repo | §2.x del repo afectado — estado, tests, pendientes | Sauron |
| Nueva decisión arquitectónica Sprint 17 | §4 — tabla de decisiones | Dev |
| Nuevo repo incorporado al ecosistema | §2 (nueva sección), §3 (dependencias), §6 (tabla resumen) | Sauron |
| Cambio de máquina / entorno | §1 (arquitectura de máquinas) | Dev + Sauron |
| Hetzner CX33 activo | §1 (mapa máquinas), §4 (estado → EN CURSO) | Dev + Sauron |
| Merge PR #7 (PostgreSQL) | §2.2 (bd_pose_b52 nueva BD), §4 (impacto repos) | Sauron |

### 5.3 Cómo actualizar — Pasos

1. **Leer** `config/estado_proyecto.json` del repo afectado
   (secciones `jornada.fin` y `desarrollo_local`).
2. **Editar** solo las secciones que corresponden al trigger.
3. **Actualizar** el campo `Última actualización` del encabezado.
4. **Verificar** que el campo `Tests totales` en §2.6 sea la suma
   real de los 5 repos (sin contar Sauron).
5. **Commitear** con:

   ```bash
   git commit -m "docs(mapa): actualizar estado <repo> — YYYY-MM-DD"
   ```

### 5.4 Qué NO se actualiza aquí

- Detalles técnicos de scripts o módulos individuales
  → esos van en el `backlog.md` o `estado_proyecto.json` del repo.
- Historial de sprints pasados
  → eso va en las actas `docs/actas/ACTA-*.md`.
- Errores de pipeline o hallazgos de QA
  → esos van en `docs/bitacora_trazabilidad.md`.

### 5.5 Señal de documento desactualizado

Si al inicio de una jornada se detecta alguna de estas condiciones,
actualizar **antes** de cualquier otra tarea:

- La fecha de `Última actualización` tiene más de 7 días.
- Un repo muestra estado ROJO o AMARILLO y §2 no lo refleja.
- Hay un PR mergeado en GitHub que §4 todavía marca como pendiente.

---

## 6. Resumen de Estado — Vista Rápida

| Repo | Tests | Pipeline | Sprint activo | Próxima acción |
|---|---|---|---|---|
| `richard_ia86_dev` | 210 / 1 skip | VERDE | Sprint 15 | UI formato ARS + buzón único Asus |
| `bd_pose_b52` | 7 | VERDE | Sprint 17 (WIP) | PR #7 merge cuando Hetzner activo |
| `planif_pose` | 47 | VERDE | Sin deuda | Sin deuda activa |
| `gestion_comp` | 36 | VERDE | — | vpn_check end-to-end (requiere VPN) |
| `data_analytics` | 46 | VERDE | Sprint 13 | Avanzar TP3/TP4 del curso |
| **Total ecosistema** | **346** | **VERDE** | — | — |
