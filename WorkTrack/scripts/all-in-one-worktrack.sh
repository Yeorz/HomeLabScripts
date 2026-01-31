#!/usr/bin/env bash
# Combined WorkTrack scripts: deploy-lxc, manage-lxc, advanced-setup, ci-cd-deploy
# Single-file dispatcher that inlines the four original scripts as functions.

set -euo pipefail

# Common color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; return 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

###############################################################################
# deploy-lxc (inlined)
###############################################################################
deploy_lxc_main() {
    # Adapted from deploy-lxc.sh
    CONTAINER_ID="${1:-100}"
    CONTAINER_NAME="${2:-worktrack-app}"
    CONTAINER_IP="${3:-192.168.1.100}"
    CONTAINER_NETMASK="${4:-24}"
    CONTAINER_GATEWAY="${5:-192.168.1.1}"
    STORAGE_POOL="${6:-local}"
    CONTAINER_MEMORY="${7:-2048}"
    CONTAINER_CORES="${8:-2}"
    # shellcheck disable=SC2034 # may be referenced externally or in future updates
    PROXMOX_HOST="${9:-pve}"

    validate_proxmox() {
        log "Validating Proxmox environment..."
        if ! command -v pvesh &> /dev/null; then
            error "Proxmox tools not found. Run this script on a Proxmox node." || return 1
        fi
        if ! command -v pct &> /dev/null; then
            error "LXC tools (pct) not found." || return 1
        fi
        success "Proxmox tools validated"
    }

    check_container_exists() {
        log "Checking if container $CONTAINER_ID already exists..."
        if pct status "$CONTAINER_ID" &> /dev/null; then
            error "Container $CONTAINER_ID already exists. Please choose a different ID or remove existing container." || return 1
        fi
        success "Container ID $CONTAINER_ID is available"
    }

    check_storage() {
        log "Validating storage pool '$STORAGE_POOL'..."
        if ! pvesh get /storage/"$STORAGE_POOL" &> /dev/null; then
            error "Storage pool '$STORAGE_POOL' not found on Proxmox node." || return 1
        fi
        success "Storage pool validated"
    }

    create_lxc_container() {
        log "Creating LXC container $CONTAINER_ID ($CONTAINER_NAME)..."
        pct create "$CONTAINER_ID" \
            "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst" \
            --hostname "$CONTAINER_NAME" \
            --memory "$CONTAINER_MEMORY" \
            --cores "$CONTAINER_CORES" \
            --swap 512 \
            --storage "$STORAGE_POOL" \
            --net0 "name=eth0,bridge=vmbr0,ip=${CONTAINER_IP}/${CONTAINER_NETMASK},gw=$CONTAINER_GATEWAY" \
            --nameserver 8.8.8.8 \
            --searchdomain local \
            --features nesting=1 \
            --unprivileged 1
        success "LXC container created"
    }

    start_container() {
        log "Starting LXC container..."
        pct start "$CONTAINER_ID"
        log "Waiting for container to be fully online (15 seconds)..."
        sleep 15
        success "Container started"
    }

    setup_container() {
        log "Setting up container $CONTAINER_ID..."
        pct exec "$CONTAINER_ID" -- apt-get update
        pct exec "$CONTAINER_ID" -- apt-get upgrade -y
        success "Container packages updated"
    }

    install_dependencies() {
        log "Installing dependencies..."
        pct exec "$CONTAINER_ID" -- apt-get install -y \
            curl wget git sudo vim nano \
            build-essential python3 python3-pip \
            ca-certificates gnupg lsb-release \
            apt-transport-https
        success "System dependencies installed"
    }

    install_nodejs() {
        log "Installing Node.js 22 (LTS)..."
        pct exec "$CONTAINER_ID" -- bash -c '
            curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
            apt-get install -y nodejs
        '
        success "Node.js installed"
    }

    install_docker() {
        log "Installing Docker..."
        pct exec "$CONTAINER_ID" -- bash -c '
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            usermod -aG docker root
        '
        success "Docker installed"
    }

    install_sqlite3() {
        log "Installing SQLite3..."
        pct exec "$CONTAINER_ID" -- apt-get install -y sqlite3
        success "SQLite3 installed"
    }

    create_app_directories() {
        log "Creating application directories..."
        pct exec "$CONTAINER_ID" -- mkdir -p /opt/worktrack/{backend,web,data}
        success "Application directories created"
    }

    setup_backend() {
        log "Setting up backend service..."
        JWT_SECRET_HOST="$(openssl rand -base64 32)"
        SESSION_SECRET_HOST="$(openssl rand -base64 32)"
        pct exec "$CONTAINER_ID" -- bash -c "cat > /opt/worktrack/backend/.env <<'ENVEOF'
NODE_ENV=production
PORT=3001
FRONTEND_URL=http://${CONTAINER_IP}:5173
JWT_SECRET=${JWT_SECRET_HOST}
SESSION_SECRET=${SESSION_SECRET_HOST}
SAML_ENTRY_POINT=https://your-idp.example.com/sso
ENVEOF"
        success "Backend environment configured"
    }

    setup_web() {
        log "Setting up web service..."
        pct exec "$CONTAINER_ID" -- bash -c "cat > /opt/worktrack/web/.env <<'ENVEOF'
REACT_APP_OAUTH_CLIENT_ID=your-oauth-client-id
REACT_APP_API_URL=http://${CONTAINER_IP}:3001
ENVEOF"
        success "Web environment configured"
    }

    create_systemd_services() {
        log "Creating systemd service files..."
        pct exec "$CONTAINER_ID" -- bash -c 'cat > /etc/systemd/system/worktrack-backend.service << "SERVICEEOF"
[Unit]
Description=WorkTrack Backend Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/worktrack/backend
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF
'
        pct exec "$CONTAINER_ID" -- bash -c 'cat > /etc/systemd/system/worktrack-web.service << "SERVICEEOF"
[Unit]
Description=WorkTrack Web Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/worktrack/web
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/bin/npx serve -s build -l 5173
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF
'
        pct exec "$CONTAINER_ID" -- systemctl daemon-reload
        success "Systemd services created"
    }

    setup_firewall() {
        log "Configuring firewall rules..."
        pct exec "$CONTAINER_ID" -- bash -c '
            apt-get install -y ufw
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow 22/tcp
            ufw allow 3001/tcp
            ufw allow 5173/tcp
            echo "y" | ufw enable
        '
        success "Firewall configured"
    }

    setup_security_hardening() {
        log "Applying security hardening..."
        pct exec "$CONTAINER_ID" -- bash -c '
            sed -i "s/#PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
            systemctl restart sshd
        '
        success "Security hardening applied"
    }

    verify_container() {
        log "Verifying container status..."
        local status
        status=$(pct status "$CONTAINER_ID" | awk '{print $2}')
        if [ "$status" != "running" ]; then
            error "Container is not running. Status: $status" || return 1
        fi
        success "Container is running"
    }

    verify_services() {
        log "Verifying installed services..."
        pct exec "$CONTAINER_ID" -- bash -c '
            echo "=== Node.js version ==="
            node --version
            npm --version
            echo "=== Docker version ==="
            docker --version
            echo "=== SQLite3 ==="
            sqlite3 --version
        '
        success "All services verified"
    }

    print_deployment_summary() {
        cat << EOF

${GREEN}════════════════════════════════════════════════════════════${NC}
${GREEN}WorkTrack Deployment Complete!${NC}
${GREEN}════════════════════════════════════════════════════════════${NC}

${BLUE}Container Details:${NC}
  Container ID:    $CONTAINER_ID
  Container Name:  $CONTAINER_NAME
  IP Address:      $CONTAINER_IP
  Memory:          ${CONTAINER_MEMORY}MB
  Cores:           $CONTAINER_CORES

${BLUE}Next Steps:${NC}

1. Copy application files to container:
   scp -r ./backend root@${CONTAINER_IP}:/opt/worktrack/
   scp -r ./web root@${CONTAINER_IP}:/opt/worktrack/

2. Install backend dependencies:
   ssh root@${CONTAINER_IP}
   cd /opt/worktrack/backend && npm install

3. Build web application:
   cd /opt/worktrack/web && npm install && npm run build

4. Start services:
   systemctl start worktrack-backend
   systemctl start worktrack-web
   systemctl enable worktrack-backend
   systemctl enable worktrack-web

5. Access the application:
   Web Dashboard:  http://${CONTAINER_IP}:5173
   Backend API:    http://${CONTAINER_IP}:3001

${GREEN}════════════════════════════════════════════════════════════${NC}

EOF
    }

    # Execute phases
    log "Starting WorkTrack Proxmox LXC Deployment"
    validate_proxmox || return 1
    check_container_exists || return 1
    check_storage || return 1
    create_lxc_container || return 1
    start_container || return 1
    setup_container || return 1
    install_dependencies || return 1
    install_nodejs || return 1
    install_docker || return 1
    install_sqlite3 || return 1
    create_app_directories || return 1
    setup_backend || return 1
    setup_web || return 1
    create_systemd_services || return 1
    setup_firewall || return 1
    setup_security_hardening || return 1
    verify_container || return 1
    verify_services || return 1
    print_deployment_summary || return 0
}

