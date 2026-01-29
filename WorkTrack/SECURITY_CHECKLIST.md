# ⚡ WorkTrack Security Quick Reference
**Last Updated:** January 29, 2026  
**Status:** 🔴 CRITICAL ISSUES FOUND

---

## 🔴 CRITICAL (Fix Immediately)

- [ ] **Hardcoded Secrets in Code**
  - `auth.js`: Line 8 has `"secret"` hardcoded
  - `server.js`: Lines 43, 88 have fallback secrets
  - **Fix:** Use `process.env.JWT_SECRET` only, no defaults
  - **Time:** 15 min

- [ ] **JWT Tokens Exposed in API Response**
  - `server.js`: Lines 200, 233 return `{ token }`
  - **Fix:** Only return `{ user }`, token goes in httpOnly cookie
  - **Time:** 10 min

- [ ] **Mobile Token Stored in Plain Text**
  - `storage.js`: AsyncStorage stores tokens unencrypted
  - **Fix:** Use `react-native-keychain` instead
  - **Time:** 1 hr

- [ ] **CSRF Validation Missing**
  - All POST endpoints lack CSRF protection
  - **Fix:** Install `csurf` package, apply middleware
  - **Time:** 45 min

- [ ] **Unencrypted Database (SQLite)**
  - `server.js`: Line 55, `db.sqlite` has no encryption
  - **Fix:** Use SQLite cipher or switch to PostgreSQL
  - **Time:** 30 min

---

## 🟠 HIGH (Fix in 24 hours)

