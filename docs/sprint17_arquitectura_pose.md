# Sprint 17 — Nueva Arquitectura POSE

> **Estado:** PLANIFICADO — pendiente confirmación para iniciar backlog formal
> **Fecha de planificación:** 2026-04-13
> **Próxima acción:** crear servidor CX33 y configurar DNS Cloudflare para gestionpose.com.ar

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
| DNS | Cloudflare Free — Full strict + proxy | ⏳ Cuenta a crear |
| SSL | Let's Encrypt + certbot | ✅ Cerrado |
| Servidor | Hetzner CX33 — €6.99/mes | ✅ Cuenta creada, pendiente activación tarjeta |
| OS servidor | Ubuntu 24.04 LTS | ✅ Cerrado |
| Frontend | Next.js + TypeScript (Copilot como escritor) | ✅ Cerrado |
| API | FastAPI + uvicorn | ✅ Cerrado |
| Power BI Pro | Comprar licencia ($10 USD/usuario/mes) | ⏳ No bloquea Sprint 17 |

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
```

---

## 11. Pendientes antes de iniciar el chat de Sprint 17

- [ ] **Dominio:** elegir y registrar nombre `.com.ar` en NIC Argentina
- [ ] **Hetzner:** crear cuenta en hetzner.com
- [ ] **Cloudflare:** crear cuenta en cloudflare.com
- [ ] **Power BI Pro:** comprar cuando el frontend esté estable (no bloquea Sprint 17)

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
