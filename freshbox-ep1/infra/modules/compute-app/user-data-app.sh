#!/bin/bash
# FreshBox SpA - User Data EC2 APP (EP1)
# Instala Docker + Compose y deja la instancia lista para el deploy vía SSM.
# Las credenciales de BD se inyectan como variables de entorno (no hardcodeadas).

exec > /var/log/user-data.log 2>&1
set -x

yum update -y
yum install -y docker awscli

systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-aarch64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

yum install -y telnet mysql jq

# Credenciales de BD desde parámetros/entorno (no hardcodeadas en código de la app)
mkdir -p /opt/freshbox
cat > /opt/freshbox/.env <<EOF
DB_HOST=${db_host}
DB_USER=${db_user}
DB_PASS=${db_pass}
DB_NAME=${db_name}
REGION=${region}
ACCOUNT_ID=${account_id}
PROJECT=${project}
EOF
chmod 600 /opt/freshbox/.env

# Directorios de trabajo del deploy
env | grep -q EC2 && true
echo "=== User Data APP completado ==="
