# 🚀 Next Steps - Testing & Deployment

## Immediate Actions (Today)

### 1. Install Node.js Dependencies
```bash
cd /Users/bart/Documents/HomeLabScriptsMac/WorkTrack

# Backend
cd backend
npm install
npm install csurf  # CSRF protection

# Web
cd ../web
npm install

# Mobile (if using React Native)
cd ../mobile
npm install
```

### 2. Verify .env Files Created
```bash
# Check backend
cat backend/.env | head -5
# Should show:
# NODE_ENV=development
# JWT_SECRET=<generated-secret>
# SESSION_SECRET=<generated-secret>

# Check web
cat web/.env
# Should show:
# VITE_API_URL=http://localhost:3001
```

### 3. Start Services for Testing
```bash
# Terminal 1: Backend
cd backend
npm run dev
# Should output: Backend running on http://localhost:3001

# Terminal 2: Web
cd web
npm run dev
# Should output: Local: http://localhost:5173
```

### 4. Run Security Tests

#### Test 1: Verify Env Vars Required
```bash
# In a new terminal
unset JWT_SECRET
cd backend
npm start
# Expected: FATAL ERROR: JWT_SECRET environment variable not set
# Expected exit code: 1
```

#### Test 2: Verify CSRF Protection
```bash
# Get auth token first
TOKEN=$(curl -s -c cookies.txt -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password12345"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

# Try POST without CSRF token (should fail)
curl -X POST http://localhost:3001/workouts \
  -b cookies.txt \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"Strength","duration":30,"calories":100}'
# Expected: 403 Forbidden
```

#### Test 3: Verify Token NOT in Response
```bash
curl -s -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password12345"}' | jq .
# Expected output should show:
# {
#   "user": {
#     "id": 1,
#     "email": "test@example.com"
#   }
# }
# Should NOT contain "token" field
```

#### Test 4: Verify Token in httpOnly Cookie
```bash
curl -i -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password12345"}' | grep -i "set-cookie"
# Expected: Set-Cookie: token=...; HttpOnly; SameSite=Strict; Path=/
```

---

## Before Production Deployment

### 1. Generate Production Secrets
```bash
# Generate three strong secrets
JWT_SECRET_PROD=$(openssl rand -base64 32)
SESSION_SECRET_PROD=$(openssl rand -base64 32)
CIPHER_KEY_PROD=$(openssl rand -base64 32)

# Store these securely (password manager, vault, etc.)
echo "JWT_SECRET: $JWT_SECRET_PROD"
echo "SESSION_SECRET: $SESSION_SECRET_PROD"
echo "CIPHER_KEY: $CIPHER_KEY_PROD"
```

### 2. Create Production .env
```bash
cat > backend/.env.production << EOF
NODE_ENV=production
PORT=3001
FRONTEND_URL=https://your-domain.com

JWT_SECRET=$JWT_SECRET_PROD
SESSION_SECRET=$SESSION_SECRET_PROD
SQLITE_CIPHER_KEY=$CIPHER_KEY_PROD

CORS_ORIGINS=https://your-domain.com

LOG_LEVEL=info
AUDIT_LOG_ENABLED=true
EOF
```

### 3. Setup HTTPS/SSL
```bash
# Using Let's Encrypt with nginx
sudo apt-get install certbot python3-certbot-nginx

# Generate certificate
sudo certbot certonly --nginx -d your-domain.com

# Configure nginx to forward to Node.js
# (See OPERATIONS.md or setup-nginx script)
```

### 4. Set Environment Variables on Server
```bash
# Export before running:
export JWT_SECRET="$JWT_SECRET_PROD"
export SESSION_SECRET="$SESSION_SECRET_PROD"
export NODE_ENV=production
export FRONTEND_URL=https://your-domain.com

# Run backend
npm start
```

### 5. Run Production Tests
```bash
# Same tests as above but against production domain
# Test 1: CSRF enforcement
# Test 2: Token not in response
# Test 3: Token in httpOnly cookie
# Test 4: Rate limiting
# Test 5: HTTPS redirect
```

---

## Ongoing Security Maintenance

### Weekly
- [ ] Check logs for security events
- [ ] Monitor failed login attempts
- [ ] Review rate limiting hits

### Monthly
- [ ] Update dependencies: `npm audit fix`
- [ ] Review audit logs
- [ ] Test backup/restore procedures

### Quarterly
- [ ] Rotate secrets (generate new JWT_SECRET, SESSION_SECRET)
- [ ] Security audit
- [ ] Penetration testing

### Annually
- [ ] Full security review
- [ ] Compliance audit
- [ ] Infrastructure review

---

## Troubleshooting

### Issue: "FATAL ERROR: JWT_SECRET environment variable not set"
**Solution:** Make sure to run the setup script first
```bash
bash setup-security.sh
```
Or manually export:
```bash
export JWT_SECRET=$(openssl rand -base64 32)
```

### Issue: CSRF Token Validation Fails
**Ensure:**
1. Backend includes `csurf` middleware
2. Frontend fetches from `/auth/csrf-token` before POST
3. Token included in `X-CSRF-Token` header

### Issue: Mobile App Can't Sync
**Check:**
1. Token stored in Keychain (not AsyncStorage)
2. Network connectivity
3. Backend API accessible
4. CORS configured correctly

### Issue: Session Expires Too Quickly
**Session timeout is 1 hour** (configurable in backend/server.js line ~85)
- For development: increase to 24 hours
- For production: keep at 1-2 hours

---

## Deployment Checklist

Before going to production, verify:

- [ ] All tests pass locally
- [ ] .env.example in git (not .env)
- [ ] npm audit shows no vulnerabilities
- [ ] HTTPS/SSL configured
- [ ] Backend environment variables set
- [ ] Frontend FRONTEND_URL points to production domain
- [ ] Database backups configured
- [ ] Monitoring/alerting configured
- [ ] Rate limiting tested
- [ ] CSRF protection verified
- [ ] Secrets rotated and stored securely

---

## Documentation References

- **Quick Start:** See `README.md` in each component directory
- **Detailed Setup:** `SECURITY_IMPLEMENTATION.md`
- **Audit Findings:** `SECURITY_AUDIT_REPORT.md`
- **Code Examples:** `SECURITY_REMEDIATION_GUIDE.md`
- **Quick Reference:** `SECURITY_CHECKLIST.md`

---

## Support & Questions

If you encounter issues:

1. Check the relevant documentation file (see above)
2. Review the setup script: `setup-security.sh`
3. Check error messages carefully - they're descriptive
4. Consult `SECURITY_AUDIT_REPORT.md` for detailed explanations

---

**Last Updated:** January 29, 2026  
**Status:** Ready for Testing & Deployment  
**Next:** Run the tests above and report any issues

