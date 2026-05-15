# Procedimiento DRP — Recarga Masiva `fact_costos_b52`

**Repositorio:** POSE_ETL
**Script:** `src/loader/recarga_masiva_b53_prod.py`
**Última ejecución exitosa:** 2026-05-15 — 473,098 filas

---

## Cuándo ejecutar este procedimiento

- Cambio de schema en `fact_costos_b52` (nuevas columnas, tipos)
- El bifurcador generó un nuevo CSV base con todos los registros históricos
- Corrupción o inconsistencia detectada en la tabla
- Rebuild completo post-migración de servidor

**NO ejecutar** para actualizaciones incrementales — esas van por el
delta del bifurcador (`costos_b52_*_delta.csv`).

---

## Arquitectura: GERENCIA en el bifurcador

`BaseCostosPOSE.xlsx` en M2 ahora genera GERENCIA al 100% — el bifurcador
fue corregido por Isindur (commit `88b25d0`, 2026-05-15) para incluir
GERENCIA en `_sha256_importe` y verificar cobertura 0 vacíos.

**Flujo actual:**

- GERENCIA viene poblada en el CSV fuente (473,098 / 473,098).
- El paso `[4/5]` sincroniza con `dim_obras_gerencias`: para los registros
  que tienen match en dim, GERENCIA del dim sobreescribe el valor del CSV
  (la dimensión sigue gobernando).
- Los registros sin match en dim (actualmente 65 obras) conservan el valor
  GERENCIA que trae el CSV.
- Post-sincronización: 473,098 / 473,098 filas con GERENCIA no nula.

**Cobertura actual:** 473,098 / 473,098 filas (100%).

---

## Pre-requisitos

### 1. WireGuard VPN activa

```bash
ip route | grep 10.10.0
# Debe mostrar: 10.10.0.0/24 dev wg0 scope link
```

Si no aparece: `sudo wg-quick up wg0`

### 2. `config/.env` configurado

```bash
ls /home/richard/Dev/POSE_ETL/config/.env
```

Si no existe, crearlo:

```bash
cat > /home/richard/Dev/POSE_ETL/config/.env << 'EOF'
ETL_ENV=PROD
PG_HOST=10.10.0.1
PG_PORT=5432
PG_USER=pose_admin
PG_PASS=PoseAdmin2026!
PG_DB_PROD=dw_grupopose_b52_prod
PG_DB_DEV=dw_grupopose_b52_dev
EOF
```

> **NUNCA hacer `git add` del `.env`.** Está en `.gitignore`.

### 3. CSV del bifurcador disponible

```bash
ls -lh /home/richard/Dev/POSE_ETL/output/b52/costos_b52_*.csv \
  | grep -v "_delta" | grep -v "_hashes"
```

El script **auto-detecta el más reciente** — no hace falta editar rutas.

### 4. `dim_obras_gerencias` cargada en PostgreSQL

```bash
/home/richard/Dev/POSE_ETL/.venv/bin/python -c "
from dotenv import load_dotenv; import os
load_dotenv('/home/richard/Dev/POSE_ETL/config/.env')
from sqlalchemy import create_engine, text
u = (
    f\"postgresql+psycopg2://{os.getenv('PG_USER')}\"
    f\":{os.getenv('PG_PASS')}@{os.getenv('PG_HOST')}\"
    f\":{os.getenv('PG_PORT')}/{os.getenv('PG_DB_PROD')}\"
)
with create_engine(u).connect() as c:
    r = c.execute(text(
        'SELECT COUNT(*) FROM dim_obras_gerencias'
        ' WHERE gerencia IS NOT NULL'
    )).fetchone()
    print('dim_obras_gerencias con gerencia:', r[0])
"
```

Debe retornar > 500. Si es 0: cargar `dim_obras_gerencias` primero
(ver `src/dims/`).

### 5. Actualizar `FILAS_ESPERADAS` si el CSV cambió

El valor en el script debe coincidir con el recuento real de filas del CSV.
**No usar `wc -l`** — sobrecontará si hay saltos de línea embebidos en
campos de texto (DETALLE, OBSERVACION, PROVEEDOR). Usar pandas:

```bash
/home/richard/Dev/POSE_ETL/.venv/bin/python -c "
import pandas as pd
import glob, os
directorio = '/home/richard/Dev/POSE_ETL/output/b52'
csvs = sorted(
    [p for p in glob.glob(f'{directorio}/costos_b52_*.csv')
     if '_delta' not in p and '_hashes' not in p],
    key=os.path.getmtime, reverse=True
)
df = pd.read_csv(csvs[0], sep='|', usecols=['OBRA_PRONTO'])
print(f'FILAS_ESPERADAS = {len(df):,}  →  archivo: {csvs[0]}')
"
```

Editar la constante en el script:

```python
# src/loader/recarga_masiva_b53_prod.py  línea ~37
FILAS_ESPERADAS = 473_098   # ← actualizar si cambió
```

