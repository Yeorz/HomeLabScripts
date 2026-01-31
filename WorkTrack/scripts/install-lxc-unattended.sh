#!/usr/bin/env bash
set -euo pipefail

# install-lxc-unattended.sh
# Enhanced LXC installer with unattended flags and repo-copy option.
# This is a companion to scripts/install-lxc.sh. Use it when you want
# CLI-driven installs or CI automation.
#
# Examples:
#  Interactive:
#    bash scripts/install-lxc-unattended.sh
#  Unattended (DHCP default):
#    bash scripts/install-lxc-unattended.sh --container my-container --unattended --copy-repo
#  Unattended static IP:
#    bash scripts/install-lxc-unattended.sh --container my-container --unattended --ip-method static \
#      --static-ip 10.0.3.25/24 --gateway 10.0.3.1 --dns 8.8.8.8 --copy-repo

WORKDIR=$(pwd)
TIMESTAMP=$(date +%s)

echo "\nWorkTrack LXC unattended installer"

if ! command -v lxc-attach >/dev/null 2>&1; then
  echo "Error: lxc-attach not found on host. Install LXC tools and try again." >&2
  exit 1
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
    -h|--help) sed -n '1,200p' "$0"; exit 0;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

if [ "$UNATTENDED" -eq 0 ]; then
  read -rp "Container name (existing): " CONTAINER
fi

if [ -z "${CONTAINER}" ]; then
  echo "No container name provided. Use --container or run interactively." >&2
  exit 1
fi

if ! lxc-info -n "${CONTAINER}" &>/dev/null; then
  echo "Container '${CONTAINER}' not found." >&2
  lxc-ls --fancy || true
  exit 1
fi

if [ "$UNATTENDED" -eq 0 ]; then
  read -rp "Desired hostname (press Enter to use '${CONTAINER}'): " HOSTNAME
fi
HOSTNAME=${HOSTNAME:-$CONTAINER}

if [ "$UNATTENDED" -eq 0 ]; then
  printf "\nIP assignment method:\n  1) DHCP (default)\n  2) Static IP\n"
  read -rp "Choose [1/2]: " IP_CHOICE
  IP_CHOICE=${IP_CHOICE:-1}
  if [ "$IP_CHOICE" = "2" ]; then IP_METHOD="static"; else IP_METHOD="dhcp"; fi
fi

if [ "$IP_METHOD" = "static" ]; then
  if [ "$UNATTENDED" -eq 0 ]; then
    read -rp "Enter static IP (CIDR, e.g. 10.0.3.25/24): " STATIC_IP
    read -rp "Enter gateway (e.g. 10.0.3.1): " STATIC_GW
    read -rp "Enter DNS servers (comma-separated, default 8.8.8.8): " STATIC_DNS
    STATIC_DNS=${STATIC_DNS:-8.8.8.8}
  else
    if [ -z "$STATIC_IP" ] || [ -z "$STATIC_GW" ]; then
      echo "Unattended static mode requires --static-ip and --gateway" >&2
      exit 1
    fi
  fi
fi

echo "Configuring container '${CONTAINER}' (hostname: ${HOSTNAME})..."

# Copy repo if requested
if [ "$COPY_REPO" -eq 1 ]; then
  TARFILE="/tmp/worktrack-${TIMESTAMP}.tar.gz"
  tar --exclude='./.git' --exclude='./node_modules' --exclude='tests/test-report-*' -czf "$TARFILE" -C "$WORKDIR" .
  echo "Pushing $TARFILE to container..."
  lxc file push "$TARFILE" "${CONTAINER}/tmp/" || { echo "lxc file push failed" >&2; exit 1; }
fi

# Prepare env opts
ENV_OPTS=("--env" "HOSTNAME=${HOSTNAME}" "--env" "USE_DHCP=$([ "$IP_METHOD" = "dhcp" ] && echo 1 || echo 0)")
if [ "$IP_METHOD" = "static" ]; then
  ENV_OPTS+=("--env" "STATIC_IP=${STATIC_IP}" "--env" "STATIC_GW=${STATIC_GW}" "--env" "STATIC_DNS=${STATIC_DNS}")
fi

sudo lxc-attach -n "${CONTAINER}" "${ENV_OPTS[@]}" -- bash -s <<'INLXC'
set -euo pipefail

