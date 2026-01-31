#!/usr/bin/env bash
set -euo pipefail

# install-lxc.sh (v2)
# Enhanced LXC installer with GitHub clone, firewall, and auto-start
# Usage: bash scripts/install-lxc.sh --force-container [--copy-repo]

echo -e "\n🚀 \033[1;32mWorkTrack LXC Installer\033[0m\n"

# Container detection
IN_CONTAINER=0
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
  IN_CONTAINER=1
elif [ -f /proc/1/cgroup ] && grep -q -E "(lxc|container=lxc)" /proc/1/cgroup 2>/dev/null; then
  IN_CONTAINER=1
fi

# OS check (skip if in container)
if [ "$IN_CONTAINER" -eq 0 ]; then
  OS=$(uname -s)
  if [ "$OS" != "Linux" ]; then
    echo "❌ Error: This script requires LXC (Linux only)" >&2; exit 1
  fi
  if ! command -v lxc-attach >/dev/null 2>&1; then
    echo "❌ Error: lxc-attach not found. Install with: sudo apt-get install lxc lxc-utils" >&2; exit 1
  fi
else
  echo "✓ Detected: Running inside LXC container"
fi

# Allow forcing container mode
if [ "$IN_CONTAINER" -eq 0 ] && [ "${FORCE_CONTAINER:-0}" = "1" ]; then
  IN_CONTAINER=1
fi

# Defaults
CONTAINER=""
HOSTNAME=""
IP_METHOD="dhcp"
STATIC_IP=""
STATIC_GW=""
STATIC_DNS="8.8.8.8"
UNATTENDED=0
COPY_REPO=0
UPDATE_CONFIG=0
START_SERVICES=1

# Parse args
while [ "$#" -gt 0 ]; do
  case "$1" in
    -c|--container) CONTAINER="$2"; shift 2;;
    --hostname) HOSTNAME="$2"; shift 2;;
    --ip-method) IP_METHOD="$2"; shift 2;;
    --static-ip) STATIC_IP="$2"; shift 2;;
    --gateway) STATIC_GW="$2"; shift 2;;
    --dns) STATIC_DNS="$2"; shift 2;;
    -y|--unattended) UNATTENDED=1; shift 1;;
    --copy-repo) COPY_REPO=1; shift 1;;
    --force-container) IN_CONTAINER=1; shift 1;;
    --update-config|--reconfigure) UPDATE_CONFIG=1; shift 1;;
    --no-start-services) START_SERVICES=0; shift 1;;
    -h|--help) sed -n '1,80p' "$0"; exit 0;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

WORKDIR=$(pwd)
TIMESTAMP=$(date +%s)

# Setup mode detection
if [ "$IN_CONTAINER" -eq 1 ]; then
  if [ "$UNATTENDED" -eq 0 ] && [ "$UPDATE_CONFIG" -eq 0 ]; then
    read -rp "Desired hostname (press Enter for default): " HOSTNAME
  fi
  HOSTNAME=${HOSTNAME:-$(hostname 2>/dev/null || echo "worktrack")}
  echo "$([ "$UPDATE_CONFIG" -eq 1 ] && echo "📝 Updating" || echo "✓ Configuring") current container (hostname: $HOSTNAME)..."
  CONFIGURE_SELF=1
else
  if [ "$UNATTENDED" -eq 0 ]; then
    read -rp "Container name: " CONTAINER
  fi
  if [ -n "$CONTAINER" ] && ! sudo lxc-info -n "$CONTAINER" >/dev/null 2>&1; then
    echo "❌ Error: Container '$CONTAINER' not found" >&2
    sudo lxc-ls 2>/dev/null || echo "  (unable to list)" >&2
    read -rp "Try again? (y/n): " RETRY
    [[ "$RETRY" =~ ^[Yy]$ ]] && read -rp "Container name: " CONTAINER || exit 1
    if [ -z "$CONTAINER" ] || ! sudo lxc-info -n "$CONTAINER" >/dev/null 2>&1; then
      echo "❌ Invalid container. Exiting." >&2; exit 1
    fi
  fi
  HOSTNAME=${HOSTNAME:-$CONTAINER}
  echo "✓ Configuring container '${CONTAINER}' (hostname: ${HOSTNAME})..."
  CONFIGURE_SELF=0
fi

# IP config prompts
if [ "$UNATTENDED" -eq 0 ] && [ "$CONFIGURE_SELF" -eq 0 ]; then
  printf "\nIP assignment:\n  1) DHCP (default)\n  2) Static\n"
  read -rp "Choose [1/2]: " IP_CHOICE
  [ "$IP_CHOICE" = "2" ] && IP_METHOD="static" || IP_METHOD="dhcp"
fi

if [ "$IP_METHOD" = "static" ]; then
  if [ "$UNATTENDED" -eq 0 ]; then
    read -rp "Static IP (CIDR): " STATIC_IP
    read -rp "Gateway: " STATIC_GW
    read -rp "DNS (default 8.8.8.8): " STATIC_DNS
    STATIC_DNS=${STATIC_DNS:-8.8.8.8}
  else
    [ -z "$STATIC_IP" ] || [ -z "$STATIC_GW" ] && { echo "Need --static-ip and --gateway"; exit 1; }
  fi
