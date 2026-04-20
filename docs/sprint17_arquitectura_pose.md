# Sprint 17 — Nueva Arquitectura POSE

> **Estado:** ACTIVO — iniciado 2026-04-20
> **Fecha de planificación:** 2026-04-13
> **Fecha de inicio formal:** 2026-04-20
> **Bloqueante externo:** Hetzner — cuenta en verificación (ticket enviado)
> **Estrategia de espera:** Ejecutar T30–T36 (sin servidor) mientras se resuelve el bloqueo

---

## 1. Por qué se hace este cambio

El sistema actual (Streamlit local + `.bat`) tiene 5 problemas confirmados:

| Problema | Impacto |
|----------|---------|
| Requiere Python/venv instalado en cada máquina | Solo funciona en máquinas configuradas |
| Director ejecuta un `.bat` para verlo | No es autónomo ni profesional |
| Solo accesible en localhost | Sin acceso remoto |
| Diseño no corporativo | Imagen ante la dirección |
| No se puede compartir como link o PDF | Sin distribución |

**Audiencia objetivo:** Director Financiero + equipo directivo (3–5 personas) + acceso remoto.

---

## 2. Arquitectura nueva — decisiones cerradas

### Stack completo

```text
ETL Python  →  PostgreSQL 16  →  FastAPI (JWT)  →  Next.js / React
(sin cambios)  (en Linux)        (nuevo)            (nuevo)
                    ↑
              WireGuard VPN
              (acceso admin)
                     ↓
         nginx + Let's Encrypt SSL
                     ↓
           Cloudflare DNS (proxy)
                     ↓
         https://[dominio].com.ar
```

### Tabla de decisiones

| Componente | Decisión | Estado |
|------------|----------|--------|
| Base de datos | PostgreSQL 16 en Linux | ✅ Cerrado |
| Auth API | JWT propio — FastAPI + python-jose | ✅ Cerrado |
| VPN | WireGuard nativo (kernel Linux) | ✅ Cerrado |
| Dominio | `gestionpose.com.ar` — NIC Argentina | ✅ Cerrado |
| DNS | Cloudflare Free — Full strict + proxy | ✅ Cuenta creada |
| SSL | Let's Encrypt + certbot | ✅ Cerrado |
| Servidor | Hetzner CX33 — €6.99/mes | ⏳ Cuenta creada, en loop de verificación (ticket enviado, esperando) |
| OS servidor | Ubuntu 24.04 LTS | ✅ Cerrado |
| Frontend | Next.js + TypeScript (Copilot como escritor) | ✅ Cerrado |
| API | FastAPI + uvicorn | ✅ Cerrado |
| Power BI Pro | Comprar licencia ($10 USD/usuario/mes) | ⏳ No bloquea Sprint 17 |
| SSH Key | Ed25519 (`Richard.r.ia86@gmail.com`) | ✅ Generada para acceso remoto seguro |

---

## 3. Specs del servidor (Hetzner CX33)

| Recurso | Valor |
|---------|-------|
| vCPU | 4 (Intel®/AMD) |
| RAM | 8 GB |
| Disco | 80 GB SSD |
| Red | 20 TB/mes |
| Costo | €6.99/mes |
| OS recomendado | Ubuntu 24.04 LTS |

**¿Por qué CX33 y no CX23 (4 GB)?**
PostgreSQL puede usar toda la RAM disponible para shared_buffers y caché.
Con 8 GB el motor usa ~2 GB para shared_buffers + FastAPI + nginx + OS,
dejando margen real de crecimiento sin restricciones de licencia.
CX33 reemplaza al CX32 con las mismas specs a €0.53/mes menos
(plan Cost-Optimized — hardware probado y confiable).

---

## 4. Seguridad — reglas de firewall

```text
Puerto 443  TCP  → internet (nginx → Next.js + FastAPI)
Puerto 51820 UDP → internet (WireGuard handshake)
Puerto 22   TCP  → SOLO desde peers VPN
Puerto 5432 TCP  → SOLO desde peers VPN
Todo lo demás   → DROP
```

Cloudflare con proxy activo ("nube naranja") oculta la IP real del servidor.
Cualquier ataque directo al host queda bloqueado en el edge de Cloudflare.

**Regla de oro:** PostgreSQL nunca expuesto a internet. Solo accesible por VPN.

---

## 5. Cloudflare — configuración SSL

```text
Browser  →  Cloudflare (cert propio)  →  nginx (cert Let's Encrypt)
```

Modo: **Full (strict)** — dos capas de encriptación.
Resultado: candado verde en browser, IP del servidor oculta, protección DDoS incluida.

---

## 6. Commits de rollback — CONSERVAR

Si algo sale mal durante Sprint 17, estos son los puntos de retorno seguros:

