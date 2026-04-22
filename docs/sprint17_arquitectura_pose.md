# Sprint 17 — Nueva Arquitectura POSE

> **Estado:** ACTIVO — servidor Hetzner CX33 operativo
> **Fecha de planificación:** 2026-04-13
> **Fecha de inicio formal:** 2026-04-20
> **Punto de partida confirmado:** 2026-04-22

---

## 1. Por qué se hace este cambio

El sistema actual (Streamlit local + `.bat` + Power Query) tiene
5 problemas confirmados:

| Problema | Impacto |
|----------|---------|
| Requiere Python/venv instalado en cada máquina | Solo funciona en máquinas configuradas |
| Director ejecuta un `.bat` para verlo | No es autónomo ni profesional |
| Solo accesible en localhost | Sin acceso remoto |
| Diseño no corporativo | Imagen ante la dirección |
| No se puede compartir como link | Sin distribución |

**Audiencia objetivo:** Director Financiero + equipo directivo
(3–5 personas) + acceso remoto vía browser.

---

## 2. Arquitectura nueva — decisiones cerradas

### Stack completo

```text
Fuentes Excel (crudos)
      │
      ▼
ETL Python (richard_ia86_dev)   ← reemplaza planif_pose .pq + .bat
      │
      ▼
PostgreSQL 16 (Hetzner CX33)    ← reemplaza SQL Express (Asus Windows)
      │
      ▼
FastAPI + JWT                   ← nuevo
      │
      ▼
Next.js / React                 ← nuevo
      │
nginx + Let's Encrypt SSL
      │
Cloudflare DNS (proxy)
      │
https://gestionpose.com.ar
```

### Acceso administrador

```text
iMac / Asus  →  WireGuard VPN  →  Puerto 22/5432 Hetzner
```

### Tabla de decisiones

| Componente | Decisión | Estado |
|------------|----------|--------|
| Base de datos | PostgreSQL 16 en Linux | ✅ Cerrado |
| Auth API | JWT propio — FastAPI + python-jose | ✅ Cerrado |
| VPN | WireGuard nativo (kernel Linux) | ✅ Cerrado |
| Dominio | `gestionpose.com.ar` — NIC Argentina | ✅ Registrado |
| DNS | Cloudflare Free — Full strict + proxy | ✅ NS delegados |
| SSL | Let's Encrypt + certbot | ✅ Cerrado |
| Servidor | Hetzner CX33 — €6.99/mes | ✅ Activo |
| OS servidor | Ubuntu 24.04 LTS | ✅ Cerrado |
| Frontend | Next.js + TypeScript | ✅ Cerrado |
| API | FastAPI + uvicorn | ✅ Cerrado |
| SSH Key | Ed25519 (`Richard.r.ia86@gmail.com`) | ✅ Generada |
| Power BI Pro | Licencia $10 USD/usuario/mes | ⏳ Post Sprint 17 |

---

## 3. Specs del servidor (Hetzner CX33)

| Recurso | Valor |
|---------|-------|
| vCPU | 4 (Intel®/AMD) |
| RAM | 8 GB |
| Disco | 80 GB SSD |
| Red | 20 TB/mes |
| Costo | €6.99/mes |
| OS | Ubuntu 24.04 LTS |

**¿Por qué CX33 y no CX23 (4 GB)?**
Con 8 GB el motor usa ~2 GB para `shared_buffers` + FastAPI + nginx + OS,
dejando margen real de crecimiento.

---

## 4. Seguridad — reglas de firewall

```text
Puerto 443   TCP  → internet (nginx → Next.js + FastAPI)
Puerto 51820 UDP  → internet (WireGuard handshake)
Puerto 22    TCP  → SOLO desde peers VPN
Puerto 5432  TCP  → SOLO desde peers VPN
Todo lo demás     → DROP
```

Cloudflare con proxy activo ("nube naranja") oculta la IP real del servidor.

**Regla de oro:** PostgreSQL nunca expuesto a internet. Solo accesible
por VPN.

---

## 5. Cloudflare — configuración SSL

```text
Browser  →  Cloudflare (cert propio)  →  nginx (cert Let's Encrypt)
```

Modo: **Full (strict)** — dos capas de encriptación.
Resultado: candado verde en browser, IP del servidor oculta,
protección DDoS incluida.

---

## 6. Inventario de máquinas

| ID | Máquina | OS | Rol |
|----|---------|-----|-----|
| M1 | iMac | Linux | Dev principal — El Ojo de Sauron (CI/CD) |
| M2 | Asus | Linux (Ubuntu/WSL2) | Todos los repos + SQL Express local + VPN peer |
| M3 | HP | Windows | Pruebas manuales — solo .bat + dashboard |
| S1 | Hetzner CX33 | Ubuntu 24.04 LTS | Producción — PostgreSQL, FastAPI, nginx |

**Regla:** El pipeline QA (`run_audit.sh`) corre exclusivamente en M1/M2.
HP (M3) solo valida UX manual.

---

## 7. Bases de datos — contexto y estrategia de migración

### Estado actual

