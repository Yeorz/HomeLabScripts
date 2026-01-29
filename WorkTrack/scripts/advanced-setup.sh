#!/bin/bash

###############################################################################
# WorkTrack Advanced Configuration Script
# Sets up production-grade environment inside deployed LXC
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

usage() {
    cat << EOF
Usage: $0 <container_id> <command> [options]

Commands:
  setup-nginx           Setup Nginx reverse proxy with SSL
  setup-monitoring      Setup Prometheus & Grafana monitoring
  setup-logging         Setup ELK stack (Elasticsearch, Logstash, Kibana)
  setup-postgres        Replace SQLite with PostgreSQL
  setup-redis           Setup Redis for caching
  setup-backup          Configure automated backups
  setup-all             Run all setups

Examples:
  $0 100 setup-nginx
  $0 100 setup-postgres
  $0 100 setup-all

EOF
}

# Setup Nginx as reverse proxy
setup_nginx() {
    local container_id=$1
    local domain=${2:-worktrack.local}
    local email=${3:-admin@worktrack.local}
    
    log "Setting up Nginx reverse proxy..."
    
    pct exec "$container_id" -- bash -c '
        apt-get install -y nginx certbot python3-certbot-nginx
        
        # Create nginx config
        cat > /etc/nginx/sites-available/worktrack << "NGINXEOF"
upstream backend {
    server localhost:3001;
}

upstream frontend {
    server localhost:5173;
}

server {
    listen 80;
    server_name '"$domain"';
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name '"$domain"';
    
    # SSL configuration (will be auto-filled by certbot)
    ssl_certificate /etc/letsencrypt/live/'"$domain"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$domain"'/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=web:10m rate=30r/s;
    
    # API endpoints
    location /api {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 30s;
    }
    
    # Auth endpoints
    location /auth {
        limit_req zone=api burst=5 nodelay;
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Analytics endpoints
    location /analytics {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # All backend routes
    location /workouts {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Frontend
    location / {
        limit_req zone=web burst=50 nodelay;
        proxy_pass http://frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
NGINXEOF
        
        ln -sf /etc/nginx/sites-available/worktrack /etc/nginx/sites-enabled/worktrack
        rm -f /etc/nginx/sites-enabled/default
        
        nginx -t
        systemctl restart nginx
    '
    
    log "Requesting SSL certificate..."
    pct exec "$container_id" -- certbot certonly --nginx -d "$domain" --email "$email" --agree-tos --non-interactive
    
    success "Nginx configured with SSL"
}

# Setup Monitoring with Prometheus
setup_monitoring() {
    local container_id=$1
    
    log "Setting up Prometheus monitoring..."
    
    pct exec "$container_id" -- bash -c '
        apt-get install -y prometheus grafana-server
        
        # Configure Prometheus
        cat > /etc/prometheus/prometheus.yml << "PROMEOF"
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: node
    static_configs:
      - targets: ["localhost:9100"]
  
  - job_name: backend
    metrics_path: /metrics
    static_configs:
      - targets: ["localhost:3001"]
PROMEOF
        
        systemctl enable prometheus
        systemctl restart prometheus
        
        systemctl enable grafana-server
        systemctl restart grafana-server
    '
    
    success "Monitoring setup completed (Grafana: port 3000)"
}

# Setup PostgreSQL
setup_postgres() {
    local container_id=$1
    local db_password=$(openssl rand -base64 32)
    
    log "Setting up PostgreSQL database..."
    
    pct exec "$container_id" -- bash -c '
        apt-get install -y postgresql postgresql-contrib
        
        # Create database and user
        sudo -u postgres psql << "SQLEOF"
CREATE DATABASE worktrack;
CREATE USER worktrack WITH PASSWORD '"'"'$db_password'"'"';
ALTER ROLE worktrack SET client_encoding TO '"'"'utf8'"'"';
ALTER ROLE worktrack SET default_transaction_isolation TO '"'"'read committed'"'"';
ALTER ROLE worktrack SET default_transaction_deferrable TO on;
ALTER ROLE worktrack SET default_transaction_read_only TO off;
GRANT ALL PRIVILEGES ON DATABASE worktrack TO worktrack;
SQLEOF
        
        systemctl enable postgresql
        systemctl restart postgresql
    '
    
    log "PostgreSQL password: $db_password"
    success "PostgreSQL configured"
}

# Setup Redis for caching
setup_redis() {
    local container_id=$1
    
    log "Setting up Redis..."
    
    pct exec "$container_id" -- bash -c '
        apt-get install -y redis-server
        
        # Configure Redis
        cat >> /etc/redis/redis.conf << "REDISEOF"
# Worktrack configuration
maxmemory 256mb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
REDISEOF
        
        systemctl enable redis-server
        systemctl restart redis-server
    '
    
    success "Redis configured"
}

# Setup automated backups
setup_backup() {
    local container_id=$1
    local backup_path=${2:-/opt/backups}
    
    log "Setting up automated backups..."
    
    pct exec "$container_id" -- bash -c '
        mkdir -p '"$backup_path"'
        
        # Create backup script
        cat > /usr/local/bin/worktrack-backup.sh << "BACKUPEOF"
#!/bin/bash
BACKUP_DIR='"$backup_path"'
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE=\$BACKUP_DIR/worktrack-\$TIMESTAMP.tar.gz

mkdir -p \$BACKUP_DIR

# Backup database
tar -czf \$BACKUP_FILE /opt/worktrack/data /opt/worktrack/backend/.env

# Keep only last 7 backups
find \$BACKUP_DIR -name "worktrack-*.tar.gz" -mtime +7 -delete

echo "Backup completed: \$BACKUP_FILE"
BACKUPEOF
        
        chmod +x /usr/local/bin/worktrack-backup.sh
        
        # Add cron job for daily backups at 2 AM
        cat >> /etc/crontab << "CRONEOF"
0 2 * * * /usr/local/bin/worktrack-backup.sh >> /var/log/worktrack-backup.log 2>&1
CRONEOF
    '
    
    success "Backup configured (daily at 2 AM)"
}

# Setup complete stack
setup_all() {
    local container_id=$1
    
    log "Running complete production setup..."
    
    setup_nginx "$container_id"
    setup_monitoring "$container_id"
    setup_postgres "$container_id"
    setup_redis "$container_id"
    setup_backup "$container_id"
    
    success "All production components configured"
}

# Main
if [ $# -lt 2 ]; then
    usage
    exit 1
fi

container_id=$1
command=$2
shift 2

case "$command" in
    setup-nginx)
        setup_nginx "$container_id" "$@"
        ;;
    setup-monitoring)
        setup_monitoring "$container_id"
        ;;
    setup-postgres)
        setup_postgres "$container_id"
        ;;
    setup-redis)
        setup_redis "$container_id"
        ;;
    setup-backup)
        setup_backup "$container_id" "$@"
        ;;
    setup-all)
        setup_all "$container_id"
        ;;
    *)
        echo "Unknown command: $command"
        usage
        exit 1
        ;;
esac
