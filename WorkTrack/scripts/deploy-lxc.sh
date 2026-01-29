#!/bin/bash

###############################################################################
# WorkTrack Proxmox LXC Deployment Script
# Deploys a complete WorkTrack environment on Proxmox LXC container
###############################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
CONTAINER_ID="${1:-100}"
CONTAINER_NAME="${2:-worktrack-app}"
CONTAINER_IP="${3:-192.168.1.100}"
CONTAINER_NETMASK="${4:-24}"
CONTAINER_GATEWAY="${5:-192.168.1.1}"
STORAGE_POOL="${6:-local}"
CONTAINER_MEMORY="${7:-2048}"
CONTAINER_CORES="${8:-2}"
PROXMOX_HOST="${9:-pve}"

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Creates and configures a Proxmox LXC container with WorkTrack stack

OPTIONS:
    Container ID       (default: 100)
    Container name     (default: worktrack-app)
    IP address         (default: 192.168.1.100)
    Netmask            (default: 24)
    Gateway            (default: 192.168.1.1)
    Storage pool       (default: local)
    Memory MB          (default: 2048)
    CPU cores          (default: 2)
    Proxmox host       (default: pve)

EXAMPLE:
    $0 100 worktrack-app 192.168.1.100 24 192.168.1.1 local 2048 2 pve

EOF
}

###############################################################################
# Phase 1: Validation
###############################################################################

validate_proxmox() {
    log "Validating Proxmox environment..."
    
    if ! command -v pvesh &> /dev/null; then
        error "Proxmox tools not found. Run this script on a Proxmox node."
    fi
    
    if ! command -v pct &> /dev/null; then
        error "LXC tools (pct) not found."
    fi
    
    success "Proxmox tools validated"
}

check_container_exists() {
    log "Checking if container $CONTAINER_ID already exists..."
    
    if pct status "$CONTAINER_ID" &> /dev/null; then
        error "Container $CONTAINER_ID already exists. Please choose a different ID or remove existing container."
    fi
    
    success "Container ID $CONTAINER_ID is available"
}

check_storage() {
    log "Validating storage pool '$STORAGE_POOL'..."
    
    if ! pvesh get /storage/"$STORAGE_POOL" &> /dev/null; then
        error "Storage pool '$STORAGE_POOL' not found on Proxmox node."
    fi
    
    success "Storage pool validated"
}

###############################################################################
# Phase 2: LXC Container Creation
###############################################################################

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

###############################################################################
# Phase 3: Container Setup
###############################################################################

setup_container() {
    log "Setting up container $CONTAINER_ID..."
    
    # Update package lists
    log "Updating package manager..."
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
    log "Installing Node.js 18+..."
    
    pct exec "$CONTAINER_ID" -- bash -c '
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
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

###############################################################################
# Phase 4: Application Deployment
###############################################################################

create_app_directories() {
    log "Creating application directories..."
    
    pct exec "$CONTAINER_ID" -- mkdir -p /opt/worktrack/{backend,web,data}
    
    success "Application directories created"
}

setup_backend() {
    log "Setting up backend service..."
    
    pct exec "$CONTAINER_ID" -- bash -c '
        cat > /opt/worktrack/backend/.env << "ENVEOF"
NODE_ENV=production
PORT=3001
FRONTEND_URL=http://'"$CONTAINER_IP"':5173
JWT_SECRET='"$(openssl rand -base64 32)"'
SESSION_SECRET='"$(openssl rand -base64 32)"'
SAML_ENTRY_POINT=https://your-idp.example.com/sso
ENVEOF
    '
    
    success "Backend environment configured"
}

setup_web() {
    log "Setting up web service..."
    
    pct exec "$CONTAINER_ID" -- bash -c '
        cat > /opt/worktrack/web/.env << "ENVEOF"
REACT_APP_OAUTH_CLIENT_ID=your-oauth-client-id
REACT_APP_API_URL=http://'"$CONTAINER_IP"':3001
ENVEOF
    '
    
    success "Web environment configured"
}

create_systemd_services() {
    log "Creating systemd service files..."
    
    # Backend service
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
    
    # Web service (using simple HTTP server)
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

###############################################################################
# Phase 5: Security Configuration
###############################################################################

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
        # Disable root SSH login
        sed -i "s/#PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
        
        # Change SSH port to non-standard (optional)
        # sed -i "s/#Port 22/Port 2222/" /etc/ssh/sshd_config
        
        # Disable password authentication (optional, use SSH keys)
        # sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
        
        systemctl restart sshd
    '
    
    success "Security hardening applied"
}

###############################################################################
# Phase 6: Health Checks
###############################################################################

verify_container() {
    log "Verifying container status..."
    
    local status=$(pct status "$CONTAINER_ID" | awk '{print $2}')
    
    if [ "$status" != "running" ]; then
        error "Container is not running. Status: $status"
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

###############################################################################
# Phase 7: Post-Deployment Instructions
###############################################################################

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

1. ${YELLOW}Copy application files to container:${NC}
   scp -r ./backend root@${CONTAINER_IP}:/opt/worktrack/
   scp -r ./web root@${CONTAINER_IP}:/opt/worktrack/

2. ${YELLOW}Install backend dependencies:${NC}
   ssh root@${CONTAINER_IP}
   cd /opt/worktrack/backend && npm install

3. ${YELLOW}Build web application:${NC}
   cd /opt/worktrack/web && npm install && npm run build

4. ${YELLOW}Start services:${NC}
   systemctl start worktrack-backend
   systemctl start worktrack-web
   systemctl enable worktrack-backend
   systemctl enable worktrack-web

5. ${YELLOW}Access the application:${NC}
   Web Dashboard:  http://${CONTAINER_IP}:5173
   Backend API:    http://${CONTAINER_IP}:3001

${BLUE}Security Reminders:${NC}
  ✓ Configure OAuth providers with callback URL: http://${CONTAINER_IP}:5173/auth/callback
  ✓ Set strong JWT_SECRET and SESSION_SECRET (.env files)
  ✓ Configure SAML entry point if needed
  ✓ Set up firewall rules for production
  ✓ Consider using reverse proxy (nginx) for HTTPS

${BLUE}SSH Access:${NC}
   ssh root@${CONTAINER_IP}

${BLUE}Logs:${NC}
   Backend:  journalctl -u worktrack-backend -f
   Web:      journalctl -u worktrack-web -f

${GREEN}════════════════════════════════════════════════════════════${NC}

EOF
}

###############################################################################
# Main Execution Flow
###############################################################################

main() {
    log "Starting WorkTrack Proxmox LXC Deployment"
    log "Container ID: $CONTAINER_ID, Name: $CONTAINER_NAME"
    
    # Phase 1: Validation
    validate_proxmox
    check_container_exists
    check_storage
    
    # Phase 2: LXC Container Creation
    create_lxc_container
    start_container
    
    # Phase 3: Container Setup
    setup_container
    install_dependencies
    install_nodejs
    install_docker
    install_sqlite3
    
    # Phase 4: Application Deployment
    create_app_directories
    setup_backend
    setup_web
    create_systemd_services
    
    # Phase 5: Security Configuration
    setup_firewall
    setup_security_hardening
    
    # Phase 6: Health Checks
    verify_container
    verify_services
    
    # Phase 7: Summary
    print_deployment_summary
}

# Run main function
main "$@"
