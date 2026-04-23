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
\\10.2.1.62\costos y compensaciones\    ← equipo RD (5 personas Windows)
\\10.2.1.62\Construyo Al Costo\...      ← idem
ProntoNet (web)                          ← cron nocturno (gestion_comp)
      │
      │  VPN empresa (Asus Windows)
      ▼
ETL Python — Asus Windows               ← Python Windows, UNC directo
(richard_ia86_dev — disparo manual, hasta 4×/día)
      │  pg_dump snapshot antes de cada carga
      │  WireGuard VPN (Asus → Hetzner :5432)
      ▼
PostgreSQL 16 (Hetzner CX33 — host)    ← reemplaza SQL Express
      │  tabla etl_log (timestamp, usuario, resultado)
      ▼
FastAPI + JWT (Docker)                  ← nuevo
      │
nginx + Let's Encrypt + Cloudflare proxy
      │
https://gestionpose.com.ar
      │
      ├── Director Financiero  → /dashboard  (todos los datos)
      │                          indicador "Datos al DD/MM/AAAA HH:MM"
      └── Gerentes de obra     → /gerencia/{slug} (filtrado por obra)
                                  [⬇ Descargar Informe .xlsx]
                                  [⬇ Descargar Datos crudos .xlsx]
```

### Acceso administrador / ETL

```text
iMac (Linux)      →  WireGuard VPN  →  Puerto 22 Hetzner  (admin SSH)
Asus (Windows)    →  WireGuard VPN  →  Puerto 5432 Hetzner (ETL psycopg2)
GitHub Actions    →  SSH directo IPs GitHub  →  Puerto 22  (CI/CD deploy)
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
| Docker deploy | FastAPI corre en Docker desde el arranque | ✅ Cerrado (2026-04-23) |
| Container Registry | ghcr.io — `GITHUB_TOKEN`, sin rate limiting | ✅ Cerrado (2026-04-23) |
| SSH deploy Actions | Directo + allowlist IPs GitHub + WireGuard admin | ✅ Cerrado (2026-04-23) |
| ETL ejecución | Python Windows — Asus (UNC directo `\\10.2.1.62`) | ✅ Cerrado (2026-04-23) |
| Dashboard tiempo real | Datos frescos por query, sin cron web | ✅ Cerrado (2026-04-23) |
| Indicador carga | "Datos al DD/MM/AAAA HH:MM" — timestamp última ETL | ✅ Cerrado (2026-04-23) |
| Reportes descargables | Excel formateado + datos crudos (xlsxwriter) | ✅ Cerrado (2026-04-23) |
| Backup ETL | 5 snapshots pg_dump + rsync disco externo cron 02:00 | ✅ Cerrado (2026-04-23) |
| Rollback | pg_restore automático si ETL falla a mitad de carga | ✅ Cerrado (2026-04-23) |
| Roles | director_financiero / gerente_obra / admin_rd | ✅ Cerrado (2026-04-23) |
| Alta usuarios | Script sync desde maestro Obras_Gerencias (admin_rd) | ✅ Cerrado (2026-04-23) |
| Loockups → BD | 5 hojas migran a catalogos.*; 2 catálogos editables quedan Excel | ✅ Cerrado (2026-04-23) |
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
Puerto 22    TCP  → rangos IP GitHub Actions  (deploy automático CI/CD)
Puerto 22    TCP  → peers WireGuard           (acceso admin)
Puerto 22    TCP  → todo lo demás             DROP
Puerto 5432  TCP  → SOLO peers WireGuard
Todo lo demás     → DROP
```

Cloudflare con proxy activo ("nube naranja") oculta la IP real del servidor.

**IPs de GitHub Actions:** GitHub las publica en `https://api.github.com/meta`
(campo `actions`). El workflow de Gemini incorpora la Action oficial que
actualiza estas reglas automáticamente cuando GitHub cambia sus rangos.

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
| M1 | iMac | **Linux nativo** | El Ojo de Sauron — QA, CI/CD, `run_audit.sh` |
| M2 | Asus | **Windows + WSL2** | Dev + ETL (Python Windows) + acceso `\\10.2.1.62` + VPN peer Hetzner |
| RD×5 | Equipo RD | Windows | Producen los Excel fuente en `\\10.2.1.62` — sin acceso web directo |
| S1 | Hetzner CX33 | Ubuntu 24.04 LTS | Producción — PostgreSQL, FastAPI, nginx |
| ~~M3~~ | ~~HP~~ | ~~Windows~~ | ~~Dado de baja 2026-04-13~~ |

**Reglas de ejecución:**

- Pipeline QA (`run_audit.sh`) corre exclusivamente en M1 (iMac Linux).
- ETL Python corre en M2 Asus **Windows** — acceso nativo a `\\10.2.1.62`.
- WSL2 del Asus: desarrollo y tests locales únicamente, NO ejecuta el ETL.
- HP dado de baja — sin rol activo en el ecosistema.

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

