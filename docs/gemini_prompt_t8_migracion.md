# Gemini — Tarea T8: Migración BD_POSE_A2 + DW_GrupoPOSE_B52

**Contexto:** Migrar las bases de datos del servidor Windows
(RICHARD_ASUS\SQLEXPRESS) a PostgreSQL 16 en Hetzner CX33.

**Tu rol:** Agente de migración. Los archivos `.dump` son generados
desde la máquina Asus Windows por Copilot y subidos al servidor via
SCP a través de WireGuard. Tú recibirás los dumps y ejecutas el restore.

**Ejecutar en:** Hetzner CX33 — como root vía SSH

**Prerrequisito:** T7 completado (PostgreSQL 16 activo, pose_db con
esquemas, directorio /backups/snapshots creado)

---

## Fase 1 — Snapshot pre-migración (snapshot de seguridad)

Este snapshot protege el estado limpio de pose_db antes de importar datos.

```bash
# Snapshot del estado vacío (previo a migración)
sudo -u postgres pg_dump \
  --format=custom \
  --file=/backups/snapshots/snapshot_pre_migracion_$(date +%Y%m%d_%H%M%S).dump \
  pose_db

ls -lh /backups/snapshots/
```

---

## Fase 2 — Recibir los dumps desde Asus (Copilot los genera)

Copilot en la máquina Asus generará y subirá por SCP:

- `bd_pose_a2_export.sql` — datos de BD_POSE_A2 (SQLServer → PostgreSQL)
- `dw_grupopose_b52_export.sql` — datos de DW_GrupoPOSE_B52

**Verificar que los archivos llegaron:**

```bash
ls -lh /backups/snapshots/bd_pose_a2_export.sql
ls -lh /backups/snapshots/dw_grupopose_b52_export.sql
sha256sum /backups/snapshots/bd_pose_a2_export.sql
sha256sum /backups/snapshots/dw_grupopose_b52_export.sql
```

Confirmar los checksums con Copilot antes de importar.

---

## Fase 3 — Restaurar BD_POSE_A2 en esquema `datos`

```bash
sudo -u postgres psql -d pose_db << 'EOF'
-- Limpiar esquema datos antes de importar (si ya tiene algo)
DROP SCHEMA IF EXISTS datos CASCADE;
CREATE SCHEMA datos AUTHORIZATION pose_app;
GRANT USAGE ON SCHEMA datos TO pose_backup;
EOF
```

```bash
# Importar BD_POSE_A2
sudo -u postgres psql \
  -d pose_db \
  -v ON_ERROR_STOP=1 \
  -f /backups/snapshots/bd_pose_a2_export.sql 2>&1 \
  | tee /tmp/import_bd_pose_a2.log

echo "Exit code: $?"
tail -20 /tmp/import_bd_pose_a2.log
```

**Verificar:**

```bash
sudo -u postgres psql -d pose_db -c "
  SELECT table_schema, table_name, pg_size_pretty(
    pg_total_relation_size(
      quote_ident(table_schema) || '.' || quote_ident(table_name)
    )
  ) AS size
  FROM information_schema.tables
  WHERE table_schema = 'datos'
  ORDER BY table_name;
"
```

---

## Fase 4 — Restaurar DW_GrupoPOSE_B52 en esquema `etl`

```bash
sudo -u postgres psql -d pose_db << 'EOF'
DROP SCHEMA IF EXISTS etl CASCADE;
CREATE SCHEMA etl AUTHORIZATION pose_app;
GRANT USAGE ON SCHEMA etl TO pose_backup;
EOF
```

```bash
sudo -u postgres psql \
  -d pose_db \
  -v ON_ERROR_STOP=1 \
  -f /backups/snapshots/dw_grupopose_b52_export.sql 2>&1 \
  | tee /tmp/import_dw_b52.log

echo "Exit code: $?"
tail -20 /tmp/import_dw_b52.log
```

**Verificar:**

```bash
sudo -u postgres psql -d pose_db -c "
  SELECT table_schema, table_name
  FROM information_schema.tables
  WHERE table_schema = 'etl'
  ORDER BY table_name;
"
```

---

## Fase 5 — Restaurar permisos pose_backup post-migración

Después de recrear esquemas con `DROP ... CASCADE`, los permisos de
`pose_backup` quedan borrados. Restaurar:

```bash
sudo -u postgres psql -d pose_db << 'EOF'
GRANT USAGE ON SCHEMA catalogos, datos, auth, etl TO pose_backup;
GRANT SELECT ON ALL TABLES
  IN SCHEMA catalogos, datos, auth, etl TO pose_backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA catalogos, datos, auth, etl
  GRANT SELECT ON TABLES TO pose_backup;
EOF
```

---

## Fase 6 — Snapshot post-migración (estado final)

```bash
sudo -u postgres pg_dump \
  --format=custom \
  --file=/backups/snapshots/snapshot_post_migracion_$(date +%Y%m%d_%H%M%S).dump \
  pose_db

ls -lh /backups/snapshots/
```

---

## Verificación final completa

```bash
sudo -u postgres psql -d pose_db -c "
SELECT
  schemaname,
  COUNT(*) AS tablas
FROM pg_tables
WHERE schemaname IN ('catalogos','datos','auth','etl')
GROUP BY schemaname
ORDER BY schemaname;
"
```

```bash
# Confirmar que pose_app puede leer datos
psql -U pose_app -h 127.0.0.1 -d pose_db -c "
  SELECT COUNT(*) FROM datos.<tabla_principal>;
"
```

---

## Reportar a Copilot cuando esté completo

- [ ] Snapshot pre-migración generado en /backups/snapshots/
- [ ] Dumps recibidos — checksums verificados con Copilot
- [ ] BD_POSE_A2 importada — exit code 0, log sin errores FATAL
- [ ] DW_GrupoPOSE_B52 importada — exit code 0, log sin errores FATAL
- [ ] `pose_backup` tiene SELECT en todos los esquemas
- [ ] Snapshot post-migración generado
- [ ] Conteo de tablas por esquema enviado a Copilot
