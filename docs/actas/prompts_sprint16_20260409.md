# Prompts de Tareas — Sprint 16 / Jornada 2026-04-09

> Generado por: El Ojo de Sauron (Agente Auditor QA)
> Fecha: 2026-04-09 (revisado arquitectura 2026-04-09)
> Pipeline base: 5/5 APROBADO — 231 tests verdes
>
> **Arquitectura de referencia:**
> Asus (Linux) = motor CI/CD + SQL Express + VPN + Streamlit
> HP (Windows) = simulador usuario final (demo, .bat, UX)

---

## PRIORIDAD ALTA

---

### PROMPT-01 — Smoke Test HP — Validación UX Usuario Final (richard_ia86_dev)

**Entorno:** HP (Windows) — simulador de máquina de usuario
**No aplica a Asus.** El pipeline (ETL, BD, datos) ya fue validado en Asus.
Este test verifica únicamente que el usuario final ve lo correcto en pantalla.

**Contexto:** Demo del Director Financiero: 10/04/2026 11:00 hs.
`lanzar_demo.py` completado en Asus (commit `3c5ff09`). Validar que el
launcher `.bat` funciona en el entorno Windows del usuario.

**Tarea para el dev:**

```text
Ejecutar en máquina HP (Windows):

1. Abrir CMD como usuario normal (sin admin).
2. Correr: demo_presentacion.bat
3. Verificar UX:
   a. venv activa sin errores.
   b. Menú de 4 opciones aparece.
   c. Opción DESPACHOS → pipeline sin traceback.
   d. Dashboard abre en localhost:8502 con datos visibles.
   e. Tab Resumen muestra métricas (no vacío).
   f. Formato números: separador miles y decimales legibles.
4. Si hay fallo en HP: el problema es de entorno Windows (rutas, venv, bat).
   NO es un bug de lógica — esos ya están cubiertos por los 139 tests en Asus.
5. Registrar en estado_proyecto.json:
   "siguiente_accion": "SMOKE_HP: OK/FALLO — detalle corto"
```

**Criterio de éxito:** Dashboard carga con datos en HP. Sin tracebacks.

**Archivos relevantes:**

- `demo_presentacion.bat`
- `lanzar_demo.py`
- `projects/report_direccion/src/dashboard/app_director.py`

---

### PROMPT-02 — Resolver 420 Rechazados DESPACHOS (richard_ia86_dev)

**Entorno:** Asus (Linux) — pyodbc + SQLEXPRESS disponibles. Ejecutar aquí.

**Contexto:** `pendientes_carga.csv` contiene 420 registros sin cargar.
Con la arquitectura correcta (SQLEXPRESS en Asus), este diagnóstico se
hace directamente contra la BD real — sin mock, sin necesitar HP.

**Tarea para el dev:**

```text
En Asus — con SQLEXPRESS activo:

1. Leer pendientes_carga.csv:
   import pandas as pd
   df = pd.read_csv("output/report_gerencias/pendientes_carga.csv", sep=";")
   print(df["motivo_rechazo"].value_counts())

2. Clasificar los rechazos por motivo_rechazo:
   a. hash_duplicado → ya están en BD, descartar sin error.
   b. columna_nula → corregir en transformer.py.
   c. tipo_invalido  → corregir mapeo en pipeline_stages.py.

3. Corregir en el módulo correspondiente.

4. Reejecutar pipeline desde Asus:
   python3 projects/report_direccion/run_despachos.py

5. Verificar PENDIENTE=0 en la BD real (requiere msodbcsql18 en
   Linux — ver proyecto_ojo_sauron_asus_linux.md W1-01).
   Si el driver no está instalado, verificar desde SSMS en Asus (Windows):
   SELECT COUNT(*) FROM PRODUCCION.pendientes WHERE estado='PENDIENTE'

6. Commitear:
   fix(despachos): resolver N rechazados — motivo: X
```

**Criterio de éxito:** `pendientes_carga.csv` sin filas activas.
Consulta SQL retorna 0.

**Archivos relevantes:**

- `projects/report_direccion/src/bd_loader_despachos.py`
- `projects/report_direccion/src/transformer.py`
- `output/report_gerencias/pendientes_carga.csv`

---

### PROMPT-03 — Scripts ML Observability (bd_pose_b52)