echo "[container] OS check..."
if [ -f /etc/os-release ]; then . /etc/os-release; echo "Detected: $NAME $VERSION"; fi

# Hostname
echo "Setting hostname to $HOSTNAME"
if command -v hostnamectl >/dev/null 2>&1; then hostnamectl set-hostname "$HOSTNAME"; else echo "$HOSTNAME" >/etc/hostname; sed -i "/127.0.1.1/d" /etc/hosts 2>/dev/null || true; echo "127.0.1.1 $HOSTNAME" >> /etc/hosts; fi

configure_dhcp() {
  if [ -d /etc/netplan ]; then
    cat >/etc/netplan/99-worktrack-dhcp.yaml <<NET
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
NET
    netplan apply || true
    return
  fi
  if [ -f /etc/network/interfaces ]; then
    sed -i '/iface eth0 inet/d' /etc/network/interfaces || true
    cat >>/etc/network/interfaces <<IFACE

# WorkTrack DHCP
auto eth0
iface eth0 inet dhcp
IFACE
    ifdown eth0 2>/dev/null || true; ifup eth0 2>/dev/null || true; return
  fi
  echo "No recognized network config system found" >&2
}

configure_static() {
  ip_cidr="$STATIC_IP"; gw="$STATIC_GW"; dns="$STATIC_DNS"
  if [ -d /etc/netplan ]; then
    cat >/etc/netplan/99-worktrack-static.yaml <<NET
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - ${ip_cidr}
      gateway4: ${gw}
      nameservers:
        addresses: [${dns}]
NET
    netplan apply || true; return
  fi
  if [ -f /etc/network/interfaces ]; then
    sed -i '/auto eth0/,/iface eth0 inet/d' /etc/network/interfaces || true
    cat >>/etc/network/interfaces <<IFACE

# WorkTrack static
auto eth0
iface eth0 inet static
  address ${ip_cidr%%/*}
  netmask 255.255.255.0
  gateway ${gw}
  dns-nameservers ${dns}
IFACE
    ifdown eth0 2>/dev/null || true; ifup eth0 2>/dev/null || true; return
  fi
  echo "No recognized network config system found" >&2
}

if [ "${USE_DHCP:-}" = "1" ]; then configure_dhcp; else configure_static; fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true
apt-get install -y --no-install-recommends curl gnupg ca-certificates lsb-release software-properties-common build-essential git sqlite3 libsqlite3-dev apt-transport-https

if ! command -v node >/dev/null 2>&1 || [ "$(node -v 2>/dev/null | cut -d. -f1)" != "v22" ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

if ! command -v pm2 >/dev/null 2>&1; then npm install -g pm2 --no-audit --no-fund; fi

if command -v locale-gen >/dev/null 2>&1; then locale-gen en_US.UTF-8 || true; fi

apt-get autoremove -y || true
apt-get clean || true

echo "[container] runtime tooling installed"
INLXC

if [ "$COPY_REPO" -eq 1 ]; then
  TARFILE_HOST="/tmp/worktrack-${TIMESTAMP}.tar.gz"
  TARFILE_CONTAINER="/tmp/$(basename "$TARFILE_HOST")"
  echo "Extracting repository into /root/worktrack in container..."
  sudo lxc-attach -n "${CONTAINER}" -- bash -c "mkdir -p /root/worktrack && tar -xzf ${TARFILE_CONTAINER} -C /root/worktrack && chown -R root:root /root/worktrack"
  echo "Repo copied to container:/root/worktrack"
fi

cat <<EOF

Done. Container '${CONTAINER}' configured.
- Hostname: ${HOSTNAME}
- IP assignment: $( [ "$IP_METHOD" = "dhcp" ] && echo "DHCP" || echo "Static: ${STATIC_IP}" )

Next steps:
- If repo copied: sudo lxc-attach -n ${CONTAINER} -- bash -c 'cd /root/worktrack && npm install' in each service dir
- Start backend: sudo lxc-attach -n ${CONTAINER} -- pm2 start --name worktrack-backend --cwd /root/worktrack/backend -- npm -- start
- Inspect network: sudo lxc-attach -n ${CONTAINER} -- ip addr

EOF
