# WorkTrack Operations Guide

Complete guide for deploying, managing, and maintaining WorkTrack in production environments.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Deployment Phases](#deployment-phases)
3. [Production Configuration](#production-configuration)
4. [Monitoring & Logging](#monitoring--logging)
5. [Backup & Recovery](#backup--recovery)
6. [Troubleshooting](#troubleshooting)
7. [Security Hardening](#security-hardening)
8. [Performance Tuning](#performance-tuning)

---

## Quick Start

### 1. Deploy Base LXC Container
```bash
./deploy-lxc.sh \
  100 \                    # Container ID
  worktrack-app \          # Container name
  192.168.1.100 \          # IP address
  24 \                     # CIDR (subnet mask)
  192.168.1.1 \            # Gateway
  local \                  # Storage pool
  2048 \                   # Memory (MB)
  2 \                      # CPU cores
  pve                      # Proxmox node
```

### 2. Enter Container
```bash
./manage-lxc.sh 100 shell
```

### 3. Deploy Application
```bash
# Copy application code
scp -r backend root@192.168.1.100:/opt/worktrack/
scp -r web root@192.168.1.100:/opt/worktrack/

# Inside container, start services
systemctl start worktrack-backend worktrack-web

# Verify
curl http://localhost:3001/auth/session
curl http://localhost:5173
```

### 4. Setup Production Features
```bash
# Setup all production components (SSL, monitoring, backups)
./advanced-setup.sh 100 setup-all

# Or individually:
./advanced-setup.sh 100 setup-nginx example.com admin@example.com
./advanced-setup.sh 100 setup-postgres
./advanced-setup.sh 100 setup-redis
./advanced-setup.sh 100 setup-monitoring
./advanced-setup.sh 100 setup-backup
```

---

## Deployment Phases

### Phase 1: Infrastructure Setup
- LXC container creation
- Network configuration
- Resource allocation
- SSH access

**Validation Points:**
```bash
pct status 100                    # Container running?
pct exec 100 -- ip addr           # IP assigned?
ping 192.168.1.100                # Network reachable?
```

### Phase 2: Application Deployment
- Backend (Express + SQLite)
- Frontend (React/Vite)
- Systemd service configuration
- Node.js/npm setup

**Validation Points:**
```bash
systemctl status worktrack-backend
systemctl status worktrack-web
curl -I http://localhost:3001
curl -I http://localhost:5173
```

### Phase 3: Production Hardening
- Nginx reverse proxy with SSL
- UFW firewall rules
- SSH key hardening
- Rate limiting

**Configuration:**
```bash
# Frontend accessed via: https://example.com
# Backend API via: https://example.com/api

# Firewall rules applied:
# - SSH: 22/tcp
# - HTTP: 80/tcp (redirects to HTTPS)
# - HTTPS: 443/tcp
# - Internal services (3001, 5173): Blocked externally
```

### Phase 4: Database Setup
- PostgreSQL (recommended for production)
- Migration from SQLite
- Automated backups
- Connection pooling

**Migration Steps:**
```bash
# Connect to container
./manage-lxc.sh 100 shell

# Backup existing SQLite
tar -czf /tmp/sqlite-backup-$(date +%Y%m%d).tar.gz /opt/worktrack/data

# Run PostgreSQL setup
/usr/local/bin/advanced-setup.sh 100 setup-postgres

# Update backend .env
echo "DATABASE_URL=postgresql://worktrack:PASSWORD@localhost/worktrack" >> /opt/worktrack/backend/.env

# Restart backend
systemctl restart worktrack-backend
```

### Phase 5: Caching & Session Management
- Redis setup
- Session store configuration
- Cache invalidation strategy

**Configuration:**
```bash
# Backend .env
REDIS_URL=redis://localhost:6379
SESSION_STORE=redis
```

### Phase 6: Monitoring & Alerting
- Prometheus metrics collection
- Grafana dashboards
- Alert rules
- Log aggregation

**Access Points:**
- Grafana: https://example.com:3000
- Prometheus: https://example.com:9090

---

## Production Configuration

### SSL/TLS with Let's Encrypt
```bash
./advanced-setup.sh 100 setup-nginx example.com admin@example.com
```

**Renewal (automatic):**
```bash
systemctl status certbot.timer    # Check timer status
systemctl list-timers --all       # Show all timers
```

### Environment Variables
Create `.env` files in container:

**Backend (.env):**
```env
# Server
NODE_ENV=production
PORT=3001

# Database
DATABASE_URL=postgresql://worktrack:PASSWORD@localhost/worktrack

# Redis
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=<random-32-char-string>
JWT_EXPIRY=86400

# OAuth
GOOGLE_CLIENT_ID=<your-client-id>
GOOGLE_CLIENT_SECRET=<your-secret>
GITHUB_CLIENT_ID=<your-client-id>
GITHUB_CLIENT_SECRET=<your-secret>

# SAML
SAML_ENTRY_POINT=https://idp.example.com/sso
SAML_ISSUER=worktrack-app

# Security
CORS_ORIGIN=https://example.com
SESSION_SECRET=<random-32-char-string>

# Logging
LOG_LEVEL=info
AUDIT_LOG_ENABLED=true
```

**Frontend (.env):**
```env
VITE_API_URL=https://example.com/api
VITE_APP_NAME=WorkTrack
VITE_ENVIRONMENT=production
```

### Systemd Service Configuration
Services installed in container:

**worktrack-backend.service:**
```
[Service]
Type=simple
ExecStart=node /opt/worktrack/backend/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
```

**worktrack-web.service:**
```
[Service]
Type=simple
ExecStart=npm run preview --prefix /opt/worktrack/web
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
```

---

## Monitoring & Logging

### Service Health Checks
```bash
# Check all WorkTrack services
./manage-lxc.sh 100 health-check

# Individual service status
systemctl status worktrack-backend
systemctl status worktrack-web
systemctl status nginx
systemctl status postgresql

# View logs
./manage-lxc.sh 100 logs

# Real-time logs
./manage-lxc.sh 100 shell
journalctl -u worktrack-backend -f
```

### Prometheus Metrics
Access Prometheus dashboard:
```
http://192.168.1.100:9090
```

**Key Metrics:**
- `node_cpu_seconds_total` - CPU usage
- `node_memory_MemAvailable_bytes` - Memory available
- `node_disk_read_bytes_total` - Disk I/O
- `worktrack_api_request_duration_ms` - API latency
- `worktrack_database_queries_total` - DB query count

### Grafana Dashboards
```
https://192.168.1.100:3000
```

**Default Credentials:**
- Username: admin
- Password: admin (change on first login)

**Pre-configured Dashboards:**
1. System Overview (CPU, Memory, Disk)
2. Backend Performance (API latency, throughput)
3. Database (Query performance, connection pool)
4. Nginx (Requests, response times, errors)

### Application Logging
Logs stored in container:
```bash
# Backend logs
journalctl -u worktrack-backend -n 100

# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# System logs
journalctl -n 50 --no-pager
```

---

## Backup & Recovery

### Automated Backups
Configured by `advanced-setup.sh`:
- **Frequency:** Daily at 2:00 AM
- **Location:** `/opt/backups/`
- **Retention:** Last 7 days
- **Contents:** Database + application files

```bash
# Manual backup
/usr/local/bin/worktrack-backup.sh

# List backups
ls -lah /opt/backups/

# Restore from backup
tar -xzf /opt/backups/worktrack-20240129_020000.tar.gz -C /
```

### Container-Level Backups
```bash
# Backup entire container
pct backup 100 /mnt/backups/

# List backups
ls -lah /mnt/backups/

# Restore
pct restore <backup_file> 101  # Restore to new container ID 101
```

### Database Backups
```bash
# Connect to container
./manage-lxc.sh 100 shell

# PostgreSQL backup
pg_dump -U worktrack worktrack > /tmp/worktrack-db-$(date +%Y%m%d).sql

# PostgreSQL restore
psql -U worktrack worktrack < /tmp/worktrack-db-20240129.sql

# SQLite backup
cp /opt/worktrack/data/db.sqlite /tmp/db-backup-$(date +%Y%m%d).sqlite
```

### Disaster Recovery Runbook
1. **Complete container failure:**
   ```bash
   pct restore /mnt/backups/worktrack-backup.tar.zst 100
   ```

2. **Database corruption:**
   ```bash
   ./manage-lxc.sh 100 shell
   systemctl stop worktrack-backend
   psql -U worktrack worktrack < /tmp/worktrack-db-backup.sql
   systemctl start worktrack-backend
   ```

3. **Application code corruption:**
   ```bash
   tar -xzf /opt/backups/worktrack-latest.tar.gz -C /opt/worktrack/
   systemctl restart worktrack-backend worktrack-web
   ```

---

## Troubleshooting

### Backend Service Won't Start
```bash
# Check service status
systemctl status worktrack-backend

# View full logs
journalctl -u worktrack-backend -n 50

# Test manually
cd /opt/worktrack/backend
node server.js

# Common issues:
# - PORT already in use: lsof -i :3001
# - Missing .env: cat /opt/worktrack/backend/.env
# - DB connection: npm test
```

### Frontend Not Responding
```bash
# Check service
systemctl status worktrack-web

# Check port 5173
netstat -tlnp | grep 5173

# Rebuild frontend
cd /opt/worktrack/web
npm install
npm run build

# Restart
systemctl restart worktrack-web
```

### High Memory Usage
```bash
# Check memory
free -h

# Process memory
ps aux --sort=-%mem | head -20

# If backend consuming too much:
systemctl restart worktrack-backend

# Check for memory leaks
journalctl -u worktrack-backend | grep "OutOfMemory"
```

### Database Connection Issues
```bash
# Test PostgreSQL connection
psql -h localhost -U worktrack -d worktrack -c "SELECT 1;"

# Check connection pool
psql -U postgres -c "SELECT datname, usename, count(*) FROM pg_stat_activity GROUP BY datname, usename;"

# View backend logs for DB errors
journalctl -u worktrack-backend | grep -i "database\|connection"
```

### Nginx SSL Certificate Issues
```bash
# Check certificate expiration
certbot certificates

# Renew manually
certbot renew

# Test SSL
openssl s_client -connect example.com:443 -showcerts
```

### High Disk Usage
```bash
# Check disk usage
df -h

# Find large files
du -sh /opt/worktrack/* | sort -hr

# Check log rotation
ls -lah /var/log/worktrack-backup.log

# Cleanup old backups
find /opt/backups -name "worktrack-*.tar.gz" -mtime +30 -delete
```

---

## Security Hardening

### SSH Hardening
```bash
# On Proxmox host, already configured by deploy-lxc.sh:
# - Disabled password auth (keys only)
# - Changed default port if desired
# - SSH keys in /root/.ssh/authorized_keys

# Add additional key
pct exec 100 -- bash -c 'echo "ssh-rsa YOUR_PUBLIC_KEY" >> /root/.ssh/authorized_keys'
```

### Firewall Rules (UFW)
```bash
# Connect to container
./manage-lxc.sh 100 shell

# View firewall rules
ufw status verbose

# Expected rules:
# 22/tcp    ALLOW  IN  192.168.1.0/24  # SSH from internal network only
# 80/tcp    ALLOW  IN  Anywhere        # HTTP (redirects to HTTPS)
# 443/tcp   ALLOW  IN  Anywhere        # HTTPS
# 3001/tcp  DENY   IN  Anywhere        # Backend (internal only)
```

### Rate Limiting
Configured in Nginx:
- API endpoints: 10 req/s per IP
- Web endpoints: 30 req/s per IP
- Auth endpoints: 5 req/s per IP

```bash
# Monitor rate limiting
tail -f /var/log/nginx/error.log | grep "limiting requests"
```

### JWT Security
```bash
# Generate secure JWT_SECRET
openssl rand -base64 32

# Update backend .env
echo "JWT_SECRET=$(openssl rand -base64 32)" >> /opt/worktrack/backend/.env

# Restart
systemctl restart worktrack-backend
```

### CORS Configuration
```env
# Backend .env
CORS_ORIGIN=https://example.com

# Nginx config (advanced-setup.sh handles this)
add_header Access-Control-Allow-Origin "https://example.com";
```

### Audit Logging
```bash
# View audit logs
tail -f /var/log/worktrack-audit.log

# Backend generates audit entries for:
# - User authentication
# - Workouts created/modified/deleted
# - Admin actions
# - Security events (failed auth attempts, etc.)
```

---

## Performance Tuning

### PostgreSQL Optimization
```bash
# Connect to container
./manage-lxc.sh 100 shell

# Increase shared buffers (edit postgresql.conf)
sed -i 's/shared_buffers = .*/shared_buffers = 256MB/' /etc/postgresql/*/main/postgresql.conf

# Increase work memory
sed -i 's/work_mem = .*/work_mem = 16MB/' /etc/postgresql/*/main/postgresql.conf

# Enable connection pooling with PgBouncer
apt-get install -y pgbouncer

# Restart
systemctl restart postgresql
systemctl restart pgbouncer
```

### Redis Optimization
```bash
# Increase maxmemory
redis-cli CONFIG SET maxmemory 512mb

# Set eviction policy
redis-cli CONFIG SET maxmemory-policy allkeys-lru

# Enable persistence
redis-cli CONFIG SET appendonly yes
```

### Nginx Optimization
```bash
# Increase worker processes (edit nginx.conf)
worker_processes auto;
worker_connections 4096;

# Enable gzip compression
gzip on;
gzip_types text/plain application/json application/javascript;
gzip_min_length 1000;

# Reload
nginx -s reload
```

### Node.js Optimization
```bash
# Add to backend .env
NODE_OPTIONS="--max-old-space-size=1024"

# In server.js, add clustering
const cluster = require('cluster');
const numCPUs = require('os').cpus().length;

if (cluster.isMaster) {
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }
}
```

### Container Resource Limits
```bash
# Update LXC config
pct set 100 --cores 4 --memory 4096 --swap 1024

# Monitor resource usage
pct config 100 | grep -E "cores|memory|swap"

# Check current usage
pct exec 100 -- bash -c "free -h; nproc"
```

---

## Scaling Strategies

### Horizontal Scaling
Deploy multiple WorkTrack instances behind load balancer:
```
Client → Nginx Load Balancer → WorkTrack-1 (LXC 100)
                              → WorkTrack-2 (LXC 101)
                              → WorkTrack-3 (LXC 102)
                              ↓
                           PostgreSQL (shared)
                           Redis (shared)
```

```bash
# Deploy second instance
./deploy-lxc.sh 101 worktrack-app2 192.168.1.101 24 192.168.1.1 local 2048 2 pve

# Configure Nginx load balancer on Proxmox host
upstream worktrack_backend {
    server 192.168.1.100:3001;
    server 192.168.1.101:3001;
}

upstream worktrack_frontend {
    server 192.168.1.100:5173;
    server 192.168.1.101:5173;
}
```

### Vertical Scaling
Increase resources on single container:
```bash
# Double resources
pct set 100 --cores 8 --memory 8192

# Monitor impact
./manage-lxc.sh 100 health-check
```

---

## Maintenance Windows

### Regular Maintenance Schedule
- **Daily:** Automated backups (2 AM)
- **Weekly:** Update OS packages (Sunday 3 AM)
- **Monthly:** Security patching (1st Sunday)
- **Quarterly:** Full system backup + disaster recovery test

### Update Procedure
```bash
# Enter container
./manage-lxc.sh 100 shell

# Update packages
apt-get update && apt-get upgrade -y

# Update Node.js packages
cd /opt/worktrack/backend && npm update
cd /opt/worktrack/web && npm update

# Restart services
systemctl restart worktrack-backend worktrack-web

# Verify
curl http://localhost:3001/health
curl http://localhost:5173
```

### Rollback Procedure
```bash
# If update fails, restore from backup
tar -xzf /opt/backups/worktrack-backup-pre-update.tar.gz -C /

# Restart
systemctl restart worktrack-backend worktrack-web
```

---

## Support & Escalation

### Logs to Collect for Support
```bash
# System logs
journalctl -u worktrack-backend -n 200 > backend-logs.txt
journalctl -u worktrack-web -n 200 > web-logs.txt

# Configuration
cat /opt/worktrack/backend/.env | grep -v SECRET > backend-config.txt
cat /opt/worktrack/web/.env > web-config.txt

# System info
uname -a > system-info.txt
free -h >> system-info.txt
df -h >> system-info.txt

# Services
systemctl status worktrack-backend worktrack-web > services-status.txt
```

### Emergency Contacts
- On-call DevOps: [contact info]
- Database Administrator: [contact info]
- Security Team: [contact info]

---

## Version History

- **1.0** (Jan 29, 2024) - Initial release with deploy-lxc, manage-lxc, advanced-setup
- Infrastructure: LXC + systemd + Nginx + PostgreSQL + Redis + Prometheus
- Includes SSL/TLS, automated backups, monitoring dashboards

