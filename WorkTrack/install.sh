#!/usr/bin/env bash
# ============================================================
#  WorkTrack — Server Installation Script
#  Supports: Ubuntu 20/22/24, Debian 11/12, Alpine 3.17+,
#            Rocky Linux 8/9, AlmaLinux 8/9
# ============================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

header()  { echo -e "\n${BOLD}${CYAN}$*${NC}"; }
info()    { echo -e "  ${BLUE}→${NC} $*"; }
ok()      { echo -e "  ${GREEN}✓${NC} $*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $*"; }
die()     { echo -e "\n${RED}✗ ERROR:${NC} $*\n" >&2; exit 1; }
ask()     {                                       # ask VAR "prompt" "default"
    local -n _ref=$1
    local _prompt=$2 _default=${3:-}
    if [[ -n $_default ]]; then
        read -rp "  $( echo -e "${BOLD}$_prompt${NC} [${_default}]: ")" _ref
        _ref=${_ref:-$_default}
    else
        read -rp "  $( echo -e "${BOLD}$_prompt${NC}: ")" _ref
    fi
}
ask_secret() {                                    # ask_secret VAR "prompt"
    local -n _ref=$1
    read -rsp "  $( echo -e "${BOLD}$2${NC} (hidden): ")" _ref
    echo
}
gen_hex()  { php -r "echo bin2hex(random_bytes(32));" 2>/dev/null || \
             openssl rand -hex 32; }

# ── Root check ────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root:  sudo bash install.sh"

# ── OS detection ──────────────────────────────────────────────
OS_ID=""; OS_VER=""; PKG_MGR=""

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS_ID="${ID,,}"
        OS_VER="${VERSION_ID:-}"
    elif [[ -f /etc/alpine-release ]]; then
        OS_ID="alpine"
        OS_VER=$(cat /etc/alpine-release)
    else
        die "Cannot detect OS. Supported: Ubuntu, Debian, Alpine, Rocky, AlmaLinux."
    fi

    case "$OS_ID" in
        ubuntu|debian)            PKG_MGR="apt" ;;
        alpine)                   PKG_MGR="apk" ;;
        rocky|almalinux|centos)   PKG_MGR="dnf" ;;
        *) die "Unsupported OS: $OS_ID. PRs welcome." ;;
    esac
    ok "Detected OS: ${OS_ID} ${OS_VER} (package manager: ${PKG_MGR})"
}

# ── PHP version picker ────────────────────────────────────────
PHP_VER="8.2"   # preferred; installer falls back to 8.1 if needed
PHP_BIN=""

pick_php_binary() {
    for v in 8.3 8.2 8.1; do
        if command -v "php${v}" &>/dev/null; then PHP_BIN="php${v}"; PHP_VER="$v"; return; fi
        if command -v php &>/dev/null; then
            local pv; pv=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
            if [[ "$pv" == 8.1 || "$pv" == 8.2 || "$pv" == 8.3 ]]; then
                PHP_BIN="php"; PHP_VER="$pv"; return
            fi
        fi
    done
    PHP_BIN=""
}

# ── Package installation ──────────────────────────────────────
WEBSERVER="apache"   # will be set by user prompt

install_apt() {
    header "Installing packages (apt)"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq

    # Ensure we have a PHP 8.x source
    local php_available
    php_available=$(apt-cache show "php${PHP_VER}" 2>/dev/null | grep -c "^Package:" || true)
    if [[ "$php_available" -eq 0 ]]; then
        info "PHP ${PHP_VER} not in default repos — adding Ondrej/Sury repository…"
        apt-get install -y -qq ca-certificates apt-transport-https lsb-release gnupg curl
        if [[ "$OS_ID" == "ubuntu" ]]; then
            add-apt-repository -y "ppa:ondrej/php" >/dev/null
        else
            curl -sSL https://packages.sury.org/php/apt.gpg \
                | gpg --dearmor -o /etc/apt/trusted.gpg.d/php-sury.gpg
            echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" \
                > /etc/apt/sources.list.d/php.list
        fi
        apt-get update -qq
    fi

    local PHP_P="php${PHP_VER}"
    local PHP_PKGS=(
        "${PHP_P}" "${PHP_P}-cli" "${PHP_P}-fpm"
        "${PHP_P}-mysql" "${PHP_P}-mbstring" "${PHP_P}-xml"
        "${PHP_P}-curl" "${PHP_P}-opcache" "${PHP_P}-intl"
    )
    local BASE_PKGS=(curl git unzip mariadb-server mariadb-client)

    if [[ "$WEBSERVER" == "nginx" ]]; then
        BASE_PKGS+=(nginx)
    else
        BASE_PKGS+=(apache2 libapache2-mod-php"${PHP_VER}")
    fi

    apt-get install -y -qq "${BASE_PKGS[@]}" "${PHP_PKGS[@]}"
    ok "APT packages installed"
}