**Contexto:** `02_scripts/python/ml/` está vacío. FASE_4 no puede iniciar
hasta que LOCAL cree y pushee los scripts. El DW tiene >8.000 filas en
`PRODUCCION.costos` (datos de prueba disponibles).

**Tarea para el dev (LOCAL):**

```text
Crear en 02_scripts/python/ml/:

1. calcular_zscores.py
   - Lee PRODUCCION.costos agrupado por GERENCIA y PERIODO.
   - Calcula z-score de IMPORTE por grupo.
   - Escribe resultado en tabla ANALYTICS.anomalias (crear si no existe).
   - Parámetro CLI: --periodo YYYY-MM (opcional, default = todos).

2. calcular_percentiles.py
   - Lee PRODUCCION.costos.
   - Calcula percentiles p25/p50/p75/p90 por GERENCIA.
   - Escribe en ANALYTICS.percentiles_gerencia.
   - Parámetro CLI: --gerencia (opcional, default = todas).

3. detectar_anomalias.py
   - Combina z-scores + percentiles.
   - Marca como ANOMALIA si z > 2.5 o > p90.
   - Genera reporte CSV en 03_output/anomalias_YYYYMM.csv.

Estándares obligatorios:
   - black + flake8 + mypy: 0 errores.
   - Líneas máx 79 chars.
   - Tests unitarios con datos mock (sin conexión BD real).
   - Docstring de módulo en cada archivo.

Commit cuando pasen los 3 requisitos estáticos:
   feat(ml): scripts z-score + percentiles + anomalias FASE_4
```

**Criterio de éxito:** `python3 -m pytest 02_scripts/python/ml/tests/`
pasa. `flake8 02_scripts/python/ml/` = 0 errores.

---

## PRIORIDAD MEDIA

---

### PROMPT-04 — Formato ARS y Fechas en Dashboard (richard_ia86_dev)

**Contexto:** El dashboard del Director Financiero usa formatos de número y
fecha anglosajones. Para la demo con directivos argentinos se esperan
formatos locales.

**Tarea para el dev:**

```text
En app_director.py:

1. Importar locale o usar f-strings para formato ARS:
   - Números: separador de miles punto, decimal coma.
   - Ejemplo: $ 1.234.567,89 → usar f"{valor:,.2f}".replace(",","X")
     .replace(".",",").replace("X",".")
   - Alternativa limpia: crear helper format_ars(valor: float) -> str

2. Fechas: columnas PERIODO o fecha_documento → formato dd/mm/yyyy.
   - pd.to_datetime(col).dt.strftime("%d/%m/%Y")

3. Actualizar test_app_director_smoke.py si el helper es exportable.

Commit:
   feat(dashboard): formato ARS y fechas dd/mm/yyyy — mejora UX demo
```

**Criterio de éxito:** En la demo, los importes muestran `$` con puntos de
miles y coma decimal. Las fechas no muestran formato ISO.

---

### PROMPT-05 — Ampliar Cobertura Tests bd_pose_b52 (bd_pose_b52)

**Contexto:** Con solo 7 tests, el repo cubre apenas `utils/validaciones.py`.
El pipeline de carga (FASE_3) usa scripts sin ningún test unitario, lo que
es un riesgo antes de ejecutar en el servidor.

**Tarea para el dev:**

```text
Crear en tests/:

1. test_cargar_catalogos.py
   - Mock de conexión ODBC (usar unittest.mock).
   - Test: carga correcta de gerencias (datos mínimos).
   - Test: manejo de error de conexión → sys.exit(1).
   - Test: carga con campo nulo → ValueError.

2. test_cargar_costos.py
   - Mock de pandas read_excel.
   - Test: filas válidas pasan a staging.
   - Test: filas con IMPORTE negativo marcadas como rechazadas.
   - Test: archivo vacío → advertencia + exit 0 (no error).

Estándares:
   - Usar pytest + unittest.mock (sin pyodbc real).
   - black + flake8 + mypy: 0 errores.
   - Líneas máx 79 chars.

Objetivo: subir de 7 a ≥ 20 tests antes de ejecutar FASE_3 en servidor.

Commit:
   test(cargas): cobertura catalogos + costos — mock ODBC
```

**Criterio de éxito:** `python3 -m pytest` en bd_pose_b52 ≥ 20 passed.

