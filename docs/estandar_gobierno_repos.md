# Estándar de Gobierno de Repositorios y Tareas
**Emisor:** Auditoría QA (El Ojo de Sauron)
**Fecha de vigencia:** 2026-04-02

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

### 2.3 Regla de Fusión (Los Pipeline Gates)
El "Merge" NO lo decide un humano por autoridad, lo decide el **Pipeline de QA**.
*   Si el escaneo de seguridad, el análisis estático (`black`, `flake8`, `mypy`) o los Tests unitarios (`pytest`) fallan, la solicitud es **denegada automáticamente**.
*   Una vez que el pipeline otorga la validación verde, el desarrollador principal aplica la fusión.
*   **Condición de rebase:** Ninguna rama será fusionable si no está alineada y actualizada con el último commit de `main`.