| Repositorio | Hash rollback | Descripción |
|-------------|---------------|-------------|
| auditoria\_ecosauron | `52a17e4` | docs(qa): inicio jornada 2026-04-13 |
| richard\_ia86\_dev | `9872c76` | ci: workflow\_dispatch manual |
| bd\_pose\_b52 | `4fd5a54` | fix(qa): pyproject.toml + black fmt |
| planif\_pose | `b0254cb` | ci: workflow\_dispatch manual |
| data\_analytics | `14c7999` | ci: workflow\_dispatch manual |

Comando de rollback: `git reset --hard <hash>`
**Los datos en PostgreSQL son independientes del código — no se tocan en ningún caso.**

---

## 7. ETL durante Sprint 17

- **Estado:** PAUSADO
- Los crudos nuevos que lleguen se depositan en `input_raw/` con nombre estandarizado
- Formato sugerido: `FUENTE_YYYYMM_RECIBIDO.xlsx`
  - Ej: `DESPACHOS_202602_RECIBIDO.xlsx`
- **Primer acto post-Sprint 17:** procesar todos los acumulados en batch

---

## 8. Repos nuevos a crear

| Repo | Nombre GitHub | Tecnología | Workspace |
|------|--------------|------------|-----------|
| API | `Richard-IA86/Pose_API` | Python — FastAPI | Agregado a EcoSauron PASO 8 |
| Frontend | `Richard-IA86/Pose_Frontend` | TypeScript — Next.js | Agregado a EcoSauron PASO 7 |

---

## 9. QA — integración en EcoSauron

El pipeline `run_audit.sh` incorpora dos pasos nuevos:

| Paso nuevo | Herramienta | Equivalente Python |
|------------|-------------|-------------------|
| PASO 7 — Frontend | `prettier`, `eslint`, `tsc --noEmit`, `jest --ci` | black, flake8, mypy, pytest |
| PASO 8 — API | Mismas herramientas Python que hoy | Sin cambios |

Un solo `bash scripts/run_audit.sh` audita Python + TypeScript + React.

---

## 10. Secuencia de ejecución Sprint 17

### SEMANA 1 — Infraestructura base

```text
T1.  Elegir y registrar dominio .com.ar en NIC Argentina
T2.  Crear cuenta Hetzner + contratar CX32 (Ubuntu 24.04)
T3.  Crear cuenta Cloudflare + delegar NS de NIC AR a Cloudflare
T4.  Configurar firewall ufw en servidor (reglas sección 4)
T5.  Instalar WireGuard en servidor + agregar peer dev (iMac)
T6.  Instalar nginx + certbot + certificado Let's Encrypt
T7.  Instalar SQL Server 2022 Express para Linux
T8.  Migrar BD: backup desde Asus Windows → restore en Hetzner
T9.  Verificar ETL Python conecta a BD nueva vía pyodbc (por VPN)
```

### SEMANA 2 — API

```text
T10. Crear repo Pose_API — FastAPI + uvicorn + estructura base
T11. Endpoints mock: /api/v1/costos /api/v1/despachos /api/v1/mensuales
T12. Implementar JWT: /auth/login, token, rutas protegidas
T13. Conectar FastAPI a MSSQL Linux (pyodbc + queries reales)
T14. Configurar nginx proxy_pass a FastAPI :8000
T15. Desplegar como servicio systemd en servidor
T16. Agregar Pose_API al pipeline EcoSauron (PASO 8)
```

### SEMANA 3 — Frontend

```text
T17. Crear repo Pose_Frontend — Next.js + TypeScript
T18. Componentes con Copilot: Sidebar, BarChart, LineChart, DataTable
T19. Páginas: /dashboard (costos), /despachos, /mensuales
T20. Conectar fetch a FastAPI con JWT en headers
T21. Build: next build + nginx serve estático
T22. Desplegar en Hetzner + verificar SSL + Cloudflare proxy
```

### SEMANA 4 — QA, docs y transición

```text
T23. Tests Jest + React Testing Library (componentes críticos)
T24. Playwright E2E: login → ver dashboard → filtrar período
T25. Agregar Pose_Frontend al pipeline EcoSauron (PASO 7)
T26. Procesar crudos acumulados con ETL existente (batch)
T27. Acta de cierre Sprint 17
T28. Docs arquitectura final + bitácora sprint
T29. Automatizacion de maestros loockups
```

---

## 11. Pendientes antes de iniciar el chat de Sprint 17

- [x] **Dominio:** nombre `.com.ar` registrado en NIC Argentina; delegación a NS Cloudflare completada.
- [ ] **Hetzner:** resolver verificación de cuenta (en loop, correo enviado a soporte) para contratar CX33.
- [ ] **T30–T36:** tareas ejecutables sin servidor — iniciadas 2026-04-20 (ver sección 13).
- [x] **Cloudflare:** cuenta creada y nameservers asignados.
- [x] **SSH:** Public key generada (`ssh-ed25519 ... Richard.r.ia86@gmail.com`) lista para inyectar en el servidor.
- [ ] **Power BI Pro:** comprar cuando el frontend esté estable (no bloquea Sprint 17)