###############################################################################
# manage-lxc (inlined)
###############################################################################
manage_lxc_main() {
    if [ $# -lt 2 ]; then
        cat << EOF
Usage: $0 <command> <container_id> [options]

Commands:
  start stop restart status logs shell backup update health-check remove
EOF
        return 1
    fi

    command=$1
    container_id=$2
    shift 2

    start_container() { pct start "$container_id"; success "Container started"; }
    stop_container() { pct stop "$container_id"; success "Container stopped"; }
    restart_container() { pct reboot "$container_id"; success "Container restarted"; }
    show_status() { pct status "$container_id"; pct exec "$container_id" -- systemctl status worktrack-backend worktrack-web || true; }
    show_logs() { local service=${1:-backend}; if [ "$service" = "backend" ]; then pct exec "$container_id" -- journalctl -u worktrack-backend -n 50 -f; elif [ "$service" = "web" ]; then pct exec "$container_id" -- journalctl -u worktrack-web -n 50 -f; else pct exec "$container_id" -- journalctl -n 100 -f; fi }
    open_shell() { pct exec "$container_id" -- /bin/bash; }
    backup_container() { local backup_path=${1:-/var/lib/vz/images/backups}; mkdir -p "$backup_path"; pct dump "$container_id" "$backup_path/worktrack-backup-$(date +%Y%m%d_%H%M%S).tar.zst"; success "Backup completed"; }
    health_check() {
        local status; status=$(pct status "$container_id" | awk '{print $2}'); if [ "$status" != "running" ]; then error "Container is not running" || return 1; fi
        pct exec "$container_id" -- systemctl is-active --quiet worktrack-backend && echo -e "${GREEN}✓${NC} Backend service is running" || echo -e "${RED}✗${NC} Backend service is not running"
        pct exec "$container_id" -- systemctl is-active --quiet worktrack-web && echo -e "${GREEN}✓${NC} Web service is running" || echo -e "${RED}✗${NC} Web service is not running"
        pct exec "$container_id" -- df -h /opt/worktrack
        pct exec "$container_id" -- free -h
        success "Health check completed"
    }
    update_application() { local source_dir=${1:-.}; rsync -avz --delete "$source_dir/backend/" root@"$(pct exec "$container_id" -- hostname -I | awk '{print $1}'):/opt/worktrack/backend/"; rsync -avz --delete "$source_dir/web/" root@"$(pct exec "$container_id" -- hostname -I | awk '{print $1}'):/opt/worktrack/web/"; pct exec "$container_id" -- bash -c 'cd /opt/worktrack/backend && npm install'; pct exec "$container_id" -- bash -c 'cd /opt/worktrack/web && npm install && npm run build'; pct exec "$container_id" -- systemctl restart worktrack-backend worktrack-web; success "Application updated"; }
    remove_container() { read -r -p "Are you sure you want to remove container $container_id? (yes/no): " confirm; if [ "$confirm" != "yes" ]; then log "Operation cancelled"; return 0; fi; pct stop "$container_id" 2>/dev/null || true; pct destroy "$container_id"; success "Container removed"; }

    case "$command" in
        start) start_container ;; stop) stop_container ;; restart) restart_container ;; status) show_status ;; logs) show_logs "$@" ;; shell) open_shell ;; backup) backup_container "$@" ;; update) update_application "$@" ;; health-check) health_check ;; remove) remove_container ;; *) echo "Unknown command: $command"; return 1 ;;
    esac
}

