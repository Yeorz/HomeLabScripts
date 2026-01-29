# WorkTrack Deployment Scripts - Index

Complete automation suite for deploying, managing, and maintaining WorkTrack in Proxmox LXC environments.

## 📋 Scripts Overview

| Script | Size | Purpose | Status |
|--------|------|---------|--------|
| [deploy-lxc.sh](#deploy-lcxsh) | 13KB | Initial LXC container setup | ✅ Executable |
| [manage-lxc.sh](#manage-lcxsh) | 7KB | Container lifecycle management | ✅ Executable |
| [advanced-setup.sh](#advanced-setupsh) | 9.3KB | Production features (SSL, monitoring, DB) | ✅ Executable |
| [ci-cd-deploy.sh](#ci-cd-deploysh) | 12KB | CI/CD pipeline & deployment strategies | ✅ Executable |
| [README.md](#readmemd) | 6.4KB | Quick start & troubleshooting | 📖 Documentation |
| [OPERATIONS.md](#operationsmd) | 15KB | Complete operations guide | 📖 Documentation |
| [INDEX.md](#this-file) | This file | Script reference | 📖 Documentation |

---

## 📖 Script Reference

### deploy-lxc.sh
**Purpose:** Create and initialize a new LXC container with all WorkTrack components

**Usage:**
```bash
./deploy-lxc.sh <container_id> <name> <ip> <cidr> <gateway> <storage> <memory> <cores> <node>
```

**Parameters:**
- `container_id`: Unique container ID (e.g., 100)
- `name`: Container hostname (e.g., worktrack-app)
- `ip`: Static IP address (e.g., 192.168.1.100)
- `cidr`: Network CIDR (e.g., 24 for /24)
- `gateway`: Network gateway (e.g., 192.168.1.1)
- `storage`: Storage pool name (e.g., local)
- `memory`: RAM in MB (e.g., 2048)
- `cores`: CPU cores (e.g., 2)
- `node`: Proxmox node name (e.g., pve)

**Example:**
```bash
./deploy-lxc.sh 100 worktrack-app 192.168.1.100 24 192.168.1.1 local 2048 2 pve
```

**What it does:**
1. ✅ Validates prerequisites (pvesh, unique ID, storage pool)
2. ✅ Creates LXC container with Ubuntu 22.04
3. ✅ Configures network interface
4. ✅ Starts container
5. ✅ Installs dependencies (Node.js, npm, Docker, SQLite3)
6. ✅ Sets up application directories
7. ✅ Configures systemd services
8. ✅ Hardens security (UFW firewall, SSH)
9. ✅ Verifies deployment

**Output:**
```
Container 100 created: worktrack-app
├─ IP: 192.168.1.100/24
├─ Memory: 2GB
├─ Cores: 2 CPU
├─ Services: backend (3001), web (5173)
├─ Database: SQLite3 (/opt/worktrack/data)
├─ SSH: root@192.168.1.100 (key auth)
├─ Firewall: UFW enabled (SSH, HTTP, HTTPS only)
└─ Status: ✅ Ready for deployment
```

---

### manage-lxc.sh
**Purpose:** Manage container lifecycle and monitor operations

**Usage:**
```bash
./manage-lxc.sh <container_id> <command> [options]
```

**Available Commands:**

| Command | Purpose | Example |
|---------|---------|---------|
| `status` | Check container status | `./manage-lxc.sh 100 status` |
| `start` | Start container | `./manage-lxc.sh 100 start` |
| `stop` | Stop container | `./manage-lxc.sh 100 stop` |
| `restart` | Restart container | `./manage-lxc.sh 100 restart` |
| `logs` | View application logs | `./manage-lxc.sh 100 logs` |
| `shell` | Interactive shell access | `./manage-lxc.sh 100 shell` |
| `health-check` | Verify all services | `./manage-lxc.sh 100 health-check` |
| `backup` | Create container backup | `./manage-lxc.sh 100 backup` |
| `update` | Update packages | `./manage-lxc.sh 100 update` |
| `remove` | Delete container | `./manage-lxc.sh 100 remove` |

**Examples:**
```bash
# Check if container is running
./manage-lxc.sh 100 status

# View service logs
./manage-lxc.sh 100 logs

# Access container shell
./manage-lxc.sh 100 shell

# Backup before updates
./manage-lxc.sh 100 backup

# Run health checks
./manage-lxc.sh 100 health-check

# Update system packages
./manage-lxc.sh 100 update
```

---

### advanced-setup.sh
**Purpose:** Configure production-grade infrastructure components

**Usage:**
```bash
./advanced-setup.sh <container_id> <command> [options]
```

**Available Commands:**

| Command | Options | Purpose |
|---------|---------|---------|
| `setup-nginx` | `<domain> [email]` | Install Nginx reverse proxy with SSL |
| `setup-monitoring` | — | Deploy Prometheus + Grafana |
| `setup-postgres` | — | Install PostgreSQL + migration |
| `setup-redis` | — | Install Redis caching layer |
| `setup-backup` | `[backup_path]` | Configure automated backups |
| `setup-all` | — | Run all setups |

**Examples:**
```bash
# Setup SSL/reverse proxy
./advanced-setup.sh 100 setup-nginx example.com admin@example.com

# Install PostgreSQL (replaces SQLite)
./advanced-setup.sh 100 setup-postgres

# Setup Redis caching
./advanced-setup.sh 100 setup-redis

# Enable monitoring (Prometheus + Grafana)
./advanced-setup.sh 100 setup-monitoring

# Configure daily backups
./advanced-setup.sh 100 setup-backup

# Setup everything at once
./advanced-setup.sh 100 setup-all
```

**What gets configured:**

**Nginx:**
- ✅ Reverse proxy for backend + frontend
- ✅ SSL/TLS with Let's Encrypt
- ✅ Security headers (HSTS, X-Frame-Options, etc.)
- ✅ Rate limiting (per-endpoint)
- ✅ Static asset caching

**Monitoring:**
- ✅ Prometheus metrics collection
- ✅ Grafana dashboards (3000)
- ✅ Pre-built dashboards (system, API, DB)
- ✅ Alert rules

**PostgreSQL:**
- ✅ Database creation
- ✅ User with secure password
- ✅ Connection pooling (PgBouncer)
- ✅ Automated backups

**Redis:**
- ✅ Session store
- ✅ Cache layer
- ✅ LRU eviction policy
- ✅ Persistence enabled

**Backups:**
- ✅ Daily 2 AM backup schedule
- ✅ Database + application files
- ✅ 7-day retention
- ✅ `/opt/backups/` storage

---

### ci-cd-deploy.sh
**Purpose:** Automate build, test, and deployment via CI/CD pipeline

**Usage:**
```bash
./ci-cd-deploy.sh <command> [options]
```

**Build Commands:**

```bash
# Build backend and frontend
./ci-cd-deploy.sh build-all

# Build backend only
./ci-cd-deploy.sh build-backend

# Build frontend only
./ci-cd-deploy.sh build-frontend
```

**Deployment Strategies:**

```bash
# Standard deployment (stops old, deploys new)
./ci-cd-deploy.sh deploy 100 192.168.1.100

# Blue-green (deploy to standby, then switch)
./ci-cd-deploy.sh blue-green 100 101 192.168.1.100 192.168.1.101

# Canary (gradual rollout with monitoring)
./ci-cd-deploy.sh canary 100 192.168.1.100 10  # Start with 10% traffic
```

**Testing Commands:**

```bash
# Integration tests (API + endpoints)
./ci-cd-deploy.sh test-integration http://localhost:3001

# Load tests (Apache Bench)
./ci-cd-deploy.sh test-load http://localhost:3001 60 10
# Parameters: URL, duration (seconds), concurrency

# Security vulnerability scan
./ci-cd-deploy.sh test-security

# Create smoke test suite
./ci-cd-deploy.sh create-smoke-tests
```

**Rollback:**

```bash
# Restore from backup
./ci-cd-deploy.sh rollback 100 192.168.1.100 /opt/backups/worktrack-20240129.tar.gz
```

---

## 🚀 Typical Deployment Flow

### Phase 1: Create Infrastructure
```bash
# Create new LXC container
./deploy-lxc.sh 100 worktrack-app 192.168.1.100 24 192.168.1.1 local 2048 2 pve

# Wait for container to initialize (2-3 minutes)
sleep 180

# Verify container health
./manage-lxc.sh 100 status
./manage-lxc.sh 100 health-check
```

### Phase 2: Deploy Application Code
```bash
# From Proxmox host or CI runner:
scp -r backend/ root@192.168.1.100:/opt/worktrack/
scp -r web/dist/ root@192.168.1.100:/opt/worktrack/web/

# Inside container, restart services
./manage-lxc.sh 100 shell
systemctl restart worktrack-backend worktrack-web
exit
```

### Phase 3: Setup Production Features
```bash
# Configure SSL + reverse proxy
./advanced-setup.sh 100 setup-nginx worktrack.example.com admin@example.com

# Replace SQLite with PostgreSQL
./advanced-setup.sh 100 setup-postgres

# Add caching layer
./advanced-setup.sh 100 setup-redis

# Enable monitoring
./advanced-setup.sh 100 setup-monitoring

# Setup automated backups
./advanced-setup.sh 100 setup-backup
```

### Phase 4: Verify Deployment
```bash
# Run health checks
./manage-lxc.sh 100 health-check

# Run integration tests
./ci-cd-deploy.sh test-integration https://worktrack.example.com/api

# Run smoke tests
./ci-cd-deploy.sh create-smoke-tests
./manage-lxc.sh 100 shell
bash /tmp/smoke-tests.sh
exit
```

---

## 📊 Monitoring & Maintenance

### Access Dashboards
```
Grafana (Monitoring):     https://worktrack.example.com:3000
Prometheus (Metrics):     https://worktrack.example.com:9090
Application Frontend:     https://worktrack.example.com
Application API:          https://worktrack.example.com/api
```

### Regular Tasks
```bash
# Weekly: Update packages
./manage-lxc.sh 100 update

# Monthly: Verify backups
./manage-lxc.sh 100 shell
ls -lah /opt/backups/
exit

# Quarterly: Disaster recovery test
./manage-lxc.sh 100 backup
# Test restore on separate container
```

---

## 🔧 Troubleshooting

### Container won't start
```bash
# Check container status
pct status 100

# View Proxmox logs
journalctl -u pve-container@100 -n 50

# Try restart
./manage-lxc.sh 100 restart
```

### Services not responding
```bash
# Connect to container
./manage-lxc.sh 100 shell

# Check service status
systemctl status worktrack-backend worktrack-web

# View service logs
journalctl -u worktrack-backend -n 100
journalctl -u worktrack-web -n 100

# Restart services
systemctl restart worktrack-backend worktrack-web
```

### High resource usage
```bash
# Check inside container
./manage-lxc.sh 100 shell
free -h          # Memory
df -h             # Disk
top               # Process list
```

### SSL certificate issues
```bash
# Check certificate status
./manage-lxc.sh 100 shell
certbot certificates

# Renew manually
certbot renew --force-renewal
```

---

## 📚 Documentation Files

### README.md
Quick start guide and basic troubleshooting
- Prerequisites
- Installation steps
- Common issues and fixes
- Port mapping

### OPERATIONS.md
Complete operations manual (15KB)
- Deployment phases detailed
- Production configuration
- Monitoring dashboards
- Backup & recovery procedures
- Performance tuning
- Scaling strategies
- Maintenance schedules

### This File (INDEX.md)
Reference guide for all scripts
- Script descriptions
- Parameter documentation
- Usage examples
- Workflow guidance

---

## 🔑 Key Features

✅ **Automated Deployment**
- One-command LXC provisioning
- Automatic dependency installation
- Service configuration

✅ **Production Ready**
- SSL/TLS with Let's Encrypt
- Nginx reverse proxy
- PostgreSQL database
- Redis caching
- Automated backups

✅ **Monitoring & Observability**
- Prometheus metrics
- Grafana dashboards
- Health checks
- Audit logging

✅ **CI/CD Integration**
- Build automation
- Multiple deployment strategies
- Automated testing
- Rollback capability

✅ **Operational Excellence**
- Container lifecycle management
- Blue-green deployments
- Canary releases
- Load testing
- Disaster recovery

---

## 🛡️ Security Features

- SSH key-only authentication (no passwords)
- UFW firewall with strict rules
- SSL/TLS encryption
- CSRF protection
- XSS sanitization
- Rate limiting
- Input validation
- Parameterized queries
- Audit logging

---

## 📈 Scaling Options

**Single Container:**
- Start with 2-4 CPU cores
- 2-4GB RAM
- SQLite or PostgreSQL

**Multiple Containers (Horizontal Scaling):**
```
Load Balancer → Container 1 (backend)
             → Container 2 (backend)
             → Container 3 (backend)
                    ↓
             Shared PostgreSQL
             Shared Redis
```

**Enterprise Setup:**
- Dedicated database server
- Dedicated Redis server
- Nginx load balancer
- Container auto-scaling

---

## 🆘 Support

For issues or questions:
1. Check [README.md](#readmemd) for quick solutions
2. Review [OPERATIONS.md](#operationsmd) troubleshooting section
3. Check container logs: `./manage-lxc.sh 100 logs`
4. Run health checks: `./manage-lxc.sh 100 health-check`

---

## 📝 Version History

- **v1.0** (Jan 29, 2024) - Initial release
  - deploy-lxc.sh: LXC provisioning
  - manage-lxc.sh: Lifecycle management
  - advanced-setup.sh: Production features
  - ci-cd-deploy.sh: CI/CD integration
  - Full documentation suite

---

**Last Updated:** January 29, 2024  
**Maintainer:** WorkTrack Dev Team  
**License:** MIT  
**Repository:** https://github.com/yourorg/worktrack
