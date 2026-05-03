# Punto de Partida (Sprint 17) - 2026-05-02
**Estado a la pausa**:
1. **Infraestructura (Bloque A)**: 100% COMPLETADO.
   - WireGuard activo (10.10.0.1 <-> 10.10.0.2).
   - PostgreSQL 16 instalado y securizado.
   - Máster estructural ejecutado con éxito vía DBeaver. BD `dw_grupopose_b52` lista.
2. **Estrategia ETL (Bloque B)**: REDEFINIDA.
   - Se eligió la **Opción A**. La responsabilidad de migración y la ingesta incremental a POSTGRESQL no recaerá en DBeaver ni en scripts obsoletos.
   - Se creó un nuevo proyecto dedicado a orquestar el movimiento de datos de por vida: **`Pose_DataPipeline`**.
   - Rol: Será el "Vigilante" que leerá el `output_reservorio` (las A procesadas u otras cosas) e inyectará a PostgreSQL mediante Psycopg2 usando UPSERTs (garantizando cero duplicados y control).

**Siguiente paso al reanudar**:
Enfocarnos en `Pose_DataPipeline`. 
- Crear entorno virtual / dependencias.
- Codificar la clase `conexion_pg.py`
- Mudar/Alinear lo que corresponda para iniciar el bombeo de datos.

**Refinamiento Arquitectónico (Decisión QA)**:
- Se suspende la prueba con archivos crudos manuales ("prueba pendiente").
- `Planif_POSE` asume la responsabilidad de formatear la salida dual:
  1. `output_reservorio/` -> Sigue alimentando BD_POSE_A2 (legacy).
  2. `output_reservorio_incr/` -> Genera los archivos incrementales limpios.
- El `Pose_DataPipeline` (inbox) a partir de ahora saca su material exclusivamente de `output_reservorio_incr`.
- A futuro, la optimización de `GestionComp` proveerá archivos lo suficientemente estructurados como para ser tomados directo por el pipeline sin pasar por Planif.

## 3. Estrategia de Entornos y Resiliencia (Acuerdo Dirección)
Se define una separación estricta de entornos para garantizar resultados inmediatos y confiabilidad a futuro:
- **PRODUCCIÓN (El Show):** Poblado con el historial limpio generado por el paralelo en `Planif_POSE`. Alimentará inmediatamente a la API y el Frontend para mostrar resultados tangibles a la Dirección.
- **DESARROLLO (Chaos Testing):** Poblado y gestionado netamente por el nuevo `Pose_DataPipeline` desde los crudos. Soportará pruebas de estrés, borrados, caídas y validaciones exhaustivas del mecanismo `UPSERT`.

**🔴 Misión Crítica:** `Planif_POSE` se convierte en un pilar indispensable para el negocio a corto plazo. Es MANDATORIO no escatimar en controles y pruebas de fiabilidad en la pre-ingesta de este repositorio. Si falla esta vía, impacta la base de Producción y la visualización de la Dirección.