**Nota de ejecución — Vía B (Python Windows):**
El ETL corre en Asus Windows con VPN empresa activa.
Accede a `\\10.2.1.62` vía UNC nativo (sin WSL2, sin montaje /mnt/).
Disparo manual por admin_rd (hasta 4×/día). ProntoNet: cron nocturno.

---

## 8b. Flujo completo de datos

### Ingesta (ETL manual — disparado por admin_rd)

```text
\\10.2.1.62\costos y compensaciones\  ← equipo RD mantiene estos Excel
\\10.2.1.62\Construyo Al Costo\...    ← idem
ProntoNet (web)                        ← gestion_comp descarga vía scraper
      │
      │  UNC directo (Asus Windows, VPN empresa activa)
      ▼
ETL Python — Asus Windows
  1. Verificar \\10.2.1.62 accesible
  2. pg_dump → /backups/snapshots/snapshot_YYYYMMDD_HHMM.dump
  3. Clasificar + transformar fuentes (clasificador_fuentes.py)
  4. INSERT / UPSERT en PostgreSQL (por VPN WireGuard)
  5a. OK   → UPDATE etl_log: éxito + timestamp
  5b. FAIL → pg_restore automático + etl_log: fallo + rollback
```

### Consulta (tiempo real — usuarios web)

```text
Browser  →  https://gestionpose.com.ar
      ▼
Cloudflare → nginx → FastAPI (Docker)
  │  valida JWT
  │  filtra por rol:
  │    director_financiero → todas las obras/gerencias
  │    gerente_obra        → solo obras_habilitadas[]
  │    admin_rd            → todo + disparar ETL + ver logs
      ▼
PostgreSQL 16
      ▼
JSON → Next.js renderiza dashboard
  │  Indicador: "Datos al 23/04/2026 14:32"
  └── Botones de descarga por gerencia:
        [⬇ Informe .xlsx formateado]  [⬇ Datos crudos .xlsx]
```

---

## 8c. Loockups.xlsx — clasificación de hojas

El archivo `Loockups.xlsx` es la fuente de configuración central del ETL.
Sus hojas se dividen en dos categorías según su naturaleza:

### Tablas de BD — migran a PostgreSQL

Datos estables o históricos que el ETL solo lee. Se cargan una vez
desde el Excel y luego se mantienen en la BD:

| Hoja | Uso en ETL | Tabla destino |
|------|-----------|---------------|
| `Obras_Gerencias` | Mapeo obra → gerencia + alta de usuarios | `catalogos.obras_gerencias` |
| `TipoCambio` | Conversión moneda histórica | `catalogos.tipo_cambio` |
| `GerenciEquivalente` | Nombres equivalentes entre sistemas | `catalogos.gerencia_equiv` |
| `Equivalencias_DescObras` | Normalización nombres de obras | `catalogos.equiv_desc_obras` |
| `GG_FDL_CentroCosto` | Mapeo centro de costo → obra | `catalogos.gg_fdl_cc` |

### Catálogos editables — quedan en Excel (o panel admin futuro)

Parámetros de comportamiento que el equipo RD actualiza según
necesidades operativas del ETL:

| Hoja | Uso | Quién edita |
|------|-----|-------------|
| `Excepciones_Gerencia` | Casos especiales de asignación gerencia | Equipo RD |
| `Config_Fuentes` | Activa/desactiva fuentes del ETL (ACTIVO=SI/NO) | Admin RD |

> **Nota:** cuando el panel admin web esté disponible (post Sprint 17),
> los catálogos editables migran a tablas con UI de edición.
> El Excel queda como respaldo de importación.

---

## 8d. Roles y modelo de acceso

### Roles definidos

| Rol | Acceso | Quién |
|-----|--------|-------|
| `director_financiero` | Dashboard completo — todas las obras/gerencias | Director Financiero |
| `gerente_obra` | Solo obras en `obras_habilitadas[]` | Gerentes de obra |
| `admin_rd` | Dashboard completo + disparar ETL + ver logs | Equipo RD |

### Alta de usuarios — flujo desde Obras_Gerencias

```text
Maestro Obras_Gerencias (Loockups.xlsx → catalogos.obras_gerencias)
      │  gerencias únicas detectadas automáticamente
      ▼
Script: sync_usuarios_gerentes.py  (admin_rd lo ejecuta manualmente)
      │  INSERT INTO usuarios (username, rol, obras_habilitadas)
      │  ON CONFLICT DO UPDATE (idempotente — re-ejecutable)
      ▼
PostgreSQL tabla: usuarios
```

No hay autoregistro. Control total del acceso desde el maestro.

### Sesión web

```text
1. POST /api/v1/auth/login → FastAPI emite JWT (httpOnly cookie)
2. Cada request: Authorization: Bearer <token>
3. FastAPI valida rol → filtra datos por obras_habilitadas[]
4. Next.js renderiza según rol:
     director → ve todo
     gerente  → ve solo su filtro + botones descarga
     admin_rd → ve todo + panel ETL (disparar, ver logs)
```