---

## 13. Ampliación Ecosistema — Gemini como Agente DevOps

> **Origen:** Propuesta `Propuesta_Ecosistema_Ojo_Sauron.md` — aprobada 2026-04-20

### Concepto central

Dividir responsabilidades entre los dos agentes de IA del equipo:

| Agente | Rol | Foco |
|--------|-----|------|
| **GitHub Copilot** | Auditor + Escritor | Lógica de código, QA, tests, PR reviews |
| **Gemini Advanced** | DevOps | Infraestructura Hetzner, Docker, GitHub Actions, analytics masiva |

### Bridge de despliegue — con gate humano obligatorio

```text
Copilot sugiere cambio
        │
        ▼
   PR en GitHub  ◄── GATE: merge manual por el dev
        │
        ▼
  GitHub Actions  (workflow disparado por merge a main)
        │
        ├── Paso 1: run_audit.sh (QA: black/flake8/mypy/pytest)
        ├── Paso 2: docker build + push a registry
        └── Paso 3: SSH al CX33 → docker pull + restart
              ▲
        Gemini define y mantiene este workflow
```

> **Regla de oro del bridge:** Ningún deploy automático sin merge humano previo.
> Copilot no pushea a producción. Gemini no toca el código.

### Inventario correcto de máquinas

| ID | Máquina | OS | Rol |
|----|---------|-----|-----|
| M1 | iMac | Linux (dev principal) | Desarrollo, CI local, VPN peer |
| M2 | Asus (Linux side) | Ubuntu/WSL2 | Dev secundario, SQL Express local |
| M3 | HP | Windows | Simulador cliente/directivo — solo .bat + dashboard |
| S1 | Hetzner CX33 | Ubuntu 24.04 LTS | Producción — PostgreSQL, FastAPI, nginx |

### Gestión de secretos (definición)

| Secreto | Dónde vive | Cómo se usa |
|---------|------------|-------------|
| DB_PASSWORD | GitHub Secrets | Inyectado en GitHub Actions (nunca en código) |
| JWT_SECRET_KEY | GitHub Secrets | Idem |
| HETZNER_SSH_PRIVATE_KEY | GitHub Secrets | SSH deploy step en Actions |
| WireGuard peer keys | `/etc/wireguard/` en S1 | Solo en servidor, nunca en repo |

### Tareas ejecutables SIN servidor Hetzner (mientras se espera)

```text
T30. Crear repo Pose_API en GitHub + scaffold FastAPI local
     └── main.py, routers/, schemas/, tests/ — estructura base
     └── pytest local pasa sin BD (mocks)
     └── Agregarlo al workspace EcoSauron cuando exista

T31. Crear repo Pose_Frontend en GitHub + scaffold Next.js local
     └── npx create-next-app --typescript
     └── Estructura: components/, pages/, lib/api.ts
     └── Agregarlo al workspace EcoSauron cuando exista

T32. Diseñar GitHub Actions workflow (draft YAML, sin ejecutar)
     └── .github/workflows/deploy.yml en Pose_API
     └── Trigger: push a main
     └── Jobs: qa → docker-build → deploy (SSH)
     └── El job deploy queda comentado hasta que S1 exista

T33. Avanzar migración PostgreSQL (PR #7 BD_POSE_B52)
     └── Continuar sin servidor real — tests con pg local o mock
     └── Scripts SQL compatibles con PG 16 listos para S1

T34. Definir estructura Docker
     └── Dockerfile para Pose_API (python:3.12-slim)
     └── docker-compose.yml dev: api + postgres local
     └── .dockerignore

T35. Diseñar roles Gemini (prompt engineering)
     └── Qué tareas delega el dev a Gemini en infraestructura
     └── Protocolo de handoff Copilot → Gemini

T36. Documentar WireGuard peer config para M1 y M2
     └── Solo la config del lado cliente (sin IP del servidor aún)
     └── Lista para copiar-pegar cuando S1 esté disponible
```

---

## 12. Contexto del sistema actual — referencia

| Ítem | Valor |
|------|-------|
| ETL | `richard_ia86_dev/projects/report_direccion/` |
| Fuentes | DESPACHOS / MENSUALES / GG FDL / FACTURACION FDL |
| BD actual | SQL Server Express en Asus Windows (`RICHARD_ASUS\SQLEXPRESS`) |
| Tests actuales | 231 passed / 1 skipped |
| QA pipeline | EcoSauron `run_audit.sh` — 5/5 APROBADO |
| Último commit orquestador | `52a17e4` |