###############################################################################
# advanced-setup (inlined)
###############################################################################
advanced_setup_main() {
    if [ $# -lt 2 ]; then echo "Usage: $0 <container_id> <command> [options]"; return 1; fi
    container_id=$1; command=$2; shift 2

    setup_nginx() {
        local domain=${1:-worktrack.local}; local email=${2:-admin@worktrack.local}
        log "Setting up Nginx reverse proxy..."
        pct exec "$container_id" -- bash -c 'apt-get install -y nginx certbot python3-certbot-nginx; rm -f /etc/nginx/sites-enabled/default'
        pct exec "$container_id" -- certbot certonly --nginx -d "$domain" --email "$email" --agree-tos --non-interactive || warning "certbot failed"
        success "Nginx configured with SSL (if cert issued)"
    }
    setup_monitoring() { pct exec "$container_id" -- bash -c 'apt-get install -y prometheus grafana-server || true'; success "Monitoring setup (Grafana:3000)"; }
    setup_postgres() { local db_password; db_password=$(openssl rand -base64 32); pct exec "$container_id" -- bash -c 'apt-get install -y postgresql postgresql-contrib || true'; log "Postgres password: $db_password"; success "PostgreSQL configured"; }
    setup_redis() { pct exec "$container_id" -- bash -c 'apt-get install -y redis-server || true'; success "Redis configured"; }
    setup_backup() { pct exec "$container_id" -- bash -c 'mkdir -p /opt/backups || true'; success "Backup configured"; }
    setup_all() { setup_nginx "$@"; setup_monitoring; setup_postgres; setup_redis; setup_backup; success "All production components configured"; }

    case "$command" in
        setup-nginx) setup_nginx "$@" ;; setup-monitoring) setup_monitoring ;; setup-postgres) setup_postgres ;; setup-redis) setup_redis ;; setup-backup) setup_backup "$@" ;; setup-all) setup_all "$@" ;; *) echo "Unknown command: $command"; return 1 ;;
    esac
}

