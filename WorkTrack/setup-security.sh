#!/bin/bash
# WorkTrack Security Setup Script
# This script helps set up required environment variables securely

set -e

echo "🔐 WorkTrack Security Setup"
echo "=================================="
echo ""

# Check if we're in the right directory
if [ ! -f "backend/server.js" ]; then
    echo "❌ Error: Run this script from the WorkTrack root directory"
    exit 1
fi

# Generate secrets
echo "📝 Generating secure secrets..."
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
SQLITE_CIPHER_KEY=$(openssl rand -base64 32)

echo "✅ Secrets generated successfully"
echo ""

# Check if .env already exists
if [ -f "backend/.env" ]; then
    echo "⚠️  backend/.env already exists"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping .env update"
        exit 0
    fi
fi

# Create .env file
cat > backend/.env << EOF
# WorkTrack Backend Configuration
NODE_ENV=development
PORT=3001
FRONTEND_URL=http://localhost:5173

# Security Secrets (Generated $(date))
JWT_SECRET=$JWT_SECRET
SESSION_SECRET=$SESSION_SECRET
SQLITE_CIPHER_KEY=$SQLITE_CIPHER_KEY

# CORS Configuration
CORS_ORIGINS=http://localhost:5173

# Logging
LOG_LEVEL=info
AUDIT_LOG_ENABLED=true
EOF

echo "✅ Created backend/.env with security configuration"
echo ""

# Create .env for web
if [ ! -f "web/.env" ]; then
    cat > web/.env << EOF
# WorkTrack Web Configuration
VITE_API_URL=http://localhost:3001
VITE_APP_NAME=WorkTrack
VITE_ENVIRONMENT=development
EOF
    echo "✅ Created web/.env"
fi

echo ""
echo "📚 Next Steps:"
echo "1. Start the backend:"
echo "   cd backend && npm install && npm run dev"
echo ""
echo "2. In another terminal, start the web:"
echo "   cd web && npm install && npm run dev"
echo ""
echo "3. For production deployment:"
echo "   - Update FRONTEND_URL to your production domain"
echo "   - Set NODE_ENV=production"
echo "   - Rotate secrets regularly"
echo "   - Use HTTPS only"
echo ""
echo "⚠️  Important: Never commit .env file to git!"
echo "Use .env.example as template instead."
echo ""
