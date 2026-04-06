#!/usr/bin/env bash
# =============================================================
# prepare_commit_msg_hook.sh
# Hook prepare-commit-msg: inserta identidad de máquina como
# trailer Git estándar en cada commit.
# Formato trailer: Workstation: <hostname> (<IP>)
# Instalado como .git/hooks/prepare-commit-msg en repos del
# ecosistema POSE.
# Rol: Agente Auditor Linux (El Ojo de Sauron)
# =============================================================
set -euo pipefail

COMMIT_MSG_FILE="$1"
COMMIT_TYPE="${2:-}"

# ------------------------------------------------------------------
# No modificar commits de merge ni squash automáticos
# ------------------------------------------------------------------
case "$COMMIT_TYPE" in
    merge|squash) exit 0 ;;
esac

# ------------------------------------------------------------------
# Obtener identidad de la máquina
# ------------------------------------------------------------------
HOST="$(hostname 2>/dev/null || echo "unknown")"
IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")"

# ------------------------------------------------------------------
# Agregar trailer solo si no existe ya (evita duplicados en --amend)
# ------------------------------------------------------------------
if ! grep -q "^Workstation:" "$COMMIT_MSG_FILE"; then
    printf "\nWorkstation: %s (%s)\n" "$HOST" "$IP" \
        >> "$COMMIT_MSG_FILE"
fi