fi

# Repo copy (host mode only)
if [ "$COPY_REPO" -eq 1 ] && [ "$CONFIGURE_SELF" -eq 0 ]; then
  TARFILE="/tmp/worktrack-${TIMESTAMP}.tar.gz"
  echo "📦 Creating tarball..."
  tar --exclude='./.git' --exclude='./node_modules' --exclude='tests/test-report-*' -czf "$TARFILE" -C "$WORKDIR" .
  echo "📤 Pushing to container..."
  lxc file push "$TARFILE" "${CONTAINER}/tmp/" || { echo "Push failed" >&2; exit 1; }
fi

# Build config script
ENV_OPTS=("--env" "HOSTNAME=${HOSTNAME}" "--env" "USE_DHCP=$([ "$IP_METHOD" = "dhcp" ] && echo 1 || echo 0)")
[ "$IP_METHOD" = "static" ] && ENV_OPTS+=("--env" "STATIC_IP=${STATIC_IP}" "--env" "STATIC_GW=${STATIC_GW}" "--env" "STATIC_DNS=${STATIC_DNS}")

CONFIG_SCRIPT=$(cat <<'CONFIG_SCRIPT_EOF'
set -euo pipefail
echo "[setup] Starting configuration..."

# Hostname
hostnamectl set-hostname "$HOSTNAME" 2>/dev/null || { echo "$HOSTNAME" >/etc/hostname; }

# Network
configure_dhcp() {
  if [ -d /etc/netplan ]; then
    cat >/etc/netplan/99-worktrack.yaml <<NET
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
NET
    netplan apply || true
  elif [ -f /etc/network/interfaces ]; then
    sed -i "/auto eth0/,/iface eth0 inet/d" /etc/network/interfaces || true
    cat >>/etc/network/interfaces <<IFACE

auto eth0
iface eth0 inet dhcp
IFACE
    ifdown eth0 2>/dev/null || true; ifup eth0 2>/dev/null || true
  fi
}

configure_static() {
  if [ -d /etc/netplan ]; then
    cat >/etc/netplan/99-worktrack.yaml <<NET
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - $STATIC_IP
      gateway4: $STATIC_GW
      nameservers:
        addresses: [$STATIC_DNS]
NET
    netplan apply || true
  fi
}

[ "${USE_DHCP:-}" = "1" ] && configure_dhcp || configure_static

# Packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get install -y --no-install-recommends curl gnupg ca-certificates build-essential git sqlite3 || true
[ grep -q "ubuntu" /etc/os-release 2>/dev/null ] && apt-get install -y software-properties-common 2>/dev/null || true

# Node.js 22 (includes npm, remove conflicting system npm first)
apt-get remove -y npm 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
if ! command -v node >/dev/null 2>&1 || [ "$(node -v 2>/dev/null | cut -d. -f1)" != "v22" ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs
fi

npm install -g pm2 --no-audit --no-fund || true

# Clone repo if needed
if [ ! -d /root/worktrack ]; then
  echo "[setup] Cloning WorkTrack..."
  git clone https://github.com/Yeorz/HomeLabScripts.git /root/worktrack 2>&1 | tail -2 || true
  if [ -d /root/worktrack/WorkTrack ]; then
    mv /root/worktrack/WorkTrack/* /root/worktrack/ && rm -rf /root/worktrack/WorkTrack
  fi
fi

# Firewall
ufw allow 80/tcp 2>/dev/null || true
ufw allow 443/tcp 2>/dev/null || true
ufw allow 3001/tcp 2>/dev/null || true
ufw allow 5173/tcp 2>/dev/null || true

# Services
if [ -d /root/worktrack/backend ] && [ -d /root/worktrack/web ]; then
  echo "[setup] Installing dependencies and starting services..."
  
  cd /root/worktrack/backend
  echo "   Installing backend dependencies..."
  npm install --no-audit --no-fund 2>&1 | grep -E "(added|packages|warn|error)" | head -5 || true

  # Ensure required env vars for backend
  CONTAINER_IP=$(hostname -I 2>/dev/null | awk "{print \$1}" || true)
  CONTAINER_IP=${CONTAINER_IP:-127.0.0.1}
  if [ ! -f /root/worktrack/backend/.env ]; then
    echo "JWT_SECRET=$(openssl rand -base64 32)" >/root/worktrack/backend/.env || true
    echo "SESSION_SECRET=$(openssl rand -base64 32)" >>/root/worktrack/backend/.env || true
    echo "FRONTEND_URL=http://$CONTAINER_IP" >>/root/worktrack/backend/.env || true
    echo "NODE_ENV=production" >>/root/worktrack/backend/.env || true
  fi

  # Kill any old pm2 process first
  pm2 delete worktrack-backend 2>/dev/null || true
  
  # Start backend with simple node call (dotenv loads from .env via server.js)
  pm2 start --name worktrack-backend --cwd /root/worktrack/backend -- node server.js 2>/dev/null || true
  
  cd /root/worktrack/web && npm ci --no-audit --no-fund 2>&1 | tail -1 || true
  npm run build 2>&1 | grep -E "(built|✓)" | tail -1 || true
  
  # Setup nginx reverse proxy
  apt-get install -y nginx 2>/dev/null || true
  cat >/etc/nginx/sites-available/worktrack <<'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    client_max_body_size 50M;

    location /api/ {
        proxy_pass http://localhost:3001/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
      root /root/worktrack/web/dist;
      try_files $uri $uri/ /index.html;
    }
}
NGINX_CONF
  
  ln -sf /etc/nginx/sites-available/worktrack /etc/nginx/sites-enabled/worktrack 2>/dev/null || true
  rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
  nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null || true
  systemctl enable nginx 2>/dev/null || true
  
  pm2 save 2>/dev/null || true
  pm2 startup -u root --hp /root 2>/dev/null || true
  
  sleep 2
  CONTAINER_IP=$(hostname -I | awk "{print \$1}")
  echo "[setup] ✓ Services ready at http://$CONTAINER_IP"
fi
CONFIG_SCRIPT_EOF
)

# Execute
if [ "$CONFIGURE_SELF" -eq 1 ]; then
  echo "⚙️  Running setup inside container..."
  bash -s <<CMD
export HOSTNAME="$HOSTNAME"
export USE_DHCP=$([ "$IP_METHOD" = "dhcp" ] && echo 1 || echo 0)
export STATIC_IP="$STATIC_IP"
export STATIC_GW="$STATIC_GW"
export STATIC_DNS="$STATIC_DNS"
$CONFIG_SCRIPT
CMD
else
  if ! command -v sudo >/dev/null 2>&1; then
    echo "❌ Error: sudo not found. If inside container, use --force-container" >&2
    exit 1
  fi
  echo "⚙️  Running setup on host for container: $CONTAINER..."
  sudo lxc-attach -n "${CONTAINER}" "${ENV_OPTS[@]}" -- bash -s <<'CMD'
export HOSTNAME="${HOSTNAME}"
export USE_DHCP="${USE_DHCP:-0}"
export STATIC_IP="${STATIC_IP}"
export STATIC_GW="${STATIC_GW}"
export STATIC_DNS="${STATIC_DNS}"
$CONFIG_SCRIPT
CMD
  
  if [ "$COPY_REPO" -eq 1 ]; then
    TARFILE="/tmp/worktrack-${TIMESTAMP}.tar.gz"
    echo "📦 Extracting repo..."
    sudo lxc-attach -n "${CONTAINER}" -- bash -c "mkdir -p /root/worktrack && tar -xzf /tmp/$(basename $TARFILE) -C /root/worktrack && chown -R root:root /root/worktrack"
  fi
fi

# Detect container IP for external access
CONTAINER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
if [ -z "$CONTAINER_IP" ] || [ "$CONTAINER_IP" = "" ]; then
  CONTAINER_IP="localhost"
fi

# Pretty summary
if [ "$IP_METHOD" = "static" ]; then
  CONTAINER_IP="${STATIC_IP%%/*}"
fi
WEB_URL="http://$CONTAINER_IP"

printf "\n\033[1;32m╔════════════════════════════════════════════════════╗\033[0m\n"
printf "\033[1;32m║  ✓ WorkTrack Setup Complete!                        ║\033[0m\n"
printf "\033[1;32m╚════════════════════════════════════════════════════╝\033[0m\n\n"

printf "\033[1;34m📋 Configuration:\033[0m\n"
printf "   Hostname: \033[1;33m%s\033[0m\n" "$HOSTNAME"
printf "   IP Method: \033[1;33m%s\033[0m\n" "$([ "$IP_METHOD" = "dhcp" ] && echo "DHCP" || echo "Static: $STATIC_IP")"
printf "   Mode: \033[1;33m%s\033[0m\n\n" "$([ "$CONFIGURE_SELF" -eq 1 ] && echo "Container" || echo "Host→Container")"

printf "\033[1;36m🌐 Web Access (from external machines):\033[0m\n"
printf "   \033[1;32m➜ Frontend: %s\033[0m\n" "$WEB_URL"
printf "   \033[1;32m➜ Backend API: %s/api/\033[0m\n\n" "$WEB_URL"

printf "\033[1;35m⚙️  Services:\033[0m\n"
printf "   pm2 list                      (show status)\n"
printf "   pm2 logs worktrack-backend    (view logs)\n"
printf "   pm2 restart all               (restart services)\n\n"

printf "\033[1;33m💡 Next Step:\033[0m\n"
printf "   Open your browser: \033[4m$WEB_URL\033[0m\n\n"
printf "\033[1;32m✨ Enjoy WorkTrack!\033[0m\n\n"