install_apk() {
    header "Installing packages (apk)"
    apk update -q
    local PHP_P="php${PHP_VER/./}"   # e.g. php82
    local PKGS=(
        "${PHP_P}" "${PHP_P}-fpm" "${PHP_P}-pdo_mysql"
        "${PHP_P}-mbstring" "${PHP_P}-openssl" "${PHP_P}-json"
        "${PHP_P}-session" "${PHP_P}-ctype" "${PHP_P}-opcache"
        mariadb mariadb-client curl bash
    )
    if [[ "$WEBSERVER" == "nginx" ]]; then
        PKGS+=(nginx)
    else
        PKGS+=(apache2 "${PHP_P}-apache2")
    fi
    apk add --no-cache -q "${PKGS[@]}"
    ok "APK packages installed"
}

install_dnf() {
    header "Installing packages (dnf)"
    dnf install -y -q epel-release 2>/dev/null || true

    # Add Remi repo for PHP 8.x
    if ! rpm -q remi-release &>/dev/null; then
        local remi_url
        case "${OS_VER%%.*}" in
            8) remi_url="https://rpms.remirepo.net/enterprise/remi-release-8.rpm" ;;
            9) remi_url="https://rpms.remirepo.net/enterprise/remi-release-9.rpm" ;;
            *) remi_url="https://rpms.remirepo.net/enterprise/remi-release-9.rpm" ;;
        esac
        dnf install -y -q "$remi_url" || warn "Could not install Remi repo — PHP version may be limited"
    fi

    dnf module reset -y php &>/dev/null || true
    dnf module enable -y "php:remi-${PHP_VER}" &>/dev/null || \
        warn "Could not enable php:remi-${PHP_VER} module — using default"

    local PKGS=(php php-cli php-fpm php-pdo php-mysqlnd php-mbstring
                php-xml php-opcache php-json curl git mariadb-server mariadb)
    if [[ "$WEBSERVER" == "nginx" ]]; then
        PKGS+=(nginx)
    else
        PKGS+=(httpd mod_ssl)
    fi
    dnf install -y -q "${PKGS[@]}"
    ok "DNF packages installed"
}

verify_php_extensions() {
    header "Verifying PHP extensions"
    local REQUIRED=(pdo pdo_mysql openssl mbstring json hash)
    local MISSING=()
    for ext in "${REQUIRED[@]}"; do
        if $PHP_BIN -m 2>/dev/null | grep -qi "^${ext}$"; then
            ok "php-${ext}"
        else
            warn "php-${ext} missing"
            MISSING+=("$ext")
        fi
    done
    [[ ${#MISSING[@]} -eq 0 ]] || die "Missing PHP extensions: ${MISSING[*]}"
}

# ── MariaDB / MySQL setup ─────────────────────────────────────
setup_mariadb() {
    header "Configuring MariaDB"

    case "$PKG_MGR" in
        apt) systemctl enable --now mariadb ;;
        apk) rc-update add mariadb default 2>/dev/null || true
             mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql &>/dev/null || true
             rc-service mariadb start 2>/dev/null || service mariadb start ;;
        dnf) systemctl enable --now mariadb ;;
    esac

    # Wait for socket to be ready
    local tries=0
    until mysql -u root -e "SELECT 1" &>/dev/null 2>&1 || [[ $tries -ge 15 ]]; do
        sleep 1; ((tries++))
    done

    if [[ -n "${DB_ROOT_PASS:-}" ]]; then
        mysql -u root -e \
            "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}'; FLUSH PRIVILEGES;" \
            2>/dev/null || \
        mysql -u root -p"${DB_ROOT_PASS}" -e "SELECT 1" &>/dev/null || \
            warn "Could not set root password — skipping (already set?)"
        MYSQL_CMD="mysql -u root -p${DB_ROOT_PASS}"
    else
        MYSQL_CMD="mysql -u root"
    fi

    $MYSQL_CMD -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
        || die "Failed to create database '${DB_NAME}'"
    ok "Database '${DB_NAME}' ready"

    $MYSQL_CMD -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
        IDENTIFIED BY '${DB_PASS}';" \
        || warn "User '${DB_USER}' may already exist"
    $MYSQL_CMD -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
        FLUSH PRIVILEGES;"
    ok "User '${DB_USER}'@localhost granted"

    # Run schema
    $MYSQL_CMD "${DB_NAME}" < "${SRC_DIR}/webapp/setup.sql" \
        || die "Failed to run setup.sql"
    ok "Schema and seed data loaded"
}

