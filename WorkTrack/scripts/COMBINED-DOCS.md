# WorkTrack Scripts — Combined Documentation

This file merges `README.md`, `INDEX.md`, `OPERATIONS.md`, and `QUICK-REFERENCE.md` into a single reference.

-- TOC --
- Quick Start / README
- Index
- Operations Guide
- Quick Reference

---

## README (Quick Start)

## WorkTrack Proxmox LXC Deployment Scripts

Automated deployment scripts for running WorkTrack on Proxmox infrastructure.

## Overview

This folder contains shell scripts to deploy and manage WorkTrack on Proxmox:

- **deploy-lxc.sh** - Initial LXC container creation and setup
- **manage-lxc.sh** - Container management and operations

## Prerequisites

- Proxmox VE 7.0+ installed on host
- SSH access to Proxmox node
- Container template: `debian-12-standard_12.2-1_amd64.tar.zst`
- At least 2GB RAM and 20GB storage available

## Quick Start

### 1. Prepare the Scripts

```bash
cd WorkTrack/scripts
chmod +x deploy-lxc.sh manage-lxc.sh
```

### 2. Deploy Container

Run the deployment script from your Proxmox node:

```bash
# Basic deployment (uses defaults)
./deploy-lxc.sh

# Custom deployment
./deploy-lxc.sh 100 worktrack-app 192.168.1.100 24 192.168.1.1 local 2048 2 pve
```

### 3. Deploy Application Code

After the container is created:

```bash
# Copy application files to container
ssh root@192.168.1.100 mkdir -p /opt/worktrack/{backend,web}

scp -r backend root@192.168.1.100:/opt/worktrack/
scp -r web root@192.168.1.100:/opt/worktrack/
```

### 4. Install Dependencies & Build

```bash
# SSH into container
ssh root@192.168.1.100

# Backend setup
cd /opt/worktrack/backend
npm install

# Web setup
cd /opt/worktrack/web
npm install
npm run build
```

### 5. Start Services

```bash
# Start backend service
systemctl start worktrack-backend
systemctl enable worktrack-backend

# Start web service
systemctl start worktrack-web
systemctl enable worktrack-web

# Check status
systemctl status worktrack-backend worktrack-web
```

### 6. Access Application

- **Dashboard**: http://192.168.1.100:5173
- **Backend API**: http://192.168.1.100:3001

## Management Commands

### Container Control

```bash
# Start container
./manage-lxc.sh start 100

# Stop container
./manage-lxc.sh stop 100

# Restart container
./manage-lxc.sh restart 100

# Check status
./manage-lxc.sh status 100
```

### Monitoring & Logs

```bash
# View backend logs
./manage-lxc.sh logs 100 backend

# View web logs
./manage-lxc.sh logs 100 web

# View all logs
./manage-lxc.sh logs 100
```

### Container Management

```bash
# Open shell in container
./manage-lxc.sh shell 100

# Health check
./manage-lxc.sh health-check 100

# Backup container
./manage-lxc.sh backup 100 /backup/path

# Update application code
./manage-lxc.sh update 100 /path/to/local/worktrack

# Remove container
./manage-lxc.sh remove 100
```

## Deployment Flow

### Phase 1: Validation ✓
- Verify Proxmox tools available
- Check container ID not in use
- Validate storage pool exists

### Phase 2: Container Creation ✓
- Create LXC container with specs
- Start container
- Wait for online status

### Phase 3: System Setup ✓
- Update packages
- Install Node.js 18+
- Install Docker
- Install SQLite3

### Phase 4: Application Setup ✓
- Create app directories
- Generate environment files
- Create systemd service files

### Phase 5: Security ✓
- Configure UFW firewall
- Harden SSH configuration
- Configure inbound rules

### Phase 6: Verification ✓
- Verify container running
- Check installed services
- Display deployment summary

## Service Files

Systemd services are auto-created:

### worktrack-backend.service
- Runs backend Node.js server
- Listens on port 3001
- Auto-restarts on failure

### worktrack-web.service
- Serves built React app
- Listens on port 5173
- Uses `serve` package for production

## Firewall Rules

By default, the following ports are allowed:
- **22/tcp** - SSH
- **3001/tcp** - Backend API
- **5173/tcp** - Web UI

For production, consider:
- Running behind nginx reverse proxy
- Enabling HTTPS with Let's Encrypt
- Restricting access by IP

## Environment Configuration

### Backend (.env)
```
NODE_ENV=production
PORT=3001
FRONTEND_URL=http://192.168.1.100:5173
JWT_SECRET=<random-32-char-string>
SESSION_SECRET=<random-32-char-string>
```

### Web (.env)
```
REACT_APP_API_URL=http://192.168.1.100:3001
REACT_APP_OAUTH_CLIENT_ID=<oauth-client-id>
```

## Troubleshooting

### Container won't start
```bash
# Check container status
pct status 100

# View container logs
journalctl -M 100 -n 100
```

