#!/bin/bash
# FreshBox SpA - User Data EC2 MySQL (EP1)
# Instala MySQL Server 8.0 y carga el esquema/datos iniciales.
# Las credenciales se inyectan como variables (no hardcodeadas en código).
# El esquema se aplica desde un script descargado/via parámetro.

exec > /var/log/user-data-mysql.log 2>&1
set -x

dnf update -y

# Amazon Linux 2023: MySQL 8.0 vía el repo nativo 'mysql80-community'
dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
dnf install -y mysql-community-server

systemctl enable mysqld
systemctl start mysqld

# Obtener password temporal generado en el primer arranque
TEMP_PASS=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}' | tail -1)

# Configurar root y crear usuario/bd
mysql --connect-expired-password -uroot -p"$${TEMP_PASS}" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${db_root_pass}';
CREATE DATABASE IF NOT EXISTS ${db_name};
CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_pass}';
GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'%';
FLUSH PRIVILEGES;
SQL

# Aplicar esquema + datos (init.sql).
# NOTA: este script espera el archivo en una ubicación conocida. En el pipeline se
# sube vía SSM o se incluye en la AMI. Se deja un hook reemplazable.
if [ -f /opt/freshbox/init.sql ]; then
  mysql -u"${db_user}" -p"${db_pass}" ${db_name} < /opt/freshbox/init.sql
  echo "Esquema y datos iniciales aplicados."
else
  echo "AVISO: /opt/freshbox/init.sql no presente. Crear el esquema manualmente."
fi

echo "=== User Data MySQL completado ==="