# ── Apache vhost ──────────────────────────────────────────────
setup_apache() {
    header "Configuring Apache"

    case "$PKG_MGR" in
        apt)
            a2enmod rewrite headers php"${PHP_VER}" &>/dev/null || a2enmod rewrite headers
            ;;
        apk)
            sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/' \
                /etc/apache2/httpd.conf 2>/dev/null || true
            ;;
        dnf)
            # mod_rewrite is usually enabled by default on RHEL
            ;;
    esac

    local VHOST_FILE
    case "$PKG_MGR" in
        apt) VHOST_FILE="/etc/apache2/sites-available/worktrack.conf" ;;
        apk) VHOST_FILE="/etc/apache2/conf.d/worktrack.conf" ;;
        dnf) VHOST_FILE="/etc/httpd/conf.d/worktrack.conf" ;;
    esac

    cat > "$VHOST_FILE" <<VHOST
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot ${INSTALL_PATH}

    <Directory ${INSTALL_PATH}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch "(config\\.php|migrate_encrypt\\.php|install\\.php)$">
        Require all denied
    </FilesMatch>

    ErrorLog  /var/log/apache2/worktrack_error.log
    CustomLog /var/log/apache2/worktrack_access.log combined
</VirtualHost>
VHOST

    if [[ "$PKG_MGR" == "apt" ]]; then
        a2ensite worktrack.conf &>/dev/null
        a2dissite 000-default.conf &>/dev/null || true
        systemctl reload apache2
    elif [[ "$PKG_MGR" == "apk" ]]; then
        rc-service apache2 restart 2>/dev/null || service apache2 restart
    else
        systemctl enable --now httpd
        systemctl reload httpd
    fi
    ok "Apache virtual host configured → ${DOMAIN}"
}

# ── Nginx vhost ───────────────────────────────────────────────
setup_nginx() {
    header "Configuring Nginx + PHP-FPM"

    # Determine PHP-FPM socket path
    local FPM_SOCK
    case "$PKG_MGR" in
        apt) FPM_SOCK="/run/php/php${PHP_VER}-fpm.sock"
             systemctl enable --now "php${PHP_VER}-fpm" ;;
        apk) FPM_SOCK="/run/php-fpm${PHP_VER/./}.sock"
             rc-update add "php-fpm${PHP_VER/./}" default 2>/dev/null || true
             rc-service  "php-fpm${PHP_VER/./}" start 2>/dev/null || true ;;
        dnf) FPM_SOCK="/run/php-fpm/www.sock"
             systemctl enable --now php-fpm ;;
    esac

    local VHOST_FILE
    case "$PKG_MGR" in
        apt) VHOST_FILE="/etc/nginx/sites-available/worktrack" ;;
        *)   VHOST_FILE="/etc/nginx/conf.d/worktrack.conf" ;;
    esac

    cat > "$VHOST_FILE" <<VHOST
server {
    listen 80;
    server_name ${DOMAIN};
    root ${INSTALL_PATH};
    index index.php;

    location / {
        try_files \$uri \$uri/ /webapp/index.php\$is_args\$args;
    }

    location ~ \\.php$ {
        try_files \$uri =404;
        fastcgi_pass unix:${FPM_SOCK};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Block sensitive files
    location ~* (config\\.php|migrate_encrypt\\.php|install\\.php)$ {
        deny all;
        return 404;
    }

    location ~ /\\. { deny all; }
}
VHOST

    if [[ "$PKG_MGR" == "apt" ]]; then
        ln -sf "$VHOST_FILE" "/etc/nginx/sites-enabled/worktrack"
        rm -f /etc/nginx/sites-enabled/default
        systemctl enable --now nginx
        systemctl reload nginx
    elif [[ "$PKG_MGR" == "apk" ]]; then
        rc-update add nginx default 2>/dev/null || true
        rc-service nginx restart 2>/dev/null || service nginx restart
    else
        systemctl enable --now nginx
        systemctl reload nginx
    fi
    ok "Nginx virtual host configured → ${DOMAIN}"
}