### Services not running
```bash
# SSH into container
./manage-lxc.sh shell 100

# Check service status
systemctl status worktrack-backend
journalctl -u worktrack-backend -n 50

# Restart service
systemctl restart worktrack-backend
```

### Backend API not responding
```bash
# Test connectivity
curl http://192.168.1.100:3001/auth/session

# Check backend logs
./manage-lxc.sh logs 100 backend
```

### Web dashboard not loading
```bash
# Check web service
systemctl status worktrack-web

# Verify build
ls -la /opt/worktrack/web/build/

# Rebuild if needed
cd /opt/worktrack/web && npm run build
```

## Performance Tuning

For production deployments:

```bash
# Increase memory allocation
pct set 100 --memory 4096

# Add more cores
pct set 100 --cores 4

# Increase swap
pct set 100 --swap 2048
```

## Backup & Recovery

```bash
# Backup before major changes
./manage-lxc.sh backup 100 /backup/worktrack

# List backups
ls -lah /backup/worktrack/

# Restore from backup (manual process)
pct restore <vmid> <backup-file>
```

## Security Best Practices

1. **Generate strong secrets**
	```bash
	openssl rand -base64 32
	```

2. **Configure OAuth/SAML**
	- Update .env with provider credentials
	- Register callback URLs

3. **Set up reverse proxy (nginx)**
	- Terminate HTTPS
	- Add rate limiting
	- Set security headers

4. **Regular backups**
	- Schedule automated backups
	- Test restore procedures

5. **Monitor logs**
	- Use container logs for debugging
	- Monitor resource usage
	- Alert on service failures

## Scaling

For production with multiple users:

1. Increase container specs (CPU, RAM)
2. Deploy behind load balancer
3. Use external database (PostgreSQL)
4. Implement caching layer (Redis)
5. Use CDN for static assets

## Support

For issues or questions:

1. Check logs: `./manage-lxc.sh logs 100`
2. Run health check: `./manage-lxc.sh health-check 100`
3. Review deployment summary from deploy output
4. Check Proxmox node logs

## License

Same as WorkTrack project

---

---

## INDEX (Scripts Reference)

Complete automation suite for deploying, managing, and maintaining WorkTrack in Proxmox LXC environments.

### Scripts Overview

| Script | Purpose |
|--------|---------|
| `deploy-lxc.sh` | Initial LXC container setup |
| `manage-lxc.sh` | Container lifecycle management |
| `advanced-setup.sh` | Production features (SSL, monitoring, DB) |
| `ci-cd-deploy.sh` | CI/CD pipeline & deployment strategies |

Refer to the sections above and the Operations guide below for usage examples and runbooks.

---

---

## OPERATIONS (Full Operations Guide)

Complete guide for deploying, managing, and maintaining WorkTrack in production environments.

### Quick Start

1. Deploy Base LXC Container

```bash
./deploy-lxc.sh 100 worktrack-app 192.168.1.100 24 192.168.1.1 local 2048 2 pve
```

2. Enter Container

```bash
./manage-lxc.sh 100 shell
```

3. Deploy Application

```bash
scp -r backend root@192.168.1.100:/opt/worktrack/
scp -r web root@192.168.1.100:/opt/worktrack/

# Inside container, start services
systemctl start worktrack-backend worktrack-web

# Verify
curl http://localhost:3001/auth/session
curl http://localhost:5173
```

### Production Configuration

- SSL/TLS with Let's Encrypt (`advanced-setup.sh`)
- Environment variables in backend `.env` and frontend `.env`
- Systemd services for backend and web
- Monitoring (Prometheus + Grafana)
- Automated backups

### Backup & Recovery

Automated backups are configured (daily at 2 AM) to `/opt/backups/` with 7-day retention. Manual restore instructions are in the Operations guide above.

### Troubleshooting & Runbook

The Operations guide contains detailed troubleshooting, disaster recovery steps, and maintenance windows. Use `./manage-lxc.sh` health-checks and logs when diagnosing issues.

---

---

## QUICK REFERENCE

Quick commands and examples for common tasks.

```bash
# Create new LXC container
./scripts/deploy-lxc.sh 100 worktrack-app 192.168.1.100 24 192.168.1.1 local 2048 2 pve

# Setup production features
./scripts/advanced-setup.sh 100 setup-all

# Verify deployment
./scripts/manage-lxc.sh 100 health-check

# Check container status
./scripts/manage-lxc.sh 100 status

# View logs
./scripts/manage-lxc.sh 100 logs

# Connect to container
./scripts/manage-lxc.sh 100 shell

# Blue-green deployment
./scripts/ci-cd-deploy.sh blue-green 100 101 192.168.1.100 192.168.1.101
```

Pre-deployment checklist:
- Container created and running
- Network connectivity verified
- SSH key authentication configured
- Application code deployed
- Environment variables set
- Services started and responding
- SSL certificate obtained (if HTTPS)
- Backups configured

---

*Last updated: January 29, 2026*


---

*Last updated: January 29, 2026*
