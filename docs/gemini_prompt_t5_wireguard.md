# Gemini — Tarea T5: WireGuard VPN

**Contexto:** Proyecto POSE — sistema web en Hetzner CX33 (Ubuntu 24.04 LTS).
El ETL Python corre en Asus Windows y necesita llegar a PostgreSQL
en el servidor por red privada. El admin también se conecta por SSH seguro.

**Tu rol:** Agente DevOps. Ejecutar estos pasos en el servidor Hetzner.

**Ejecutar en:** Hetzner CX33 — como root vía SSH

**Prerrequisito:** T4 completado (ufw activo con puerto 22 abierto)

**Bloquea a:** T9 (ETL conecta a PostgreSQL por esta VPN)

---

## Variables — completar antes de ejecutar

```text
IP_HETZNER_CX33  = <reemplazar con la IP pública del servidor>
PUBLIC_KEY_M1    = <clave pública del iMac — ver Fase 1>
PUBLIC_KEY_M2    = <clave pública del Asus Windows — ver Fase 1>
PUBLIC_KEY_M2B   = <clave pública del equipo backup — ver Fase 1>
```

Subnet WireGuard definida: `10.10.0.0/24`

| Máquina | IP VPN |
|---------|--------|
| Servidor CX33 | 10.10.0.1 |
| M1 iMac | 10.10.0.2 |
| M2 Asus Windows | 10.10.0.3 |
| M2b equipo backup | 10.10.0.4 |

---

## Fase 1 — Generar claves en cada máquina cliente

**Hacer ANTES de tocar el servidor. El usuario ejecuta en sus máquinas
y te reporta las 3 claves públicas.**

### M1 — iMac (Linux)

```bash
wg genkey | tee /etc/wireguard/wg_private.key \
  | wg pubkey > /etc/wireguard/wg_public.key
chmod 600 /etc/wireguard/wg_private.key
cat /etc/wireguard/wg_public.key   # <- reportar este valor
```

### M2 — Asus Windows y M2b — equipo backup (Windows)

1. Instalar WireGuard para Windows: <https://www.wireguard.com/install/>
2. Abrir WireGuard → "Add Tunnel" → "Add empty tunnel"
3. Copiar la **Public Key** que aparece en pantalla → reportar ese valor
4. Guardar el túnel (NO activar aún — falta la config del peer servidor)

**Esperar las 3 claves públicas antes de continuar con Fase 2.**

---

## Fase 2 — Configurar servidor

### Paso 1: Instalar WireGuard

```bash
apt update && apt install wireguard -y
```

### Paso 2: Generar clave del servidor

```bash
wg genkey | tee /etc/wireguard/server_private.key \
  | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key
echo "=== CLAVE PÚBLICA DEL SERVIDOR (reportar al usuario) ==="
cat /etc/wireguard/server_public.key
```

### Paso 3: Crear /etc/wireguard/wg0.conf

Reemplazar `<SERVER_PRIVATE_KEY>` con el contenido de
`/etc/wireguard/server_private.key` y las claves de los peers:

```ini
[Interface]
Address    = 10.10.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

# M1 — iMac (admin SSH + consultas)
[Peer]
PublicKey  = <PUBLIC_KEY_M1>
AllowedIPs = 10.10.0.2/32

# M2 — Asus Windows (ETL psycopg2 + admin SSH)
[Peer]
PublicKey  = <PUBLIC_KEY_M2>
AllowedIPs = 10.10.0.3/32

# M2b — equipo backup (solo ETL :5432, sin SSH al servidor)
[Peer]
PublicKey  = <PUBLIC_KEY_M2B>
AllowedIPs = 10.10.0.4/32
```

```bash
chmod 600 /etc/wireguard/wg0.conf
```

### Paso 4: Habilitar IP forwarding

```bash
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

### Paso 5: Abrir puerto WireGuard en ufw

```bash
ufw allow 51820/udp comment 'WireGuard VPN'
ufw reload
```

### Paso 6: Iniciar y habilitar el servicio

```bash
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
systemctl status wg-quick@wg0
wg show   # debe mostrar los 3 peers configurados
```

---

## Fase 3 — Configurar clientes (usuario ejecuta en sus máquinas)

### M1 — iMac: /etc/wireguard/wg0.conf

```ini
[Interface]
Address    = 10.10.0.2/32
PrivateKey = <contenido de /etc/wireguard/wg_private.key>
DNS        = 1.1.1.1

[Peer]
PublicKey           = <PUBLIC_KEY_SERVIDOR>
Endpoint            = <IP_HETZNER_CX33>:51820
AllowedIPs          = 10.10.0.0/24
PersistentKeepalive = 25
```

```bash
systemctl enable wg-quick@wg0 && systemctl start wg-quick@wg0
ping 10.10.0.1   # debe responder
```

### M2 — Asus Windows (en la app WireGuard)

```ini
[Interface]
Address    = 10.10.0.3/32
PrivateKey = <generada por la app>
DNS        = 1.1.1.1

[Peer]
PublicKey           = <PUBLIC_KEY_SERVIDOR>
Endpoint            = <IP_HETZNER_CX33>:51820
AllowedIPs          = 10.10.0.0/24
PersistentKeepalive = 25
```

### M2b — equipo backup (en la app WireGuard)

```ini
[Interface]
Address    = 10.10.0.4/32
PrivateKey = <generada por la app>
DNS        = 1.1.1.1

[Peer]
PublicKey           = <PUBLIC_KEY_SERVIDOR>
Endpoint            = <IP_HETZNER_CX33>:51820
AllowedIPs          = 10.10.0.0/24
PersistentKeepalive = 25
```

---

## Verificación final

```bash
# Desde M1 o M2 con VPN activa:
ping 10.10.0.1           # servidor responde
ssh root@10.10.0.1       # acceso SSH por VPN OK
```

---

## Reportar a Copilot cuando esté completo

- [ ] `wg show` en servidor muestra los 3 peers
- [ ] M1 hace `ping 10.10.0.1` con respuesta
- [ ] M2 hace `ping 10.10.0.1` con respuesta
- [ ] Clave pública del servidor (para documentar en sprint17)
- [ ] IPs asignadas confirmadas (10.10.0.1 a 10.10.0.4)