---

### PROMPT-06 — Sprint 14 data_analytics (data_analytics)

**Contexto:** `punto_de_partida.json` tiene `sprint_actual: 13` y
`estado: "completado"`. No hay Sprint 14 declarado aunque el repo tuvo
actividad posterior.

**Tarea para el dev:**

```text
Actualizar punto_de_partida.json:

{
  "sprint_actual": 14,
  "estado": "activo",
  "fecha_ultima_actualizacion": "2026-04-09",
  "tareas_pendientes": [
    "[MEDIA] Definir próxima práctica TP o módulo de análisis",
    "[BAJA] Revisar notebooks TP2/TP3 con nueva versión pandas"
  ],
  "tareas_completadas": [
    ... (conservar existentes) ...,
    "Sprint 13 cerrado: 38 tests, pymarkdown OK, QA aprobado"
  ]
}

Commit:
   chore(estado): Sprint 14 activo — actualizar punto_de_partida
```

**Criterio de éxito:** `jq '.sprint_actual' punto_de_partida.json` → 14.

---

## PRIORIDAD BAJA

---

### PROMPT-07 — Métrica Tests en Reporte run_audit.sh (orquestador)

**Contexto:** El reporte generado en `docs/reportes/` no incluye el total de
tests ejecutados. Sería valioso para tendencias semanales y presentación al
equipo.

**Tarea para el dev QA (orquestador):**

```text
En scripts/run_audit.sh, función run_tests():

1. Capturar la línea de resumen de pytest:
   summary=$(cd "$repo_path" && python3 -m pytest -q 2>&1 | tail -1)
   Ejemplo: "139 passed, 1 skipped in 1.96s"

2. Almacenar en variable asociativa o acumular:
   TESTS_RESULTS["$repo_name"]="$summary"

3. Al final del pipeline, añadir sección al reporte:
   ## Tests
   | Repo | Resultado |
   |------|-----------|
   | richard_ia86_dev | 139 passed, 1 skipped |
   | planif_pose | 47 passed |
   | bd_pose_b52 | 7 passed |
   | data_analytics | 38 passed |
   | TOTAL | 231 passed, 1 skipped |

Commit:
   feat(audit): agregar métrica tests al reporte diario
```

**Criterio de éxito:** `cat docs/reportes/reporte_FECHA.md` incluye sección
"Tests" con total acumulado.

---

### PROMPT-08 — Túnel ngrok Dashboard (richard_ia86_dev)

**Contexto:** El dashboard corre en `localhost:8502` en la PC principal. Para
acceso desde HP sin configurar red, ngrok ofrece un túnel HTTP temporal.

**Tarea para el dev:**

```text
1. Instalar ngrok: snap install ngrok (o descargar binario).
2. Autenticar: ngrok config add-authtoken <TOKEN>
   (obtener token gratuito en https://ngrok.com)
3. Lanzar túnel: ngrok http 8502
4. Anotar URL pública (ej. https://abc123.ngrok.io).
5. Acceder desde HP al URL y verificar dashboard.
6. Documentar en docs/acceso_remoto.md:
   - Comando de inicio.
   - Tiempo de vida del túnel (plan gratuito: 8 hs).
   - Advertencia: no compartir URL públicamente.

Nota: Esta tarea NO requiere código Python. Solo configuración.
No commitear el authtoken al repo.
```

**Criterio de éxito:** Dashboard accesible desde HP via URL ngrok.

---

## Resumen de Prioridades

| ID | Repo | Prioridad | Esfuerzo est. |
|----|------|-----------|---------------|
| PROMPT-01 | richard_ia86_dev | ALTA | 30 min |
| PROMPT-02 | richard_ia86_dev | ALTA | 2-4 hs |
| PROMPT-03 | bd_pose_b52 | ALTA | 3-4 hs |
| PROMPT-04 | richard_ia86_dev | MEDIA | 1 hs |
| PROMPT-05 | bd_pose_b52 | MEDIA | 2-3 hs |
| PROMPT-06 | data_analytics | MEDIA | 15 min |
| PROMPT-07 | orquestador | BAJA | 1 hs |
| PROMPT-08 | richard_ia86_dev | BAJA | 30 min |

---

Acta relacionada: ACTA-20260409-001.md