| BD | Servidor | Tipo | Estado |
|----|----------|------|--------|
| `BD_POSE_A2` | Servidor empresa | No incremental | ✅ Activa — reportes área financiera |
| `DW_GrupoPOSE_B52` | Asus Windows (`RICHARD_ASUS\SQLEXPRESS`) | Incremental | ✅ En desarrollo |

### Destino Sprint 17

Ambas BDs migran a **PostgreSQL 16 en Hetzner CX33**.

### Estrategia — "la palanca"

```text
FASE PARALELA (durante Sprint 17):
  BD_POSE_A2 (empresa)     →  activa, reportes financieros siguen
  DW_GrupoPOSE_B52 (Asus)  →  activa, ETL Python sigue cargando
  PostgreSQL Hetzner        →  se construye y valida en paralelo

FLIP (cuando PostgreSQL esté validado):
  ETL Python apunta a PostgreSQL  ←  una línea de config
  FastAPI lee desde PostgreSQL    ←  operativo
  BD_POSE_A2 queda como respaldo  ←  NO se da de baja inmediatamente
  SQL Express queda como respaldo ←  idem

POST-SPRINT 17 (cuando haya confianza):
  BD_POSE_A2  →  archivada (read-only)
  SQL Express →  dado de baja
```

**Criterio de flip:** ETL Python carga correctamente en PostgreSQL y
el dashboard muestra datos consistentes con los reportes de A2.

---

## 8. ETL Python — reemplazo del pipeline .pq

El ETL Python (`richard_ia86_dev/projects/report_direccion`) está
reemplazando activamente el pipeline anterior:

| Pipeline | Tecnología | Estado |
|----------|-----------|--------|
| **Anterior** | `planif_pose`: `.pq` (Power Query) + `menu_ejecucion.bat` | En uso |
| **Nuevo** | `richard_ia86_dev`: Python puro (`clasificador_fuentes.py` + runners) | En construcción |

Cuando el nuevo pipeline esté validado y cargando en PostgreSQL,
el `.bat` / Power Query queda obsoleto.

**Fuentes cubiertas por el nuevo ETL:**

| Fuente | Runner | Staging |
|--------|--------|---------|
| DESPACHOS | `run_despachos.py` | `staging_despachos.csv` |
| GG FDL | `run_fdl.py` | `staging_fdl.csv` |
| FACTURACION FDL | `run_fdl.py` | `staging_fdl.csv` |
| MENSUALES | `run_mensuales.py` | `staging_mensuales.csv` |
| QUINCENAS | `run_quincenas.py` | `staging_quincenas.csv` |

Arquitectura buzón único: `input_raw/` → `clasificador_fuentes.py`
→ `run_todas_fuentes.py` → runners individuales.

---

## 9. Repos nuevos a crear

| Repo | Nombre GitHub | Tecnología | Workspace |
|------|--------------|------------|-----------|
| API | `Richard-IA86/Pose_API` | Python — FastAPI | EcoSauron PASO 8 |
| Frontend | `Richard-IA86/Pose_Frontend` | TypeScript — Next.js | EcoSauron PASO 7 |

---

## 10. QA — integración en EcoSauron

El pipeline `run_audit.sh` incorpora dos pasos nuevos:

| Paso nuevo | Herramienta | Equivalente Python |
|------------|-------------|-------------------|
| PASO 7 — Frontend | `prettier`, `eslint`, `tsc --noEmit`, `jest --ci` | black, flake8, mypy, pytest |
| PASO 8 — API | Mismas herramientas Python que hoy | Sin cambios |

Un solo `bash scripts/run_audit.sh` audita Python + TypeScript + React.

---

## 11. Secuencia de ejecución Sprint 17

### BLOQUE A — Infraestructura base (parcialmente completado)

```text
T1.  [✅] Registrar dominio gestionpose.com.ar en NIC Argentina
T2.  [✅] Contratar Hetzner CX33 (Ubuntu 24.04) — ACTIVO
T3.  [✅] Crear cuenta Cloudflare + delegar NS de NIC AR
T4.  Configurar firewall ufw en servidor (reglas sección 4)
T5.  Instalar WireGuard en servidor + agregar peer M1 (iMac) y M2 (Asus)
T6.  Instalar nginx + certbot + certificado Let's Encrypt
T7.  Instalar PostgreSQL 16 en servidor
```

### BLOQUE B — Migración de datos

```text
T8a. Migrar BD_POSE_A2 → PostgreSQL 16 (volcado + restore)
T8b. Migrar DW_GrupoPOSE_B52 → PostgreSQL 16
     └── Usar scripts SQL del PR #7 (bd_pose_b52/feature/postgresql-migration)
T9.  Verificar ETL Python conecta a PostgreSQL vía psycopg2 (por VPN)
     └── Prueba de carga batch con datos reales
     └── Comparar resultados con BD_POSE_A2 — deben coincidir
```

### BLOQUE C — API

