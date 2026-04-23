# Gemini — Tarea T6: nginx + certbot + SSL

**Contexto:** Proyecto POSE — `gestionpose.com.ar` en Hetzner CX33.
nginx actúa como reverse proxy hacia FastAPI (Docker :8000) y
Next.js (futuro :3000). SSL con Let's Encrypt. DNS en Cloudflare
modo Full strict.

**Tu rol:** Agente DevOps. Ejecutar estos pasos en el servidor Hetzner.

**Ejecutar en:** Hetzner CX33 — como root vía SSH

**Prerrequisito:** T4 ufw activo (puerto 80 y 443 abiertos al público)

**Bloquea a:** T15 (deploy Docker Pose_API necesita proxy activo)

---

## Variables — completar antes de ejecutar

```text
DOMINIO          = gestionpose.com.ar
EMAIL_CERTBOT    = Richard.r.ia86@gmail.com
IP_HETZNER_CX33  = <reemplazar con la IP pública del servidor>
```

---

## Paso 1: Confirmar puertos 80 y 443 en ufw

```bash
ufw allow 80/tcp comment 'HTTP nginx'
ufw allow 443/tcp comment 'HTTPS nginx'
ufw reload
ufw status
```

## Paso 2: Instalar nginx

```bash
apt update && apt install nginx -y
systemctl enable nginx
systemctl start nginx
curl -I http://localhost   # debe responder 200
```

## Paso 3: Crear configuración provisional (sin SSL)

Crear `/etc/nginx/sites-available/gestionpose`:

```nginx
server {
    listen 80;
    server_name gestionpose.com.ar www.gestionpose.com.ar;

    # Solo API por ahora — frontend se agrega en T21
    location /api/ {
        proxy_pass         http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    location / {
        return 200 'POSE API — OK';
        add_header Content-Type text/plain;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/gestionpose \
      /etc/nginx/sites-enabled/gestionpose
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
```

## Paso 4: Instalar certbot

```bash
apt install certbot python3-certbot-nginx -y
```

## Paso 5: Obtener certificado Let's Encrypt

**IMPORTANTE antes de ejecutar:** en Cloudflare → DNS → registro A
`gestionpose.com.ar` → cambiar a **modo "DNS only" (nube gris)**.
Volver a proxy (nube naranja) después de obtener el cert.

```bash
certbot --nginx \
  -d gestionpose.com.ar \
  -d www.gestionpose.com.ar \
  --email Richard.r.ia86@gmail.com \
  --agree-tos \
  --non-interactive
```

Certbot modifica automáticamente el bloque nginx con los paths SSL.

## Paso 6: Reactivar proxy Cloudflare

En Cloudflare → DNS → registros A → activar proxy (nube naranja) en
ambos registros (`gestionpose.com.ar` y `www.gestionpose.com.ar`).

## Paso 7: Mejorar config nginx post-certbot

Editar `/etc/nginx/sites-available/gestionpose` y agregar headers de
seguridad en el bloque `server { listen 443 ... }`:

```nginx
    # Headers de seguridad
    add_header X-Frame-Options        DENY;
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy        strict-origin-when-cross-origin;
```

```bash
nginx -t && systemctl reload nginx
```

## Paso 8: Verificar renovación automática

```bash
systemctl status certbot.timer
certbot renew --dry-run   # simular renovación sin ejecutar
```

---

## Verificación final

```bash
nginx -t
curl -I https://gestionpose.com.ar/
# Esperado: HTTP/2 200 con header Server: nginx
```

---

## Reportar a Copilot cuando esté completo

- [ ] `nginx -t` sin errores
- [ ] Cert obtenido en `/etc/letsencrypt/live/gestionpose.com.ar/`
- [ ] `curl -I https://gestionpose.com.ar` devuelve 200
- [ ] `certbot renew --dry-run` exitoso
- [ ] Cloudflare vuelto a modo proxy (nube naranja)
- [ ] Fecha de expiración del certificado (para monitoreo)
