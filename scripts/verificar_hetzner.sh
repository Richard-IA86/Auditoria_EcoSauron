#!/usr/bin/env bash
# verificar_hetzner.sh — diagnóstico de solo lectura del servidor Hetzner CX33
# Uso: bash scripts/verificar_hetzner.sh [IP]
# Sin argumento usa el valor por defecto.
# No ejecuta ningún cambio en el servidor.

set -euo pipefail

SERVER_IP="${1:-178.104.226.136}"
SSH_USER="root"
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
NEGRITA='\033[1m'
RESET='\033[0m'

ok()   { echo -e "  ${VERDE}✔${RESET}  $*"; }
warn() { echo -e "  ${AMARILLO}⚠${RESET}  $*"; }
fail() { echo -e "  ${ROJO}✘${RESET}  $*"; }
sep()  { echo -e "${NEGRITA}──────────────────────────────────────────${RESET}"; }

echo ""
echo -e "${NEGRITA}VERIFICACIÓN HETZNER CX33 — ${SERVER_IP}${RESET}"
sep

# ── 1. Conectividad SSH ─────────────────────────────────────────────────────
echo -e "\n${NEGRITA}[1] Conectividad SSH${RESET}"
if ssh $SSH_OPTS "${SSH_USER}@${SERVER_IP}" "exit 0" 2>/dev/null; then
    ok "SSH responde — autenticación por clave OK"
else
    fail "No se puede conectar vía SSH a ${SERVER_IP}"
    echo "    Verificar: clave cargada en ssh-agent, IP correcta, servidor activo."
    exit 1
fi

# ── Bloque remoto — un solo SSH para minimizar conexiones ───────────────────
echo -e "\n${NEGRITA}[2–8] Estado del servidor (lectura remota)${RESET}"
sep

ssh $SSH_OPTS "${SSH_USER}@${SERVER_IP}" bash << 'REMOTE'
VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
NEGRITA='\033[1m'
RESET='\033[0m'

ok()      { echo -e "  ${VERDE}✔${RESET}  $*"; }
warn()    { echo -e "  ${AMARILLO}⚠${RESET}  $*"; }
fail()    { echo -e "  ${ROJO}✘${RESET}  $*"; }
sep()     { echo -e "${NEGRITA}──────────────────────────────────────────${RESET}"; }
head_sec(){ echo -e "\n${NEGRITA}[$1] $2${RESET}"; }

# ── 2. Sistema operativo ────────────────────────────────────────────────────
head_sec 2 "Sistema operativo"
OS_NAME=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null || uptime)
ok "OS:     ${OS_NAME}"
ok "Kernel: ${KERNEL}"
ok "Uptime: ${UPTIME}"

# ── 3. Recursos (disco / RAM) ────────────────────────────────────────────────
head_sec 3 "Recursos"
DISK=$(df -h / | awk 'NR==2 {print $3 " usados / " $2 " total (" $5 " uso)"}')
RAM=$(free -h | awk '/^Mem:/{print $3 " usados / " $2 " total"}')
ok "Disco: ${DISK}"
ok "RAM:   ${RAM}"

# ── 4. Firewall (ufw) ────────────────────────────────────────────────────────
head_sec 4 "Firewall (ufw)"
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    ok "ufw instalado — ${UFW_STATUS}"
    ufw status numbered 2>/dev/null | grep -E "^\[" | while read -r line; do
        echo "     ${line}"
    done
else
    warn "ufw NO está instalado (T4 pendiente)"
fi

# ── 5. WireGuard ────────────────────────────────────────────────────────────
head_sec 5 "WireGuard"
if command -v wg &>/dev/null; then
    WG_VER=$(wg --version 2>/dev/null)
    ok "WireGuard instalado — ${WG_VER}"
    IFACE_COUNT=$(wg show interfaces 2>/dev/null | wc -w)
    if [ "${IFACE_COUNT}" -gt 0 ]; then
        ok "Interfaces activas: $(wg show interfaces 2>/dev/null)"
    else
        warn "WireGuard instalado pero sin interfaces activas (T5 pendiente)"
    fi
else
    warn "WireGuard NO instalado (T5 pendiente)"
fi

# ── 6. nginx ────────────────────────────────────────────────────────────────
head_sec 6 "nginx"
if command -v nginx &>/dev/null; then
    NGINX_VER=$(nginx -v 2>&1 | head -1)
    ok "nginx instalado — ${NGINX_VER}"
    if systemctl is-active --quiet nginx 2>/dev/null; then
        ok "nginx servicio: ACTIVO"
    else
        warn "nginx instalado pero servicio INACTIVO"
    fi
else
    warn "nginx NO instalado (T6 pendiente)"
fi

# ── 7. certbot ──────────────────────────────────────────────────────────────
head_sec 7 "certbot (Let's Encrypt)"
if command -v certbot &>/dev/null; then
    CERTBOT_VER=$(certbot --version 2>&1)
    ok "certbot instalado — ${CERTBOT_VER}"
    CERT_COUNT=$(certbot certificates 2>/dev/null | grep -c "Certificate Name" || true)
    ok "Certificados gestionados: ${CERT_COUNT}"
else
    warn "certbot NO instalado (T6 pendiente)"
fi

# ── 8. PostgreSQL ────────────────────────────────────────────────────────────
head_sec 8 "PostgreSQL"
if command -v psql &>/dev/null; then
    PG_VER=$(psql --version 2>/dev/null)
    ok "PostgreSQL instalado — ${PG_VER}"
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        ok "Servicio postgresql: ACTIVO"
        DB_LIST=$(psql -U postgres -lqt 2>/dev/null \
            | cut -d'|' -f1 \
            | grep -v '^\s*$' \
            | tr '\n' ' ' || echo "(sin acceso directo)")
        ok "Bases de datos: ${DB_LIST}"
    else
        warn "PostgreSQL instalado pero servicio INACTIVO"
    fi
else
    warn "PostgreSQL NO instalado (T7 pendiente)"
fi

# ── 9. Python3 / pip ────────────────────────────────────────────────────────
head_sec 9 "Python3"
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version 2>/dev/null)
    ok "python3: ${PY_VER}"
else
    warn "python3 no encontrado"
fi
if command -v pip3 &>/dev/null; then
    PIP_VER=$(pip3 --version 2>/dev/null | cut -d' ' -f1-2)
    ok "pip3: ${PIP_VER}"
else
    warn "pip3 no encontrado"
fi

# ── 10. Resumen ──────────────────────────────────────────────────────────────
echo ""
echo -e "${NEGRITA}══════════════════════════════════════════${RESET}"
echo -e "${NEGRITA}RESUMEN — Tareas pendientes detectadas${RESET}"
echo -e "${NEGRITA}══════════════════════════════════════════${RESET}"

pendientes=0

chk() {
    local cmd="$1"; local label="$2"
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "  ${ROJO}✘${RESET}  ${label}"
        pendientes=$((pendientes+1))
    fi
}

chk ufw      "T4 — ufw firewall"
chk wg       "T5 — WireGuard"
chk nginx    "T6 — nginx"
chk certbot  "T6 — certbot"
chk psql     "T7 — PostgreSQL 16"

if [ "$pendientes" -eq 0 ]; then
    echo -e "  ${VERDE}✔${RESET}  Todo instalado — verificar configuración de cada componente"
else
    echo ""
    echo -e "  ${AMARILLO}${pendientes} tarea(s) de instalación pendientes${RESET}"
fi
echo ""
REMOTE

echo ""
sep
echo -e "${NEGRITA}Verificación completa — ningún cambio ejecutado en el servidor.${RESET}"
echo ""