- [ ] **Weak Session Security**
  - Session timeout: 24h (should be 1-2h)
  - Secret hardcoded (see critical #1)
  - **Fix:** Reduce maxAge, remove fallback secret
  - **Time:** 20 min

- [ ] **API Endpoint Data Leakage**
  - `/public/:userId` exposes user emails
  - No rate limiting on public endpoints
  - **Fix:** Remove email, add rate limiter
  - **Time:** 25 min

- [ ] **Password Duration Validation**
  - Min length OK (12 chars) but no complexity check
  - **Fix:** Require uppercase, lowercase, number, special char
  - **Time:** 20 min

- [ ] **CORS Misconfiguration**
  - Defaults to `localhost:5173` if env missing
  - No origin validation function
  - **Fix:** Validate against whitelist, fail on mismatch
  - **Time:** 20 min

---

## 🟡 MEDIUM (Fix This Week)

- [ ] **Missing HTTP Security Headers**
  - CSP not configured
  - Add: X-Content-Type-Options, Content-Security-Policy
  - **Time:** 30 min

- [ ] **Insufficient Security Logging**
  - Audit log missing event types and details
  - No SIEM integration
  - **Time:** 1 hr

- [ ] **OAuth State Validation**
  - State not validated on callback
  - No CSRF for OAuth flows
  - **Time:** 40 min

- [ ] **Watch App Security**
  - UserDefaults stores data unencrypted
  - **Fix:** Use CryptoKit for encryption
  - **Time:** 1 hr

- [ ] **Backup Encryption**
  - Database backups stored unencrypted
  - **Fix:** Use GPG encryption
  - **Time:** 45 min

---

## ✅ WHAT'S ALREADY GOOD

- ✅ Bcrypt for password hashing (12 rounds)
- ✅ Rate limiting implemented (auth + global)
- ✅ Helmet.js for basic headers
- ✅ Parameterized queries (no SQL injection)
- ✅ Input validation on auth endpoints
- ✅ DOMPurify for XSS prevention (web)
- ✅ httpOnly flag on cookies
- ✅ SameSite=strict on cookies
- ✅ Audit logging basic structure

---

## 🚨 URGENT ACTION ITEMS

### TODAY (Next 2 hours)
```bash
# 1. Generate secrets
export JWT_SECRET=$(openssl rand -base64 32)
export SESSION_SECRET=$(openssl rand -base64 32)

# 2. Update auth.js
# - Remove hardcoded "secret"
# - Add: if (!process.env.JWT_SECRET) process.exit(1)

# 3. Update server.js
# - Remove || fallback secrets
# - Remove token from response body

# 4. Test
npm start  # Should require JWT_SECRET env var
```

### THIS WEEK (4-6 hours total)
```bash
# 1. Install CSRF package
npm install csurf

# 2. Implement CSRF middleware
# See: SECURITY_REMEDIATION_GUIDE.md

# 3. Add database encryption
npm install sqlcipher

# 4. Fix mobile token storage
cd mobile
npm install react-native-keychain
```

---

## FILE LOCATIONS NEEDING FIXES

| File | Issue | Lines | Priority |
|------|-------|-------|----------|
| backend/auth.js | Hardcoded secret | 8 | 🔴 NOW |
| backend/server.js | Multiple secrets, JWT exposure, CSRF | 43, 88, 200, 233, 273-288 | 🔴 NOW |
| mobile/storage.js | Plain text tokens | 5-40 | 🔴 NOW |
| web/src/utils/security.js | Weak password rules | 68 | 🟠 24h |
| web/src/contexts/AuthContext.jsx | OAuth state validation | 59-71 | 🟡 1w |
| watch/UserCalibration.swift | Unencrypted storage | 10-24 | 🟡 1w |
| backend/.env | Secrets location | - | 🔴 NOW |

---

## ENVIRONMENT VARIABLES REQUIRED

```bash
# Minimum for production
JWT_SECRET=<openssl rand -base64 32>
SESSION_SECRET=<openssl rand -base64 32>
SQLITE_CIPHER_KEY=<openssl rand -base64 32>
CORS_ORIGINS=https://your-domain.com
NODE_ENV=production
FRONTEND_URL=https://your-domain.com
```

---

## TESTING COMMANDS

```bash
# 1. Test secrets required
unset JWT_SECRET
npm start
# Expected error: "FATAL: JWT_SECRET environment variable not set"

# 2. Test CSRF protection
curl -X POST http://localhost:3001/workouts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"Strength","duration":30,"calories":100}'
# Expected: 403 Forbidden

# 3. Test token NOT in response
curl -s -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test"}' | grep -c "\"token\""
# Expected: 0 (not found)

# 4. Test token IN cookie
curl -s -i -X POST http://localhost:3001/auth/login \
  -d '{"email":"test@example.com","password":"test"}' | grep -i "set-cookie"
# Expected: httpOnly; SameSite=Strict
```

---

## DEPLOYMENT READINESS

| Aspect | Status | Action |
|--------|--------|--------|
| Secrets Management | 🔴 FAIL | Remove hardcoded values |
| CSRF Protection | 🔴 FAIL | Install & implement csurf |
| Database Encryption | 🔴 FAIL | Enable SQLite cipher |
| API Token Handling | 🔴 FAIL | Remove from response body |
| Mobile Security | 🔴 FAIL | Use Keychain for tokens |
| HTTP Headers | 🟡 WARN | Add CSP, X-Content-Type-Options |
| CORS Validation | 🟡 WARN | Add origin whitelist check |
| Rate Limiting | 🟢 PASS | Configured but tune values |
| Password Hashing | 🟢 PASS | Bcrypt 12 rounds OK |
| HTTPS | 🔴 FAIL | Not yet configured |

**Cannot Deploy:** 🔴 **6 Critical issues must be fixed**

---

## SECURITY HEADERS TO ADD

```javascript
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", process.env.FRONTEND_URL],
      frameDest: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  frameguard: { action: 'deny' },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  noSniff: true,
  xssFilter: true,
}));
```

---

## 📞 ESCALATION PATH

If you need immediate help:
1. Review detailed audit: `SECURITY_AUDIT_REPORT.md`
2. Follow fixes: `SECURITY_REMEDIATION_GUIDE.md`
3. Use this checklist for tracking

**Estimated Resolution Time:** 4-6 hours for critical items

---

**Last Security Review:** January 29, 2026  
**Next Review:** After critical fixes applied + 1 week  
**Status:** 🔴 NOT PRODUCTION READY

