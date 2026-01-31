#!/usr/bin/env bash
set -euo pipefail

# deploy-web-container.sh
# Run inside the LXC container to install web deps, build the frontend,
# restart backend, and reload nginx.

WORKDIR=/root/worktrack
WEBDIR="$WORKDIR/web"
BACKEND_NAME=worktrack-backend

SUDO=''
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO=sudo
  else
    echo "This script should be run as root or with sudo available." >&2
    exit 1
  fi
fi

if [ ! -d "$WEBDIR" ]; then
  echo "Web directory not found at $WEBDIR" >&2
  exit 1
fi

cd "$WEBDIR"
echo "== Installing web dependencies (npm ci) =="
if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found. Ensure Node.js (>=22) and npm are installed in the container." >&2
  exit 1
fi

npm ci --no-audit --no-fund

echo "== Building web (npm run build) =="
npm run build

echo "== Ensuring backend is running under pm2 =="
if command -v pm2 >/dev/null 2>&1; then
  if pm2 list | grep -q "${BACKEND_NAME}"; then
    pm2 restart "${BACKEND_NAME}" || true
  else
    # Try to start the backend if pm2 entry missing
    if [ -d "$WORKDIR/backend" ]; then
      pm2 start --name "${BACKEND_NAME}" --cwd "$WORKDIR/backend" -- node -r dotenv/config server.js || true
    fi
  fi
  pm2 save || true
else
  echo "pm2 not found, skipping process manager steps." >&2
fi

echo "== Reloading nginx =="
${SUDO} nginx -t || true
(${SUDO} systemctl restart nginx || ${SUDO} service nginx restart || ${SUDO} nginx -s reload) || true

echo "== Done; tailing backend logs (press Ctrl-C to stop) =="
if command -v pm2 >/dev/null 2>&1; then
  pm2 logs "${BACKEND_NAME}" --lines 200
else
  if [ -f /var/log/nginx/error.log ]; then
    tail -n 200 /var/log/nginx/error.log
  else
    echo "No pm2 and no nginx error log available to tail." >&2
  fi
fi
