#!/bin/bash

###############################################################################
# WorkTrack Container Management Script
# Manage deployed WorkTrack LXC containers
###############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Show usage
usage() {
    cat << EOF
Usage: $0 <command> <container_id> [options]

Commands:
  start          Start container
  stop           Stop container
  restart        Restart container
  status         Show container status
  logs           Show service logs
  shell          Open shell in container
  backup         Backup container
  update         Update application code
  health-check   Perform health checks
  remove         Remove container

Examples:
  $0 start 100
  $0 logs 100 backend
  $0 shell 100
  $0 backup 100 /backup/path
  $0 health-check 100

EOF
}

# Container commands
start_container() {
    local container_id=$1
    log "Starting container $container_id..."
    pct start "$container_id"
    success "Container started"
}

stop_container() {
    local container_id=$1
    log "Stopping container $container_id..."
    pct stop "$container_id"
    success "Container stopped"
}

restart_container() {
    local container_id=$1
    log "Restarting container $container_id..."
    pct reboot "$container_id"
    success "Container restarted"
}

show_status() {
    local container_id=$1
    log "Status for container $container_id:"
    pct status "$container_id"
    
    log "Service status inside container:"
    pct exec "$container_id" -- systemctl status worktrack-backend worktrack-web || true
}

show_logs() {
    local container_id=$1
    local service=${2:-backend}
    
    if [ "$service" = "backend" ]; then
        log "Backend logs:"
        pct exec "$container_id" -- journalctl -u worktrack-backend -n 50 -f
    elif [ "$service" = "web" ]; then
        log "Web logs:"
        pct exec "$container_id" -- journalctl -u worktrack-web -n 50 -f
    else
        log "All service logs:"
        pct exec "$container_id" -- journalctl -n 100 -f
    fi
}

open_shell() {
    local container_id=$1
    log "Opening shell in container $container_id..."
    pct exec "$container_id" -- /bin/bash
}

backup_container() {
    local container_id=$1
    local backup_path=${2:-/var/lib/vz/images/backups}
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_path"
    
    log "Creating backup of container $container_id..."
    log "Backup location: $backup_path/worktrack-backup-$timestamp"
    
    pct dump "$container_id" "$backup_path/worktrack-backup-$timestamp.tar.zst"
    
    success "Backup completed: $backup_path/worktrack-backup-$timestamp.tar.zst"
}

health_check() {
    local container_id=$1
    local ip=$(pct exec "$container_id" -- hostname -I | awk '{print $1}')
    
    log "Running health checks on container $container_id..."
    
    # Check if container is running
    local status=$(pct status "$container_id" | awk '{print $2}')
    if [ "$status" != "running" ]; then
        error "Container is not running"
    fi
    echo -e "${GREEN}✓${NC} Container is running"
    
    # Check backend service
    log "Checking backend service..."
    if pct exec "$container_id" -- systemctl is-active --quiet worktrack-backend; then
        echo -e "${GREEN}✓${NC} Backend service is running"
        
        # Test API
        if timeout 5 pct exec "$container_id" -- curl -s http://localhost:3001/auth/session > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Backend API is responding"
        else
            echo -e "${YELLOW}⚠${NC} Backend API not responding (might not be fully started)"
        fi
    else
        echo -e "${RED}✗${NC} Backend service is not running"
    fi
    
    # Check web service
    log "Checking web service..."
    if pct exec "$container_id" -- systemctl is-active --quiet worktrack-web; then
        echo -e "${GREEN}✓${NC} Web service is running"
        
        if timeout 5 pct exec "$container_id" -- curl -s http://localhost:5173 > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Web interface is responding"
        else
            echo -e "${YELLOW}⚠${NC} Web interface not responding (might not be fully started)"
        fi
    else
        echo -e "${RED}✗${NC} Web service is not running"
    fi
    
    # Check disk usage
    log "Checking disk usage..."
    pct exec "$container_id" -- df -h /opt/worktrack
    
    # Check memory
    log "Checking memory usage..."
    pct exec "$container_id" -- free -h
    
    success "Health check completed"
}

update_application() {
    local container_id=$1
    local source_dir=${2:-.}
    
    log "Updating application code in container $container_id..."
    
    # This assumes you have direct access to the host
    log "Syncing backend code..."
    rsync -avz --delete "$source_dir/backend/" root@"$(pct exec "$container_id" -- hostname -I | awk '{print $1}'):/opt/worktrack/backend/"
    
    log "Syncing web code..."
    rsync -avz --delete "$source_dir/web/" root@"$(pct exec "$container_id" -- hostname -I | awk '{print $1}'):/opt/worktrack/web/"
    
    log "Reinstalling dependencies..."
    pct exec "$container_id" -- bash -c 'cd /opt/worktrack/backend && npm install'
    pct exec "$container_id" -- bash -c 'cd /opt/worktrack/web && npm install && npm run build'
    
    log "Restarting services..."
    pct exec "$container_id" -- systemctl restart worktrack-backend worktrack-web
    
    success "Application updated and services restarted"
}

remove_container() {
    local container_id=$1
    
    read -p "Are you sure you want to remove container $container_id? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log "Operation cancelled"
        return
    fi
    
    log "Stopping container $container_id..."
    pct stop "$container_id" 2>/dev/null || true
    
    log "Removing container $container_id..."
    pct destroy "$container_id"
    
    success "Container removed"
}

# Main
if [ $# -lt 2 ]; then
    usage
    exit 1
fi

command=$1
container_id=$2
shift 2

case "$command" in
    start)
        start_container "$container_id"
        ;;
    stop)
        stop_container "$container_id"
        ;;
    restart)
        restart_container "$container_id"
        ;;
    status)
        show_status "$container_id"
        ;;
    logs)
        show_logs "$container_id" "$@"
        ;;
    shell)
        open_shell "$container_id"
        ;;
    backup)
        backup_container "$container_id" "$@"
        ;;
    update)
        update_application "$container_id" "$@"
        ;;
    health-check)
        health_check "$container_id"
        ;;
    remove)
        remove_container "$container_id"
        ;;
    *)
        echo "Unknown command: $command"
        usage
        exit 1
        ;;
esac
