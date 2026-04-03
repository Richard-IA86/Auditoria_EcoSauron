# Estándar de Gobierno de Repositorios y Tareas
**Emisor:** Auditoría QA (El Ojo de Sauron)
**Fecha de vigencia:** 2026-04-02
**Última revisión:** 2026-04-03 — Sprint 8 (Tarea 0: refinamiento procedimiento de ramas)

Este documento establece las normativas inquebrantables de desarrollo unificado para todos los repositorios ecosistema POSE.

## 1. Gestión de Tareas (Tracking JSON)
Todo repositorio debe contar con un archivo maestro de estado: `config/estado_proyecto.json`.
Cualquier otro archivo (ej. `estado_implementacion.json`, `estado_tareas.json`) será considerado obsoleto.

### Estructura Obligatoria
```json
{
    "auditoria_qa": [
        "Tareas de corrección inyectadas por el pipeline de calidad (Tests, Mypy, Lints)."
    ],
    "desarrollo_local": [
        "Tareas funcionales, backlog de negocio y evolución del código introducidas por el desarrollador."
    ]
}
```
*   Nadie excepto QA puede modificar la llave `auditoria_qa`.
*   Nadie excepto QA evalúa el completado de la llave `auditoria_qa`.

## 2. Gestión de Ramas y Git QA Flow
### 2.1 Políticas de Bloqueo
*   **La rama `main` es sagrada inmutable.** Queda estrictamente prohibido el push directo a `main`.
*   Toda integración a `main` debe hacerse por Pull Request (PR) o Merge Request (MR).

### 2.2 Convención de Nombres de Ramas
Toda rama debe estar en minúsculas (snake_case) bajo la estructura `<tipo>/<descripcion_corta>`:
*   `feature/<descripcion>`: Nuevas características o implementaciones funcionales.
*   `hotfix/<descripcion>`: Correcciones urgentes de errores críticos en producción.
*   `qa/<descripcion>`: Ajustes de linter, type-hinting, seguridad o tests.
*   `chore/<descripcion>`: Tareas de mantenimiento sin impacto funcional (actualizar deps,
    configuración de herramientas, archivos de estado, hooks, `.gitignore`).

> **Regla de uso `chore/`:** Un cambio solo es `chore` si NO modifica lógica de negocio
> ni tests. Si conviven un fix técnico y un cambio administrativo, se crean dos commits
> separados dentro de la misma rama (ver sección 2.4).

### 2.3 Regla de Fusión (Los Pipeline Gates)
El "Merge" NO lo decide un humano por autoridad, lo decide el **Pipeline de QA**.
*   Si el escaneo de seguridad, el análisis estático (`black`, `flake8`, `mypy`) o los Tests unitarios (`pytest`) fallan, la solicitud es **denegada automáticamente**.
*   Una vez que el pipeline otorga la validación verde, el desarrollador principal aplica la fusión.
*   **Condición de rebase:** Ninguna rama será fusionable si no está alineada y actualizada con el último commit de `main`.

### 2.4 Separación de Commits por Naturaleza
Cada commit debe representar **una sola naturaleza de cambio**. Cuando una rama requiera
cambios de distinto tipo, se usará un commit por cada naturaleza:

| Prefijo Conventional Commits | Naturaleza |
|---|---|
| `fix:` | Corrección técnica (bug, hook, config rota) |
| `chore:` | Mantenimiento administrativo (estado JSON, .gitignore) |
| `feat:` | Nueva funcionalidad |
| `test:` | Tests unitarios |
| `docs:` | Documentación |
| `style:` | Formato sin cambio de lógica (black, isort) |

**Anti-patrón a evitar** (detectado jornada 2026-04-02 en Data-Analytics):
```
# MAL — mezcla fix técnico y actualización administrativa
git commit -m "feat: marcar tareas completadas y corregir hook mypy"

# BIEN — dos commits separados en la misma rama
git commit -m "fix(pre-commit): eliminar types-all incompatible con Python 3.13"
git commit -m "chore(estado): marcar tareas completadas + agregar próximo TP"
```

### 2.5 Flujo Completo Obligatorio al Cerrar Jornada
Si `main` está protegida, el siguiente flujo es **obligatorio** antes de cerrar:

```bash
# 1. Crear rama con tipo correcto
git checkout -b chore/descripcion-breve

# 2. Commits separados por naturaleza (ver 2.4)
git commit -m "fix: ..."
git commit -m "chore: ..."

# 3. Push de la rama
git push origin chore/descripcion-breve

# 4. Crear PR en GitHub (obligatorio — no dejar rama huérfana)
gh pr create --title "..." --body "..." --base main
```

**Rama sin PR = jornada incompleta.** El orquestador detectará ramas sin PR
como anomalía en futuras versiones del pipeline.