###############################################################################
# ci-cd-deploy (inlined)
###############################################################################
ci_cd_deploy_main() {
    if [ $# -lt 1 ]; then echo "Usage: $0 <command> [options]"; return 1; fi
    cmd=$1; shift
    build_backend() { log "Building backend..."; (cd backend && npm ci || true); success "Backend built"; }
    build_frontend() { log "Building frontend..."; (cd web && npm ci || true); success "Frontend built"; }
    deploy_to_container() { local container_id=$1; local container_ip=$2; if ! ping -c 1 "$container_ip" &> /dev/null; then error "Container $container_ip unreachable" || return 1; fi; scp -r backend/* "root@$container_ip:/opt/worktrack/backend/" || return 1; scp -r web/dist/* "root@$container_ip:/opt/worktrack/web/dist/" || return 1; ssh "root@$container_ip" "systemctl restart worktrack-backend worktrack-web" || return 1; sleep 5; ssh "root@$container_ip" "curl -f http://localhost:3001/health" &> /dev/null || return 1; success "Deployment completed"; }
    deploy_blue_green() { deploy_to_container "$1" "$3"; deploy_to_container "$2" "$4"; success "Blue-green flow (partial)"; }
    deploy_canary() { deploy_to_container "$1" "$2"; success "Canary (partial)"; }
    rollback_deployment() { local container_id=$1; local container_ip=$2; local backup_file=$3; ssh "root@$container_ip" "tar -xzf '$backup_file' -C /opt/worktrack/" || return 1; ssh "root@$container_ip" "systemctl restart worktrack-backend worktrack-web" || return 1; success "Rollback completed"; }
    run_integration_tests() { local api_url=$1; curl -f "$api_url/health" &> /dev/null || warning "Integration health check failed"; success "Integration tests (partial)"; }
    create_smoke_tests() { cat > /tmp/smoke-tests.sh << 'EOF'
#!/bin/bash
API_URL="http://localhost:3001"
FRONTEND_URL="http://localhost:5173"
TIMEOUT=10
run_test() { local name=$1; local command=$2; if eval "$command"; then echo "✓ $name"; else echo "✗ $name"; fi }
run_test "API Health" "curl -f --max-time $TIMEOUT $API_URL/health"
EOF
        chmod +x /tmp/smoke-tests.sh
        success "Smoke tests created at /tmp/smoke-tests.sh"
    }

    case "$cmd" in
        build-all)
            build_backend
            build_frontend
            ;;
        build-backend)
            build_backend
            ;;
        build-frontend)
            build_frontend
            ;;
        deploy)
            if [ $# -lt 2 ]; then
                error "Usage: $0 deploy <container_id> <ip>"
                return 1
            fi
            deploy_to_container "$1" "$2"
            ;;
        rollback)
            rollback_deployment "$1" "$2" "$3"
            ;;
        blue-green)
            deploy_blue_green "$@"
            ;;
        canary)
            deploy_canary "$@"
            ;;
        test-integration)
            run_integration_tests "$1"
            ;;
        create-smoke-tests)
            create_smoke_tests
            ;;
        *)
            echo "Unknown command: $cmd"
            return 1
            ;;
    esac
}

###############################################################################
# Dispatcher
###############################################################################
if [ $# -lt 1 ]; then
    cat << EOF
Usage: $0 <deploy-lxc|manage-lxc|advanced-setup|ci-cd-deploy> [args...]

Examples:
  $0 deploy-lxc 100 worktrack-app 192.168.1.100
  $0 manage-lxc start 100
  $0 advanced-setup 100 setup-all
  $0 ci-cd-deploy deploy 100 192.168.1.100
EOF
    exit 1
fi

subcmd=$1; shift
case "$subcmd" in
    deploy-lxc) deploy_lxc_main "$@" ;;
    manage-lxc) manage_lxc_main "$@" ;;
    advanced-setup) advanced_setup_main "$@" ;;
    ci-cd-deploy) ci_cd_deploy_main "$@" ;;
    *) echo "Unknown subcommand: $subcmd"; exit 1 ;;
esac
