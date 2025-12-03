#!/usr/bin/env bash
# /Yeorz/HomeLabScripts/zabbix_lxc_setup.sh
# Sets up Zabbix server + MariaDB + nginx + php-fpm in a Debian/Ubuntu LXC.
# Non-interactive friendly but prompts for FQDN and optional passwords/timezone.
set -euo pipefail

# Basic helpers
die(){ echo "ERROR: $*" >&2; exit 1; }
random_pw(){ openssl rand -base64 16 2>/dev/null || head -c 16 /dev/urandom | base64; }

if [ "$(id -u)" -ne 0 ]; then
    die "This script must be run as root."
fi

echo "This script will install Zabbix (server + frontend) with MariaDB, nginx and php-fpm."
read -r -p "FQDN for Zabbix web UI (e.g. zabbix.example.com) [$(hostname -f 2>/dev/null || hostname)]: " ZBX_FQDN
ZBX_FQDN=${ZBX_FQDN:-$(hostname -f 2>/dev/null || hostname)}

read -r -p "MariaDB root password (leave empty to auto-generate): " MYSQL_ROOT_PWD
if [ -z "$MYSQL_ROOT_PWD" ]; then MYSQL_ROOT_PWD="$(random_pw)"; fi

read -r -p "Zabbix DB user password (leave empty to auto-generate): " ZBX_DB_PWD
if [ -z "$ZBX_DB_PWD" ]; then ZBX_DB_PWD="$(random_pw)"; fi

read -r -p "Time zone for PHP (e.g. UTC, Europe/Berlin) [UTC]: " PHP_TZ
PHP_TZ=${PHP_TZ:-UTC}

# Detect OS
if command -v lsb_release >/dev/null 2>&1; then
    DIST_ID=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    CODENAME=$(lsb_release -sc)
else
    . /etc/os-release
    DIST_ID=${ID:-debian}
    CODENAME=${VERSION_CODENAME:-$(awk -F= '/VERSION_CODENAME/{print $2}' /etc/os-release || echo "buster")}
fi

ZBX_VER="6.0"
echo "Detected: ${DIST_ID} ${CODENAME}. Using Zabbix ${ZBX_VER} repo."

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y gnupg wget lsb-release ca-certificates apt-transport-https software-properties-common

# Add Zabbix repository package
ZBX_REPO_PKG="zabbix-release_${ZBX_VER}-1+${DIST_ID}${CODENAME}_all.deb"
ZBX_REPO_URL="https://repo.zabbix.com/zabbix/${ZBX_VER}/${DIST_ID}/pool/main/z/zabbix-release/${ZBX_REPO_PKG}"
# Fallback: try debian naming if ubuntu fails
if ! wget -q --spider "$ZBX_REPO_URL"; then
    # try Debian-style codename (some Ubuntu hosts use ubuntuXX names). Try direct codename insertion
    ZBX_REPO_PKG="zabbix-release_${ZBX_VER}-1+debian${CODENAME}_all.deb"
    ZBX_REPO_URL="https://repo.zabbix.com/zabbix/${ZBX_VER}/debian/pool/main/z/zabbix-release/${ZBX_REPO_PKG}"
fi

echo "Downloading Zabbix repo package from: $ZBX_REPO_URL"
wget -qO /tmp/zbxrepo.deb "$ZBX_REPO_URL"
dpkg -i /tmp/zbxrepo.deb || apt-get -f install -y
rm -f /tmp/zbxrepo.deb

apt-get update

# Install MariaDB server
apt-get install -y mariadb-server mariadb-client

# Secure MariaDB: set root password and remove test/anonymous
# We assume we can run mysql as root via unix_socket initially.
MYSQL_CMD() {
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        mysql -u root -e "$1"
    else
        mysql -u root -p"${MYSQL_ROOT_PWD}" -e "$1"
    fi
}

# If running as unix_socket-enabled root, set the password
if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
    echo "Setting MariaDB root password and securing server..."
    mysql -u root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PWD}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL
else
    # If root access with password already required, attempt with provided password to ensure it's usable
    if ! mysql -u root -p"${MYSQL_ROOT_PWD}" -e "SELECT 1;" >/dev/null 2>&1; then
        die "Cannot access MariaDB as root. Please ensure MariaDB is in a clean state or run script with proper privileges."
    fi
fi

# Create Zabbix DB and user
ZBX_DB_NAME="zabbix"
ZBX_DB_USER="zabbix"