# ── Firewall ─────────────────────────────────────────────────
open_firewall() {
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        ufw allow 80/tcp &>/dev/null
        ufw allow 443/tcp &>/dev/null
        ok "UFW: ports 80 and 443 opened"
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-service=http  &>/dev/null || true
        firewall-cmd --permanent --add-service=https &>/dev/null || true
        firewall-cmd --reload &>/dev/null || true
        ok "firewalld: http/https opened"
    fi
}

# ── File permissions ──────────────────────────────────────────
set_permissions() {
    header "Setting permissions"
    local WEB_USER
    case "$PKG_MGR" in
        apt) WEB_USER="www-data" ;;
        apk) WEB_USER="apache"  ;;
        dnf) WEB_USER="apache"  ;;
    esac
    chown -R "${WEB_USER}:${WEB_USER}" "${INSTALL_PATH}"
    chmod -R 750 "${INSTALL_PATH}"
    chmod 640 "${INSTALL_PATH}/webapp/config.php" 2>/dev/null || true
    chmod 640 "${INSTALL_PATH}/webapp/migrate_encrypt.php" 2>/dev/null || true
    ok "Owner: ${WEB_USER}, dirs 750, sensitive files 640"
}

# ── Generate config.php ───────────────────────────────────────
write_config() {
    header "Generating config.php"
    local JWT_SECRET;      JWT_SECRET=$(gen_hex)
    local ENCRYPTION_KEY;  ENCRYPTION_KEY=$(gen_hex)
    local SEARCH_KEY;      SEARCH_KEY=$(gen_hex)

    cat > "${INSTALL_PATH}/webapp/config.php" <<PHP
<?php
define('DB_HOST',    '${DB_HOST}');
define('DB_PORT',    '${DB_PORT}');
define('DB_NAME',    '${DB_NAME}');
define('DB_USER',    '${DB_USER}');
define('DB_PASS',    '${DB_PASS}');
define('DB_CHARSET', 'utf8mb4');

define('APP_URL',   '${APP_URL}');

define('JWT_SECRET',         '${JWT_SECRET}');
define('APP_ENCRYPTION_KEY', '${ENCRYPTION_KEY}');
define('APP_SEARCH_KEY',     '${SEARCH_KEY}');

define('ALLOWED_ORIGINS', [
    '${APP_URL}',
]);

// OAuth — fill in after obtaining credentials from each provider
define('GOOGLE_CLIENT_ID',     '${GOOGLE_CLIENT_ID:-}');
define('GOOGLE_CLIENT_SECRET', '${GOOGLE_CLIENT_SECRET:-}');

define('FACEBOOK_APP_ID',     '${FACEBOOK_APP_ID:-}');
define('FACEBOOK_APP_SECRET', '${FACEBOOK_APP_SECRET:-}');

define('APPLE_CLIENT_ID',   '${APPLE_CLIENT_ID:-}');
define('APPLE_TEAM_ID',     '${APPLE_TEAM_ID:-}');
define('APPLE_KEY_ID',      '${APPLE_KEY_ID:-}');
define('APPLE_PRIVATE_KEY', '');
PHP
    ok "config.php written"
}

# ── Self-check ────────────────────────────────────────────────
run_selfcheck() {
    header "Running self-check"
    $PHP_BIN -r "
        require '${INSTALL_PATH}/webapp/includes/db.php';
        require '${INSTALL_PATH}/webapp/includes/crypto.php';
        \$pdo = getDB();
        \$n   = \$pdo->query('SELECT COUNT(*) FROM exercises')->fetchColumn();
        echo \"  DB OK — {$n} exercises loaded\n\";
    " && ok "Database connection and schema verified" || \
        warn "Self-check failed — check credentials and try again"
}

