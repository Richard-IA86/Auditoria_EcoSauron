# Gemini — Tarea T7 + T7b: PostgreSQL 16 + Docker

**Contexto:** Proyecto POSE — Hetzner CX33. PostgreSQL 16 corre
directamente en host (NO en Docker — los datos viven fuera de
contenedores por seguridad y simplicidad de backup). Docker se
instala para correr la imagen de la API FastAPI.

**Tu rol:** Agente DevOps. Ejecutar estos pasos en el servidor Hetzner.

**Ejecutar en:** Hetzner CX33 — como root vía SSH

**Prerrequisito:** T5 WireGuard activo (el ETL conecta por 10.10.0.1)

**Bloquea a:**

- T8 (migración de datos requiere PostgreSQL activo)
- T9 (ETL Python requiere conexión psycopg2 a PostgreSQL)
- T15 (deploy Docker de la API)

---

## Variables — completar antes de ejecutar

```text
DB_PASSWORD_POSE_APP  = <contraseña segura para usuario pose_app>
DB_PASSWORD_BACKUP    = <contraseña para usuario pose_backup (solo lectura)>
```

Guardar ambas contraseñas en un gestor seguro — se usarán como
GitHub Secrets en T15 y en los archivos de config del ETL.

---

## PARTE A — PostgreSQL 16

### Paso 1: Instalar PostgreSQL 16

```bash
apt install -y postgresql-common
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
apt install -y postgresql-16
systemctl enable postgresql
systemctl start postgresql
systemctl status postgresql
```

### Paso 2: Verificar instalación

```bash
sudo -u postgres psql -c "SELECT version();"
# Esperado: PostgreSQL 16.x
```

### Paso 3: Crear usuario y base de datos de la aplicación

```bash
sudo -u postgres psql << 'EOF'
-- Usuario principal de la API
CREATE USER pose_app
  WITH PASSWORD '<DB_PASSWORD_POSE_APP>'
  LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Usuario de solo lectura para backups y monitoreo
CREATE USER pose_backup
  WITH PASSWORD '<DB_PASSWORD_BACKUP>'
  LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Base de datos principal
CREATE DATABASE pose_db
  OWNER pose_app
  ENCODING 'UTF8'
  LC_COLLATE 'es_AR.UTF-8'
  LC_CTYPE 'es_AR.UTF-8'
  TEMPLATE template0;

-- Esquemas base
\c pose_db
CREATE SCHEMA IF NOT EXISTS catalogos AUTHORIZATION pose_app;
CREATE SCHEMA IF NOT EXISTS datos AUTHORIZATION pose_app;
CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION pose_app;
CREATE SCHEMA IF NOT EXISTS etl AUTHORIZATION pose_app;

-- Permisos usuario backup
GRANT CONNECT ON DATABASE pose_db TO pose_backup;
GRANT USAGE ON SCHEMA catalogos, datos, auth, etl TO pose_backup;
GRANT SELECT ON ALL TABLES IN SCHEMA
  catalogos, datos, auth, etl TO pose_backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA catalogos, datos, auth, etl
  GRANT SELECT ON TABLES TO pose_backup;

\q
EOF
```

### Paso 4: Configurar acceso de red en PostgreSQL

Editar `/etc/postgresql/16/main/postgresql.conf`:

```bash
# Escuchar en la IP de la VPN WireGuard además de localhost
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '127.0.0.1,10.10.0.1'/" \
  /etc/postgresql/16/main/postgresql.conf
```

Editar `/etc/postgresql/16/main/pg_hba.conf` — agregar al final:

```bash
cat >> /etc/postgresql/16/main/pg_hba.conf << 'EOF'

# Conexiones desde VPN WireGuard — ETL Python
host  pose_db  pose_app     10.10.0.0/24  scram-sha-256
host  pose_db  pose_backup  10.10.0.0/24  scram-sha-256
EOF
```

```bash
systemctl restart postgresql
```

### Paso 5: Abrir puerto 5432 en ufw SOLO para la VPN

```bash
ufw allow from 10.10.0.0/24 to any port 5432 \
  comment 'PostgreSQL — solo VPN WireGuard'
ufw reload
ufw status
```

### Paso 6: Probar conexión desde el servidor

```bash
psql -U pose_app -h 127.0.0.1 -d pose_db -c "\dn"
# Debe mostrar: catalogos, datos, auth, etl
```

### Paso 7: Crear directorio de backups

```bash
mkdir -p /backups/snapshots /backups/diarios
chown postgres:postgres /backups/snapshots /backups/diarios
chmod 750 /backups/snapshots /backups/diarios
```

---

## PARTE B — Docker y docker-compose

### Paso 1: Instalar Docker Engine

```bash
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null

apt update && apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list

apt update && apt install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker
docker --version
docker compose version
```

### Paso 2: Crear red Docker para la API

```bash
docker network create pose_network
```

### Paso 3: Crear directorio de deploy

```bash
mkdir -p /opt/pose_api
chown root:docker /opt/pose_api
chmod 750 /opt/pose_api
```

---

## Verificación final

```bash
# PostgreSQL
sudo -u postgres psql -c "SELECT datname FROM pg_database;"
psql -U pose_app -h 10.10.0.1 -d pose_db -c "\dn"
# (ejecutar desde M2 con WireGuard activo — verifica conectividad VPN)

# Docker
docker info
docker network ls | grep pose_network
```

---

## Reportar a Copilot cuando esté completo

- [ ] PostgreSQL 16 activo: `systemctl status postgresql` = active
- [ ] Base de datos `pose_db` creada con 4 esquemas
- [ ] Usuario `pose_app` puede conectar desde 10.10.0.x
- [ ] Directorio `/backups/snapshots` creado con permisos correctos
- [ ] Docker Engine instalado: `docker --version`
- [ ] `docker network ls` muestra `pose_network`
- [ ] Puerto 5432 solo visible desde la VPN (ufw status confirmado)