---

## Ejecución

```bash
cd /home/richard/Dev/POSE_ETL
source .venv/bin/activate
python src/loader/recarga_masiva_b53_prod.py
```

### Flujo del script (5 pasos)

| Paso | Acción | Duración aprox. |
|------|--------|-----------------|
| `[1/5]` | DROP TABLE + CREATE TABLE (17 cols) | < 1 seg |
| `[2/5]` | Leer CSV completo con pandas | ~30 seg |
| `[3/5]` | INSERT en batches de 50,000 filas via WireGuard | ~40 min |
| `[4/5]` | Sincronizar GERENCIA con `dim_obras_gerencias` + validar cobertura | < 5 seg |
| `[5/5]` | Validar COUNT(*) DB == filas CSV | < 1 seg |

### Salida esperada al finalizar

```text
✅ RECARGA COMPLETA — todo cuadra.
      Filas CSV        : 473,098
      COUNT(*) DB      : 473,098
      GERENCIA poblada : 473,098
      Filas esperadas  : 473,098
```

Si aparece `⚠️ COUNT cuadra con CSV pero difiere del esperado`:
el COUNT DB == filas CSV pero no coincide con `FILAS_ESPERADAS`.
**Los datos están correctos.** Solo actualizar la constante y
hacer commit.

Si aparece `❌ DIVERGENCIA`: los datos no cuadraron. No tocar nada.
Investigar antes de continuar.

---

## Verificación post-carga

### Endpoint dashboard

```bash
curl -s "https://api.gestionpose.com.ar/api/v1/b53/dashboard-data" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('months      :', len(d.get('months', [])))
print('gerencias   :', len(d.get('gerencias_list', [])),
      d.get('gerencias_list', [])[:3])
print('obras       :', len(d.get('obras', [])))
"
```

**Valores esperados:**

- `months` → 72+ (rango histórico 2019–presente)
- `gerencias_list` → 19+ gerencias distintas
- `obras` → 448+

Si `gerencias_list: []` con `months: []`: verificar que el contenedor
Docker de Pose_API está corriendo la imagen más reciente.

### Verificar imagen en Hetzner

```bash
ssh root@10.10.0.1 "
  cd /opt/pose
  docker compose ps
  docker inspect pose_api --format '{{.Config.Image}}'
"
```

Si la imagen es antigua → `docker compose pull api && docker compose up -d api`

---

## Commits post-ejecución

```bash
cd /home/richard/Dev/POSE_ETL

# 1. Actualizar estado_proyecto.json
# Campos a modificar:
#   - alertas_pendientes.recarga_b53_prod.estado → "COMPLETADO"
#   - m2_pendiente.tarea → ""
#   - ultimo_resultado → nueva entrada con fecha y totales
#   - desarrollo_local.punto_de_partida_manana → siguiente tarea

# 2. Commit
git add config/estado_proyecto.json
git commit -m "chore(jornada): recarga masiva b53 YYYY-MM-DD — N filas"
git push
```

---

## Causas raíz conocidas y estado

- **GERENCIA NULL en CSV**: ✅ RESUELTO (2026-05-15, commit `88b25d0` Isindur).
  El bifurcador fue corregido — GERENCIA viene 100% poblada desde el CSV.
  El paso `[4/5]` sincroniza con `dim_obras_gerencias` (dim gobierna sobre
  CSV para los registros con match; los 65 sin match conservan valor CSV).
- **`wc -l` sobrecontaba filas**: `\n` embebidos en campos
  DETALLE/OBSERVACION/PROVEEDOR. Usar pandas para contar filas reales.
- **`.env` no persiste**: `config/.env` está en `.gitignore`. Recrear
  manualmente en cada sesión M1 nueva.

---

## Schema actual `fact_costos_b52`

```sql
CREATE TABLE fact_costos_b52 (
    "OBRA_PRONTO"       VARCHAR(20),
    "DESCRIPCION_OBRA"  TEXT,
    "FECHA"             DATE,
    "FUENTE"            VARCHAR(100),
    "TIPO_COMPROBANTE"  VARCHAR(100),
    "NRO_COMPROBANTE"   VARCHAR(100),
    "PROVEEDOR"         TEXT,
    "DETALLE"           TEXT,
    "CODIGO_CUENTA"     VARCHAR(50),
    "IMPORTE"           NUMERIC(18, 2),
    "OBSERVACION"       TEXT,
    "RUBRO_CONTABLE"    VARCHAR(200),
    "CUENTA_CONTABLE"   VARCHAR(200),
    "COMPENSABLE"       VARCHAR(100),
    "GERENCIA"          VARCHAR(100),
    "TC"                NUMERIC(10, 6),
    "IMPORTE_USD"       NUMERIC(18, 2)
);
```

17 columnas. No incluye: `ANIO`, `MES`, `_hash_fila`, `_hash_importe`,
`_estado_carga` — esas son columnas de control del bifurcador, no se
cargan en producción.