---

## 8e. Backup policy

### Snapshot pre-carga (automático en cada ETL run)

```text
Antes de cada INSERT al ETL:
  pg_dump -Fc → /backups/snapshots/snapshot_YYYYMMDD_HHMM.dump
  Retener: últimos 5 snapshots (rotación automática)

Si carga OK:   etl_log "éxito", snapshot anterior rotado
Si carga FAIL: pg_restore automático del snapshot previo
               etl_log "fallo + rollback" + notificación admin_rd
```

### Backup diario — disco externo (cron 02:00)

```text
Cron en Asus Windows (Task Scheduler 02:00):
  1. WireGuard conectar (si no está activo)
  2. pg_dump -Fc Hetzner → backup_YYYYMMDD.dump.gz
  3. rsync → /media/disco_externo/pose_backups/
  4. Retener: últimos 30 días en disco externo
  5. WireGuard desconectar
```

### Matriz de riesgos cubiertos

| Riesgo | Cobertura |
|--------|-----------|
| ETL falla a mitad de carga | Rollback automático al snapshot previo |
| Director necesita datos de antes del fallo | Snapshot disponible inmediatamente |
| Falla catastrófica Hetzner | Disco externo (último backup diario, máx 24h) |
| Error en migración de datos | Snapshot pre-sprint17 conservado sin rotación |

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
T4.  [✅] Configurar firewall ufw en servidor (reglas sección 4)
T5.  Instalar WireGuard en servidor + agregar peer M1 (iMac) y M2 (Asus)
T6.  Instalar nginx + certbot + certificado Let's Encrypt
T7.  Instalar PostgreSQL 16 en servidor
T7b. Instalar Docker en servidor (prerequisito para T15)
```

### BLOQUE B — Migración de datos

```text
T8a. Snapshot inicial antes de la migración
     └── pg_dump → /backups/snapshots/snapshot_pre_sprint17.dump (sin rotación)
T8b. Migrar BD_POSE_A2 → PostgreSQL 16 (volcado + restore)
T8c. Migrar DW_GrupoPOSE_B52 → PostgreSQL 16
     └── Usar scripts SQL del PR #7 (bd_pose_b52/feature/postgresql-migration)
T9.  Verificar ETL Python Windows conecta a PostgreSQL vía psycopg2
     └── WireGuard activo + psycopg2 desde Asus Windows
     └── Prueba de carga batch con datos reales desde \\10.2.1.62
     └── Comparar resultados con BD_POSE_A2 — deben coincidir
T9b. Sincronizar usuarios gerentes desde maestro Obras_Gerencias
     └── sync_usuarios_gerentes.py lee catalogos.obras_gerencias
     └── INSERT INTO usuarios ON CONFLICT DO UPDATE (idempotente)
```

### BLOQUE C — API

```text
T10. Crear repo Pose_API — FastAPI + uvicorn + estructura base
     └── main.py, routers/, schemas/, tests/ — scaffold inicial
T11. Endpoints mock + reportes descargables
     ├── GET /api/v1/costos?obra={id}              → datos director
     ├── GET /api/v1/despachos?obra={id}           → datos director
     ├── GET /api/v1/mensuales?obra={id}           → datos director
     ├── GET /api/v1/etl/ultimo_update             → timestamp última carga
     ├── POST /api/v1/etl/ejecutar                 → solo rol admin_rd
     ├── GET /api/v1/reportes/{gerencia}/informe   → Excel formateado (xlsxwriter)
     └── GET /api/v1/reportes/{gerencia}/datos     → dataset crudo .xlsx
     [Con T11 completo se desbloquea BLOQUE D — Frontend puede avanzar en paralelo]
T12. Implementar JWT: /auth/login, token, rutas protegidas
     └── Roles: director_financiero / gerente_obra / admin_rd
     └── gerente_obra: filtrado automático por obras_habilitadas[]
T13. Conectar FastAPI a PostgreSQL 16 vía psycopg2 + queries reales
T14. Configurar nginx proxy_pass a FastAPI :8000
T15. Desplegar Pose_API como contenedor Docker en Hetzner
     └── Gemini define Dockerfile + docker-compose.yml
     └── Imagen publicada en ghcr.io/richard-ia86/pose_api:latest
     └── Deploy: GitHub Actions → ghcr.io → SSH CX33 → docker pull + restart
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
T26. Automatización de maestros lookups
     └── [QA] Prerequisito del flip — sin lookups actualizados la validación
         ETL Python vs BD_POSE_A2 puede dar falsos positivos
T27. FLIP: ETL Python apunta a PostgreSQL Hetzner (cambio de config)
     └── Validar datos coinciden con BD_POSE_A2
     └── BD_POSE_A2 y SQL Express quedan como respaldo (read-only)
T28. Procesar crudos acumulados en input_raw/ con ETL (batch)
T29. Acta de cierre Sprint 17
T30. Actualizar mapa_ecosistema.md + docs arquitectura final
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
