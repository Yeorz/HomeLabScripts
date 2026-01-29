#!/bin/bash
# WorkTrack Deployment Quick Reference
# Copy these commands into your terminal for quick access

## 📋 QUICK START COMMANDS

# 1️⃣  Create new LXC container
./scripts/deploy-lxc.sh 100 worktrack-app 192.168.1.100 24 192.168.1.1 local 2048 2 pve

# 2️⃣  Setup production features
./scripts/advanced-setup.sh 100 setup-all

# 3️⃣  Deploy application code
scp -r backend root@192.168.1.100:/opt/worktrack/
scp -r web/dist root@192.168.1.100:/opt/worktrack/web/

# 4️⃣  Verify deployment
./scripts/manage-lxc.sh 100 health-check

---

## 🔧 COMMON MANAGEMENT TASKS

# Check container status
./scripts/manage-lxc.sh 100 status

# View service logs
./scripts/manage-lxc.sh 100 logs

# Connect to container
./scripts/manage-lxc.sh 100 shell

# Restart services
./scripts/manage-lxc.sh 100 restart

# Create backup
./scripts/manage-lxc.sh 100 backup

# Update packages
./scripts/manage-lxc.sh 100 update

# Run health checks
./scripts/manage-lxc.sh 100 health-check

---

## 🚀 DEPLOYMENT STRATEGIES

# Standard deployment (recommended for non-critical)
./scripts/ci-cd-deploy.sh deploy 100 192.168.1.100

# Blue-green deployment (recommended for production)
./scripts/ci-cd-deploy.sh blue-green 100 101 192.168.1.100 192.168.1.101

# Canary deployment (gradual rollout)
./scripts/ci-cd-deploy.sh canary 100 192.168.1.100 10

---

## 🧪 TESTING

# Run integration tests
./scripts/ci-cd-deploy.sh test-integration http://localhost:3001

# Run load tests (60 seconds, 10 concurrent requests)
./scripts/ci-cd-deploy.sh test-load http://localhost:3001 60 10

# Run security scan
./scripts/ci-cd-deploy.sh test-security

# Create smoke tests
./scripts/ci-cd-deploy.sh create-smoke-tests

---

## 🛡️ PRODUCTION SETUP

# Setup SSL/TLS with Let's Encrypt
./scripts/advanced-setup.sh 100 setup-nginx worktrack.example.com admin@example.com

# Setup PostgreSQL (replaces SQLite)
./scripts/advanced-setup.sh 100 setup-postgres

# Setup Redis caching
./scripts/advanced-setup.sh 100 setup-redis

# Setup Prometheus monitoring
./scripts/advanced-setup.sh 100 setup-monitoring

# Setup automated backups
./scripts/advanced-setup.sh 100 setup-backup

---

## 📊 MONITORING ACCESS

# Grafana dashboards (default password: admin/admin)
https://192.168.1.100:3000

# Prometheus metrics
https://192.168.1.100:9090

# Application web interface
https://worktrack.example.com

# API endpoint
https://worktrack.example.com/api

---

## 🔙 ROLLBACK & RECOVERY

# List available backups
./scripts/manage-lxc.sh 100 shell
ls -lah /opt/backups/

# Restore from backup
./scripts/ci-cd-deploy.sh rollback 100 192.168.1.100 /opt/backups/worktrack-20240129.tar.gz

# Backup container
./scripts/manage-lxc.sh 100 backup

---

## 🐛 TROUBLESHOOTING

# Check service status
./scripts/manage-lxc.sh 100 shell
systemctl status worktrack-backend worktrack-web

# View backend logs
journalctl -u worktrack-backend -n 100 -f

# View frontend logs
journalctl -u worktrack-web -n 100 -f

# Test API connectivity
curl -I http://localhost:3001/health

# Test database connection
psql -U worktrack -d worktrack -c "SELECT 1;"

# Check disk usage
df -h
du -sh /opt/worktrack/*

---

## 🔐 SECURITY TASKS

# SSH into container (key auth)
ssh -i ~/.ssh/id_rsa root@192.168.1.100

# View firewall rules
./scripts/manage-lxc.sh 100 shell
ufw status verbose

# Regenerate JWT secret
openssl rand -base64 32

# View audit logs
./scripts/manage-lxc.sh 100 shell
journalctl -u worktrack-backend | grep -i audit

---

## 📈 SCALING

# Vertical: Increase resources on single container
pct set 100 --cores 4 --memory 4096

# Horizontal: Create second container
./scripts/deploy-lxc.sh 101 worktrack-app2 192.168.1.101 24 192.168.1.1 local 2048 2 pve

---

## 📚 DOCUMENTATION

# Full reference guide
cat ./scripts/INDEX.md

# Operations manual (15KB)
cat ./scripts/OPERATIONS.md

# Quick start guide
cat ./scripts/README.md

# This file
cat ./scripts/QUICK-REFERENCE.sh

---

## 🆘 GET HELP

# View script usage
./scripts/deploy-lxc.sh
./scripts/manage-lxc.sh
./scripts/advanced-setup.sh
./scripts/ci-cd-deploy.sh

# Check script permissions (should be executable)
ls -lah ./scripts/*.sh

# Run health check
./scripts/manage-lxc.sh 100 health-check

---

## 🚨 EMERGENCY PROCEDURES

# If backend service crashes
ssh root@192.168.1.100 systemctl restart worktrack-backend

# If container won't respond
pct stop 100
pct start 100

# If disk is full
ssh root@192.168.1.100 'find /opt/backups -name "*.tar.gz" -mtime +30 -delete'

# If database corrupted
./scripts/manage-lxc.sh 100 shell
systemctl stop worktrack-backend
# Restore from backup or rebuild

---

## 📋 ENVIRONMENT VARIABLES

# Backend (.env)
JWT_SECRET=<random-32-char-string>
DATABASE_URL=postgresql://user:pass@localhost/worktrack
REDIS_URL=redis://localhost:6379
CORS_ORIGIN=https://worktrack.example.com

# Frontend (.env)
VITE_API_URL=https://worktrack.example.com/api
VITE_APP_NAME=WorkTrack

---

## 💾 BACKUP LOCATIONS

# Container backups
/opt/backups/worktrack-*.tar.gz

# Database backups
/opt/backups/worktrack-db-*.sql

# Nginx configs
/etc/nginx/sites-available/worktrack

# Application code
/opt/worktrack/backend/
/opt/worktrack/web/

---

## 🎯 PRE-DEPLOYMENT CHECKLIST

- [ ] Container created and running
- [ ] Network connectivity verified (ping works)
- [ ] SSH key authentication configured
- [ ] Application code deployed
- [ ] Environment variables set (.env)
- [ ] Services started and responding
- [ ] SSL certificate obtained (if using HTTPS)
- [ ] Nginx reverse proxy configured
- [ ] Firewall rules applied
- [ ] Backups configured
- [ ] Monitoring dashboards accessible
- [ ] Health checks passing
- [ ] Smoke tests completed
- [ ] Load tests passing (optional)
- [ ] Disaster recovery tested (quarterly)

---

**Last Updated:** January 29, 2024
**Version:** 1.0
**Status:** Production Ready ✅

