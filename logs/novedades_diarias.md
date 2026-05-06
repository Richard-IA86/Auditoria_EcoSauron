# Briefing de Inicio de Jornada - 2026-05-06

## Crew — Estado de Ejecución

- **Inicio:** 2026-05-06T13:14:38
- **Duración total:** 36.4s
- **Pasos:**
  - `wireguard`: OK (2.3s)
  - `containers`: OK (3.7s)
  - `api_endpoint`: OK (7.4s)
  - `postgres`: OK (6.2s)
  - `git_status`: OK (5.7s)
  - `git_pull_proyectos`: OK (4.6s)
  - `drift_checks`: OK (6.4s)

**Semáforo Global:** AMARILLO

## Alertas

- **dim_obras_drift** (WARN): dim_obras desincronizada

## Estado de Proyectos

### ecosauron

- **Sincronización:** Sincronizado OK
- **Último cierre:** 2026-05-05
- **Pipeline:** VERDE
- **Notas QA:** Jornada de diagnóstico y alineación M1/M2. SSH cron corregido. Desacople planif_pose resuelto con p...
- **Pendientes:**
  - [M2/Windows] Validar prueba diferencial v2: correr 1+5 del .bat con cambio real en input_raw
  - [M2/Windows] Investigar si OBRA_PRONTO y FUENTE son sobreescritos por Power Query desde tabla maestra
  - [M1/Linux] Revisar lógica generador_b52_incremental_v2.py — no capturó delta +31 inserts +1 update (con M2)

### gestion_comp

- **Sincronización:** Skipped (Regla de repositorio)
- **Último cierre:** 2026-05-04
- **Pipeline:** VERDE
- **Notas QA:** RN-001 registrada. Dry-run OK: 582 filas (434 ProntoNet + 148 históricas), 11 COMPENSABLE_CAMBIO ac...
- **Pendientes:**
  - Ejecutar sin --dry-run y verificar escritura real en Loockups.xlsx
  - Test real con conexión PostgreSQL DEV (dim_obras_gerencias)
  - QA: tests/test_actualizar_obras_gerencias.py con fixtures sin FAT32
  - Verificar deploy en producción: www.gestionpose.com.ar

### planif_pose

- **Sincronización:** Sincronizado OK
- **Último cierre:** 2026-05-05
- **Pipeline:** VERDE
- **Notas QA:** Jornada 2026-05-05: fix COMPENSABLE completado y verificado. Las 4 tareas del sprint anterior marca...

### bd_pose_b52

- **Sincronización:** Sincronizado OK
- **Error:** Fallo lectura JSON: Expecting property name enclosed in double quotes: line 229 column 5 (char 13103)

### richard_ia86_dev

- **Sincronización:** Sincronizado OK
- **Último cierre:** 2026-04-20
- **Pipeline:** VERDE
- **Notas QA:** QA re-aplicó rollback_20260420 completo. 226 tests VERDE. HP eliminado de toda la config. Pipeline ...
- **Pendientes:**
  - Obra 479 (PUNTA LARA): actualizar Loockups.xlsx fila 589 de 00009999 a 00000479 (cosmético)
  - Evaluar 4 duplicados residuales QUINCENAS 03-2026.xlsx (FECHA+OBRA+CUENTA+DETALLE idénticos)

### data_analytics

- **Sincronización:** Sincronizado OK
- **Último cierre:** 2026-05-02
- **Pipeline:** VERDE
- **Notas QA:** Cierre de jornada automático de la IA.
- **Pendientes:**
  - Reanudación de los sprints en curso