# ── Interactive prompts ───────────────────────────────────────
collect_inputs() {
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║       WorkTrack  Installation        ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""

    ask DOMAIN        "Domain name (e.g. worktrack.example.com)" "localhost"
    ask INSTALL_PATH  "Install path"                             "/var/www/worktrack"
    ask WEBSERVER     "Web server [apache/nginx]"                "apache"
    [[ "$WEBSERVER" =~ ^(apache|nginx)$ ]] || die "Web server must be 'apache' or 'nginx'"
    ask APP_URL       "App public URL"                           "http://${DOMAIN}"

    echo ""
    echo -e "  ${BOLD}Database${NC}"
    ask DB_HOST "  DB host"     "localhost"
    ask DB_PORT "  DB port"     "3306"
    ask DB_NAME "  DB name"     "worktrack"
    ask DB_USER "  DB user"     "worktrack_user"
    ask_secret DB_PASS "  DB password (for app user)"
    [[ -n "$DB_PASS" ]] || die "DB password cannot be empty"

    echo ""
    warn "MariaDB root password is needed to create the database and user."
    warn "Leave empty if root has passwordless socket auth (common on fresh installs)."
    ask_secret DB_ROOT_PASS "  MariaDB root password"

    echo ""
    echo -e "  ${BOLD}OAuth credentials (press Enter to skip each)${NC}"
    ask GOOGLE_CLIENT_ID     "  Google Client ID"     ""
    [[ -z "$GOOGLE_CLIENT_ID" ]]  || ask GOOGLE_CLIENT_SECRET "  Google Client Secret" ""
    ask FACEBOOK_APP_ID      "  Facebook App ID"      ""
    [[ -z "$FACEBOOK_APP_ID" ]]   || ask FACEBOOK_APP_SECRET  "  Facebook App Secret"  ""
    ask APPLE_CLIENT_ID      "  Apple Client ID"      ""
    if [[ -n "$APPLE_CLIENT_ID" ]]; then
        ask APPLE_TEAM_ID    "  Apple Team ID"        ""
        ask APPLE_KEY_ID     "  Apple Key ID"         ""
    fi

    # Source directory (where this script lives = project root)
    SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ok "Source directory: ${SRC_DIR}"
}

# ── Copy project files ────────────────────────────────────────
copy_files() {
    header "Copying project files to ${INSTALL_PATH}"
    mkdir -p "${INSTALL_PATH}"
    cp -a "${SRC_DIR}/." "${INSTALL_PATH}/"
    # Remove installer and dev files from production copy
    rm -f "${INSTALL_PATH}/install.sh"
    rm -f "${INSTALL_PATH}/webapp/migrate_encrypt.php"  # keep only if needed for migration
    ok "Files copied"
}

# ── Main ──────────────────────────────────────────────────────
main() {
    collect_inputs
    detect_os

    header "Installing system packages"
    case "$PKG_MGR" in
        apt) install_apt ;;
        apk) install_apk ;;
        dnf) install_dnf ;;
    esac

    pick_php_binary
    [[ -n "$PHP_BIN" ]] || die "PHP 8.1+ not found after installation. Check package manager output."
    ok "PHP binary: ${PHP_BIN} (${PHP_VER})"

    verify_php_extensions
    copy_files
    setup_mariadb
    write_config

    if [[ "$WEBSERVER" == "nginx" ]]; then
        setup_nginx
    else
        setup_apache
    fi

    set_permissions
    open_firewall
    run_selfcheck

    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║         Installation complete! ✓             ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Web UI   : ${CYAN}${APP_URL}/webapp/${NC}"
    echo -e "  API base : ${CYAN}${APP_URL}/${NC}"
    echo -e "  DB name  : ${DB_NAME}"
    echo -e "  DB user  : ${DB_USER}"
    echo ""
    echo -e "  ${YELLOW}Next steps:${NC}"
    echo -e "  1. Point your DNS for '${DOMAIN}' to this server's IP"
    echo -e "  2. Add OAuth credentials to ${INSTALL_PATH}/webapp/config.php"
    if command -v certbot &>/dev/null; then
        echo -e "  3. Run: ${CYAN}certbot --${WEBSERVER} -d ${DOMAIN}${NC}  (free HTTPS)"
    else
        echo -e "  3. Install certbot for free HTTPS: ${CYAN}apt install certbot${NC}"
    fi
    echo ""
}

main "$@"
