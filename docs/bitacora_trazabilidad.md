# Bitácora de Trazabilidad — EcoSauron

**Proyecto:** Auditoria_EcoSauron
**Rol:** Agente Auditor Linux (El Ojo de Sauron)
**Plantilla versión:** 1.0

---

## Instrucciones de Uso

Registra cada ejecución del pipeline en esta bitácora.
Copia el bloque de entrada de plantilla para cada evento.
Los logs detallados se encuentran en `logs/`.

---

## Registro de Ejecuciones

### Plantilla de Entrada

```
---
**Fecha y hora:** YYYY-MM-DD HH:MM:SS
**Ejecutado por:** <usuario>@<hostname>
**Script ejecutado:** scripts/<nombre>.sh
**Workspaces auditados:**
  - repo_1
  - repo_2
**Resultado general:** ✅ APROBADO / ❌ FALLIDO
**Pasos:**
| Etapa             | Estado         |
|-------------------|----------------|
| Clonación         | ✅ / ❌        |
| Pre-commit Hooks  | ✅ / ❌        |
| Dependencias      | ✅ / ❌        |
| Análisis Estático | ✅ / ❌        |
**Anomalías detectadas:**
  - (Descripción de la anomalía, archivo, línea)
**Acciones tomadas:**
  - (Acción correctiva o escalada)
**Log referenciado:**
  `logs/auditoria_YYYYMMDD_HHMMSS.log`
---
```

---

## Historial

<!-- Inserta nuevas entradas debajo de esta línea -->

---

*Bitácora mantenida por el Agente Auditor Linux.*
*Toda anomalía sin registrar es un vector de riesgo.*