```text
T10. Crear repo Pose_API — FastAPI + uvicorn + estructura base
     └── main.py, routers/, schemas/, tests/ — scaffold inicial
T11. Endpoints mock: /api/v1/costos /api/v1/despachos /api/v1/mensuales
T12. Implementar JWT: /auth/login, token, rutas protegidas
T13. Conectar FastAPI a PostgreSQL 16 vía psycopg2 + queries reales
T14. Configurar nginx proxy_pass a FastAPI :8000
T15. Desplegar Pose_API como contenedor Docker en Hetzner
     └── Gemini define Dockerfile + docker-compose.yml + imagen en registry
     └── PostgreSQL corre directo en host (sin contenedor — datos fuera de Docker)
T16. Agregar Pose_API al pipeline EcoSauron (PASO 8)
```

### BLOQUE D — Frontend

```text
T17. Crear repo Pose_Frontend — Next.js + TypeScript
     └── npx create-next-app --typescript
     └── Estructura: components/, pages/, lib/api.ts
T18. Componentes con Copilot: Sidebar, BarChart, LineChart, DataTable
T19. Páginas: /dashboard (costos), /despachos, /mensuales
T20. Conectar fetch a FastAPI con JWT en headers
T21. Build: next build + nginx serve estático
T22. Desplegar en Hetzner + verificar SSL + Cloudflare proxy
```

### BLOQUE E — QA, palanca y cierre

```text
T23. Tests Jest + React Testing Library (componentes críticos)
T24. Playwright E2E: login → ver dashboard → filtrar período
T25. Agregar Pose_Frontend al pipeline EcoSauron (PASO 7)
T26. FLIP: ETL Python apunta a PostgreSQL Hetzner (cambio de config)
     └── Validar datos coinciden con BD_POSE_A2
     └── BD_POSE_A2 y SQL Express quedan como respaldo (read-only)
T27. Procesar crudos acumulados en input_raw/ con ETL (batch)
T28. Acta de cierre Sprint 17
T29. Actualizar mapa_ecosistema.md + docs arquitectura final
T30. Automatización de maestros lookups
```

---

## 12. Gemini — Agente DevOps

> **Origen:** Propuesta `Propuesta_Ecosistema_Ojo_Sauron.md`
> — aprobada 2026-04-20

### División de responsabilidades

| Agente | Rol | Foco |
|--------|-----|------|
| **GitHub Copilot** | Auditor + Escritor | Código, QA, tests, PR reviews |
| **Gemini Advanced** | DevOps | Infraestructura Hetzner, Docker, GitHub Actions |

### Bridge de despliegue — gate humano obligatorio

```text
Copilot sugiere cambio
        │
        ▼
   PR en GitHub  ◄── GATE: merge manual por el dev
        │
        ▼
  GitHub Actions  (disparado por merge a main)
        │
        ├── Paso 1: run_audit.sh (QA: black/flake8/mypy/pytest)
        ├── Paso 2: docker build + push a registry
        └── Paso 3: SSH al CX33 → docker pull + restart
              ▲
        Gemini define y mantiene este workflow
```

> **Regla de oro:** Ningún deploy automático sin merge humano previo.
> Copilot no pushea a producción. Gemini no toca el código.

### Gestión de secretos

| Secreto | Dónde vive | Cómo se usa |
|---------|------------|-------------|
| `DB_PASSWORD` | GitHub Secrets | Inyectado en GitHub Actions |
| `JWT_SECRET_KEY` | GitHub Secrets | Idem |
| `HETZNER_SSH_PRIVATE_KEY` | GitHub Secrets | SSH deploy step |
| WireGuard peer keys | `/etc/wireguard/` en S1 | Solo en servidor |

---

## 13. Commits de rollback — CONSERVAR

Si algo sale mal, estos son los puntos de retorno seguros:

| Repositorio | Hash | Descripción |
|-------------|------|-------------|
| `auditoria_ecosauron` | `52a17e4` | docs(qa): inicio jornada 2026-04-13 |
| `richard_ia86_dev` | `9872c76` | ci: workflow\_dispatch manual |
| `bd_pose_b52` | `4fd5a54` | fix(qa): pyproject.toml + black fmt |
| `planif_pose` | `b0254cb` | ci: workflow\_dispatch manual |
| `data_analytics` | `14c7999` | ci: workflow\_dispatch manual |

Comando: `git reset --hard <hash>`

**Los datos en PostgreSQL son independientes del código.
No se tocan en ningún caso de rollback.**

---

## 14. Contexto del sistema al inicio del sprint

| Ítem | Valor |
|------|-------|
| ETL activo | `richard_ia86_dev/projects/report_direccion/` |
| Fuentes cubiertas | DESPACHOS / MENSUALES / GG FDL / FAC FDL / QUINCENAS |
| BD actual (empresa) | `BD_POSE_A2` — servidor empresa — activa |
| BD actual (dev) | `DW_GrupoPOSE_B52` — SQL Express Asus — activa |
| BD destino | PostgreSQL 16 — Hetzner CX33 |
| Tests ecosistema | ~346 passed / 1 skipped |
| QA pipeline | EcoSauron `run_audit.sh` — 6/6 APROBADO |
| Último commit orquestador | `52a17e4` |
| Repos nuevos a crear | `Pose_API`, `Pose_Frontend` |
| ETL pipeline a reemplazar | `planif_pose/scripts/menu_ejecucion.bat` (.pq) |