echo "Creating Zabbix database and user..."
mysql -u root -p"${MYSQL_ROOT_PWD}" <<SQL
CREATE DATABASE IF NOT EXISTS ${ZBX_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS '${ZBX_DB_USER}'@'localhost' IDENTIFIED BY '${ZBX_DB_PWD}';
GRANT ALL PRIVILEGES ON ${ZBX_DB_NAME}.* TO '${ZBX_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

# Install Zabbix server, frontend, nginx, php-fpm and required PHP extensions
# Pick packages available in repo
apt-get install -y zabbix-server-mysql zabbix-frontend-php zabbix-agent nginx php-fpm php-mysql php-xml php-gd php-bcmath php-ldap php-mbstring php-xmlrpc php-json

# Import initial schema
echo "Importing initial Zabbix schema into database (this may take a while)..."
# find the SQL gz file
SQL_GZ=$(dpkg -L zabbix-sql-scripts 2>/dev/null | grep -E 'mysql.*server.sql.gz$' | head -n1 || true)
if [ -z "$SQL_GZ" ]; then
    # location when package not present: /usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz
    SQL_GZ="/usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz"
fi

if [ -f "$SQL_GZ" ]; then
    zcat "$SQL_GZ" | mysql -u "${ZBX_DB_USER}" -p"${ZBX_DB_PWD}" "${ZBX_DB_NAME}"
else
    die "Zabbix SQL schema file not found. Ensure zabbix-sql-scripts is installed."
fi

# Configure zabbix_server.conf to use DB credentials
ZCONF="/etc/zabbix/zabbix_server.conf"
sed -i "s/^# DBPassword=.*/DBPassword=${ZBX_DB_PWD}/" "$ZCONF" || echo "DBPassword=${ZBX_DB_PWD}" >> "$ZCONF"

# Configure PHP timezone
PHP_INI_FILE=$(find /etc/php -type f -path "*/fpm/php.ini" | head -n1)
if [ -z "$PHP_INI_FILE" ]; then
    die "php-fpm ini not found."
fi
sed -i "s@^;*date.timezone.*@date.timezone = ${PHP_TZ}@" "$PHP_INI_FILE"

# Setup nginx config for Zabbix
NGINX_CONF="/etc/nginx/sites-available/zabbix"
# find php-fpm socket
PHP_SOCK=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n1 || true)
if [ -z "$PHP_SOCK" ]; then
    # fallback to tcp
    PHP_SOCK="127.0.0.1:9000"
fi

cat > "$NGINX_CONF" <<EOF
server {
        listen 80;
        server_name ${ZBX_FQDN};

        root /usr/share/zabbix;
        index index.php index.html index.htm;

        access_log /var/log/nginx/zabbix.access.log;
        error_log  /var/log/nginx/zabbix.error.log;

        location / {
                try_files \$uri \$uri/ =404;
        }

        location ~ \.php\$ {
                fastcgi_split_path_info ^(.+\.php)(/.+)\$;
                fastcgi_index index.php;
                include fastcgi_params;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                fastcgi_param ZBX_SERVER_NAME ${ZBX_FQDN};
                fastcgi_pass unix:${PHP_SOCK};
                fastcgi_buffers 16 16k;
                fastcgi_buffer_size 32k;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
                access_log off;
                expires 7d;
        }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/zabbix
# Disable default site if present
if [ -f /etc/nginx/sites-enabled/default ]; then
    rm -f /etc/nginx/sites-enabled/default
fi

# Ensure permissions
chown -R www-data:www-data /usr/share/zabbix || true

# Enable and restart services
systemctl enable --now mariadb
systemctl enable --now zabbix-server
systemctl enable --now php*-fpm 2>/dev/null || true
# restart available php-fpm service(s)
for s in $(systemctl list-units --type=service --all | awk '{print $1}' | grep php | grep fpm || true); do
    systemctl restart "$s" || true
done
systemctl restart zabbix-server || true
systemctl restart nginx || true
systemctl enable --now nginx

# Final output
cat <<SUMMARY

Zabbix installation complete.

Web UI:
    http://$ZBX_FQDN/

Zabbix DB:
    DB name: ${ZBX_DB_NAME}
    DB user: ${ZBX_DB_USER}
    DB password: ${ZBX_DB_PWD}

MariaDB root password:
    ${MYSQL_ROOT_PWD}

PHP timezone set to: ${PHP_TZ}

Notes:
 - If the FQDN resolves to this container, open the URL in your browser.
 - For production use obtain TLS certificates (Let's Encrypt / certbot) and configure HTTPS for nginx.
 - Default Zabbix frontend login: Admin / zabbix

SUMMARY
exit 0