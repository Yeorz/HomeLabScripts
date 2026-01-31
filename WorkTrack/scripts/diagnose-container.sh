#!/usr/bin/env bash
# diagnose-container.sh - Debug WorkTrack container setup
# Run inside the LXC container with: bash scripts/diagnose-container.sh

set -euo pipefail

echo "🔍 WorkTrack Container Diagnostic"
echo "=================================="
echo

# Check Node.js
echo "📌 Node.js version:"
node --version
npm --version
echo

# Check backend dependencies first (install if needed)
echo "📌 Backend dependencies:"
cd /root/worktrack/backend

# Clear cache and retry
echo "   Clearing npm cache..."
npm cache clean --force 2>&1 | grep -E "(cleared|cache)" | head -2 || true

echo "   Running npm install..."
npm install 2>&1 | tail -20
echo

echo "   Checking installed packages..."
npm ls --depth=0 2>&1 | head -15
echo

# Check .env file
echo "📌 Backend .env file:"
if [ -f /root/worktrack/backend/.env ]; then
  echo "   ✓ File exists at /root/worktrack/backend/.env"
  echo "   Contents:"
  cat /root/worktrack/backend/.env | sed 's/^/     /'
else
  echo "   ❌ .env file missing. Creating now..."
  cat >/root/worktrack/backend/.env <<EOF
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
FRONTEND_URL=http://$(hostname -I | awk '{print $1}')
NODE_ENV=production
EOF
  echo "   ✓ Created .env file"
fi
echo

# Check backend dependencies
echo "📌 Backend dependencies:"
cd /root/worktrack/backend && npm ls --depth=0 2>&1 | head -20
echo

# Kill any existing pm2 process
echo "📌 PM2 processes:"
pm2 list
echo

# Try starting backend manually to see actual errors
echo "📌 Testing backend startup (manual run):"
cd /root/worktrack/backend
timeout 5 node server.js 2>&1 || true
echo

# Now restart with pm2
echo "📌 Restarting backend with pm2..."
pm2 delete worktrack-backend 2>/dev/null || true
pm2 start --name worktrack-backend --cwd /root/worktrack/backend -- node server.js
sleep 2
pm2 logs worktrack-backend --lines 50
echo

# Check nginx
echo "📌 Nginx status:"
sudo nginx -t
sudo systemctl status nginx --no-pager | head -5 || true
echo

# Check web dist
echo "📌 Web dist folder:"
if [ -d /root/worktrack/web/dist ]; then
  echo "   ✓ Exists"
  ls -lh /root/worktrack/web/dist | head -10
else
  echo "   ❌ Missing - rebuilding web..."
  cd /root/worktrack/web
  npm run build
fi
echo

# Test API endpoint
echo "📌 Testing API endpoint:"
curl -s -w "\n   HTTP Status: %{http_code}\n" http://localhost:3001/auth/csrf-token || echo "   ⚠️  Could not connect"
echo

echo "✅ Diagnostic complete"
