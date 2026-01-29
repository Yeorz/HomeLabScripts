# 🔒 WorkTrack Security Audit Report
**Generated:** January 29, 2026  
**Severity Levels:** 🔴 CRITICAL | 🟠 HIGH | 🟡 MEDIUM | 🟢 LOW

---

## Executive Summary

Comprehensive security audit of WorkTrack multi-platform system identified **6 CRITICAL vulnerabilities**, **4 HIGH-risk issues**, and **8 MEDIUM-priority improvements**. No data breaches currently detected, but immediate remediation required to prevent exposure.

**Risk Level:** 🔴 **HIGH** — System not production-ready without fixes  
**Quick Priority:** Fix items 1-6 (Critical) and 7-9 (High) before any deployment

---

## CRITICAL VULNERABILITIES (IMMEDIATE ACTION REQUIRED)

### 🔴 #1: Hardcoded JWT Secret in auth.js
**File:** [backend/auth.js](backend/auth.js)  
**Severity:** CRITICAL (10/10)  
**Impact:** JWT tokens can be forged; entire authentication system compromised

**Current Code:**
```javascript
req.user = jwt.verify(token, "secret");
```

**Problems:**
- Secret is hardcoded as `"secret"` (4 characters)
- Visible in source code repository
- Same secret used in server.js with fallback `'super-secret-jwt-key'`
- Anyone with access to repo can forge valid tokens
- No environment variable usage

**Remediation:**
```bash
# 1. Generate secure secret
openssl rand -base64 32

# 2. Store in environment
export JWT_SECRET="<your-generated-secret>"

# 3. Update backend/auth.js
```

```javascript
export function auth(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.sendStatus(401);
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.sendStatus(403);
  }
}
```

---

### 🔴 #2: Hardcoded Fallback Secrets in server.js (Multiple Locations)
**File:** [backend/server.js](backend/server.js)  
**Severity:** CRITICAL (10/10)  
**Impact:** Authentication/session bypass in all environment setups

**Current Code (Lines 43-44, 88-89):**
```javascript
secret: process.env.SESSION_SECRET || 'super-secret-session-key',
// ... later ...
process.env.JWT_SECRET || 'super-secret-jwt-key',
```

**Problems:**
- Two production-like secrets hardcoded as fallbacks
- Used in session middleware (expires data compromise)
- Defaults activate if env var missing → PRODUCTION DEPLOYMENT RISK
- Same issue in token generation and verification

**Remediation:**
```javascript
// Validate environment on startup
const requiredEnvVars = ['JWT_SECRET', 'SESSION_SECRET'];
requiredEnvVars.forEach(envVar => {
  if (!process.env[envVar]) {
    console.error(`❌ FATAL: ${envVar} not set. Exiting.`);
    process.exit(1);
  }
});

// Remove all || fallbacks
secret: process.env.SESSION_SECRET,  // Will throw early if missing
process.env.JWT_SECRET,  // Will throw early if missing
```

---

### 🔴 #3: JWT Tokens Exposed in Response Body
**File:** [backend/server.js](backend/server.js) - Lines 200-204, 233-238  
**Severity:** CRITICAL (9/10)  
**Impact:** Tokens visible in logs, network proxies, browser history, API responses

**Current Code:**
```javascript
res.json({ user: { id: user.id, email: user.email }, token });
```

**Problems:**
- JWT returned in response body (not just httpOnly cookie)
- Duplicates token in cookie + JSON body
- Frontend receives token in `data.token` (accessible to JavaScript)
- Can be logged by proxies, browsers, monitoring tools
- API response caching exposes tokens

**Remediation:**
```javascript
// Only send token in httpOnly cookie (already set)
res.json({ user: { id: user.id, email: user.email } });
// Remove: token

// Frontend already gets cookie automatically
// secureApiCall with credentials: 'include' handles it
```

---

### 🔴 #4: Plaintext Token Storage in Mobile (AsyncStorage)
**File:** [mobile/storage.js](mobile/storage.js)  
**Severity:** CRITICAL (9/10)  
**Impact:** JWT tokens in cleartext; any rooted device compromised

**Current Architecture:**
- Tokens stored in AsyncStorage (plaintext)
- No encryption layer
- Accessible to any app/malware with device access
- No token expiration/rotation

**Problems:**
- AsyncStorage has no encryption (unlike Keychain/Keystore)
- Pending workouts include tokens in JSON
- Background sync stores tokens in memory persistently

**Remediation:**
```javascript
// Use react-native-keychain instead
import * as Keychain from 'react-native-keychain';

export async function saveTokenSecurely(token) {
  await Keychain.setGenericPassword('worktrack', token);
}

export async function getTokenSecurely() {
  const credentials = await Keychain.getGenericPassword();
  return credentials ? credentials.password : null;
}

// For pending workouts, store only locally without token
export async function saveWorkoutOffline(workout) {
  const existing = JSON.parse(await AsyncStorage.getItem('pending_workouts')) || [];
  // Remove token from stored data
  const { ...workoutWithoutToken } = workout;
  existing.push(workoutWithoutToken);
  await AsyncStorage.setItem('pending_workouts', JSON.stringify(existing));
}

// Fetch token from Keychain at sync time
export async function syncPendingWorkouts() {
  const token = await getTokenSecurely();  // Secure retrieval
  // ... use token for sync
}
```

---

### 🔴 #5: Missing CSRF Validation on Backend
**File:** [backend/server.js](backend/server.js)  
**Severity:** CRITICAL (9/10)  
**Impact:** Cross-Site Request Forgery attacks; attacker can POST workouts as victim

**Current Code:**
```javascript
app.post('/workouts', auth, (req, res) => {
  // No CSRF token validation
  // ...
});
```

**Problems:**
- Frontend sends CSRF token in `X-CSRF-Token` header
- Backend does NOT validate it
- POST endpoints completely open to CSRF
- auth middleware checks JWT but NOT CSRF

**Remediation:**
```javascript
// 1. Add CSRF middleware
const csrf = require('csurf');
const csrfProtection = csrf({ cookie: true });

// 2. Apply to all state-changing routes
app.post('/workouts', csrfProtection, auth, (req, res) => {
  // CSRF token now validated automatically
  // ...
});

app.post('/auth/login', csrfProtection, authLimiter, (req, res) => {
  // ...
});

app.post('/auth/register', csrfProtection, authLimiter, (req, res) => {
  // ...
});

// 3. Provide CSRF token endpoint
app.get('/csrf-token', csrfProtection, (req, res) => {
  res.json({ token: req.csrfToken() });
});

// 4. Update frontend to fetch before forms
const token = await fetch('/csrf-token').then(r => r.json());
```

---

### 🔴 #6: Unencrypted Database (SQLite in Production)
**File:** [backend/server.js](backend/server.js) - Line 55  
**Severity:** CRITICAL (9/10)  
**Impact:** All user data readable if database file accessed (passwords, OAuth tokens, audit logs)

**Current Setup:**
```javascript
const db = new sqlite3.Database('db.sqlite');
```

**Problems:**
- SQLite file is plaintext (no encryption at rest)
- Database stored in container with other files
- Passwords stored in column (with bcrypt), but OAuth tokens in plaintext if added
- Backup files inherit no encryption
- No audit trail isolation

**Remediation (Immediate):**
```javascript
// Use SQLite encryption extension
// Install: npm install sqlite3 --build-from-source --sqlite=/usr/bin/sqlite3-icu

// Enable encryption
const db = new sqlite3.Database('db.sqlite', (err) => {
  if (err) {
    console.error('Database error:', err);
    process.exit(1);
  }
  // Enable encryption with password
  db.run(`PRAGMA key = '${process.env.SQLITE_ENCRYPTION_KEY}'`, (err) => {
    if (err) console.error('Encryption error:', err);
  });
});
```

**Long-term (Production):**
```bash
# Switch to PostgreSQL (from advanced-setup.sh)
./scripts/advanced-setup.sh <CONTAINER_ID> setup-postgres

# Enable PostgreSQL encryption
# Use pgcrypto extension
# Configure SSL certificates
# Use encrypted backups
```

---

## HIGH-RISK VULNERABILITIES

### 🟠 #7: Insufficient Session Security
**File:** [backend/server.js](backend/server.js) - Line 44  
**Severity:** HIGH (8/10)

**Issues:**
- Session secret hardcoded/insufficient (see #2)
- No session rotation after login
- No HTTPS enforcement check (production flag exists but not enforced)
- Session timeout: 24h (consider 1-2h)

**Fix:**
```javascript
app.use(session({
  secret: process.env.SESSION_SECRET, // Fixed in #2
  resave: false,
  saveUninitialized: false,  // Don't create empty sessions
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production' ? true : false,
    sameSite: 'strict',
    maxAge: 1 * 60 * 60 * 1000,  // 1 hour instead of 24h
  },
  name: 'sessionId',  // Don't leak framework name
}));
```

---

### 🟠 #8: API Endpoint Information Leakage
**File:** [backend/server.js](backend/server.js) - Lines 348-356  
**Severity:** HIGH (7/10)

**Issues:**
- `/public/:userId` endpoint leaks user emails via `userName` field
- No rate limiting on public endpoints
- Enumeration attack: iterate IDs to find all users

**Fix:**
```javascript
app.get('/public/:userId', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,  // Rate limit public access too
}), (req, res) => {
  const { userId } = req.params;

  if (!validator.isNumeric(userId) && !validator.isUUID(userId)) {
    return res.status(400).json({ error: 'Invalid user ID' });
  }

  db.get('SELECT id FROM users WHERE id = ?', [userId], (err, user) => {
    if (!user) {
      return res.status(404).json({ error: 'Not found' });
    }

    db.all(
      `SELECT 
        DATE(created_at) as day,
        SUM(calories) as calories
       FROM workouts
       WHERE user_id = ?
       GROUP BY DATE(created_at)
       ORDER BY day DESC
       LIMIT 90`,
      [userId],
      (err, rows) => {
        if (err) {
          return res.status(500).json({ error: 'Failed to fetch data' });
        }
        res.json({
          // Remove: userName: user.email.split('@')[0],
          workouts: rows || [],
        });
      }
    );
  });
});
```

---

### 🟠 #9: Insufficient Input Validation for Duration/Calories
**File:** [backend/server.js](backend/server.js) - Lines 273-288  
**Severity:** HIGH (7/10)

**Issues:**
- Max duration: 14,400 sec (4 hours) OK, but no minimum
- Negative values bypass validation if not checked
- Calories max: 10,000 (unrealistic upper bound)
- Type validation only checks enum (good)

**Fix:**
```javascript
if (typeof duration !== 'number' || duration <= 0 || duration > 14400) {
  return res.status(400).json({ error: 'Invalid duration (1-14400 seconds)' });
}

if (typeof calories !== 'number' || calories < 0 || calories > 5000) {
  return res.status(400).json({ error: 'Invalid calories (0-5000)' });
}
```

---

### 🟠 #10: CORS Misconfiguration Risk
**File:** [backend/server.js](backend/server.js) - Lines 20-25  
**Severity:** HIGH (7/10)

**Issues:**
- CORS origin defaults to `localhost:5173` if env missing
- No port mismatch detection
- `credentials: true` + overly permissive origin = account compromise

**Fix:**
```javascript
const allowedOrigins = (process.env.CORS_ORIGINS || 'http://localhost:5173').split(',');

if (!allowedOrigins.includes('https://') && process.env.NODE_ENV === 'production') {
  console.error('❌ FATAL: CORS must use HTTPS in production');
  process.exit(1);
}

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  allowedHeaders: ['Content-Type', 'X-CSRF-Token'],
  maxAge: 3600,
}));
```

---

## MEDIUM-PRIORITY IMPROVEMENTS

### 🟡 #11: Missing HTTP Security Headers
**File:** [backend/server.js](backend/server.js) - Line 15  
**Severity:** MEDIUM (6/10)

**Issues:**
- Helmet used but headers incomplete
- Missing: X-Content-Type-Options, Content-Security-Policy
- No rate limit on public endpoints

**Fix:**
```javascript
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", process.env.FRONTEND_URL],
    },
  },
  hsts: { maxAge: 31536000, includeSubDomains: true },
  frameguard: { action: 'deny' },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));
```

---

### 🟡 #12: Weak Password Requirements
**File:** [web/src/utils/security.js](web/src/utils/security.js) - Line 68  
**Severity:** MEDIUM (6/10)

**Issues:**
- Minimum password length: 12 characters (good)
- No complexity requirements (uppercase, numbers, special chars)
- Frontend validation not enforced server-side

**Fix (Backend):**
```javascript
// Add comprehensive password validation
function isStrongPassword(password) {
  return (
    password.length >= 12 &&
    /[A-Z]/.test(password) &&  // Uppercase
    /[a-z]/.test(password) &&  // Lowercase
    /[0-9]/.test(password) &&  // Number
    /[!@#$%^&*]/.test(password) // Special char
  );
}

app.post('/auth/register', authLimiter, async (req, res) => {
  const { email, password } = req.body;
  
  if (!isStrongPassword(password)) {
    return res.status(400).json({ 
      error: 'Password must be 12+ chars with uppercase, lowercase, number, special char' 
    });
  }
  // ...
});
```

---

### 🟡 #13: Insufficient Logging of Security Events
**File:** [backend/server.js](backend/server.js) - Line 99-108  
**Severity:** MEDIUM (6/10)

**Issues:**
- Audit log limited to: `user_id, action, ip, timestamp`
- No event type classification
- No failure reason logging
- Failed logins don't distinguish "user not found" vs "bad password"

**Enhancement:**
```javascript
const logAudit = (userId, action, ip, details = {}) => {
  db.run(
    `INSERT INTO audit_log(user_id, action, ip_address, details, timestamp, severity) 
     VALUES (?, ?, ?, ?, datetime("now"), ?)`,
    [userId, action, ip, JSON.stringify(details), details.severity || 'INFO'],
    (err) => {
      if (err) console.error('Audit log error:', err);
      // Also log to external service in production
      if (process.env.SIEM_URL) {
        fetch(process.env.SIEM_URL, {
          method: 'POST',
          body: JSON.stringify({ userId, action, ip, details, timestamp: new Date() })
        }).catch(() => {});
      }
    }
  );
};

// Usage
logAudit(null, 'failed_login', req.ip, {
  email: email,
  reason: 'invalid_credentials',
  severity: 'WARN'
});
```

---

### 🟡 #14: Mobile Token Handling in Plain Text
**File:** [mobile/App.js](mobile/App.js), [mobile/storage.js](mobile/storage.js)  
**Severity:** MEDIUM (7/10)

**Issues:**
- Token passed in Authorization header (OK)
- But stored in AsyncStorage unencrypted (see #4)
- No token refresh mechanism
- Background sync retains old tokens

**Fix:** (See #4 for Keychain implementation)

---

### 🟡 #15: Missing Error Handling in OAuth Flow
**File:** [web/src/contexts/AuthContext.jsx](web/src/contexts/AuthContext.jsx) - Lines 59-71  
**Severity:** MEDIUM (5/10)

**Issues:**
- OAuth state not validated on callback
- No error handling if provider fails
- OAuth/SAML responses not validated for CSRF

**Fix:**
```javascript
const initiateOAuth = useCallback((provider) => {
  // Generate cryptographically secure state
  const state = crypto.getRandomValues(new Uint8Array(32));
  const stateStr = btoa(String.fromCharCode(...state));
  
  sessionStorage.setItem('oauth_state', stateStr);
  sessionStorage.setItem('oauth_provider', provider);
  sessionStorage.setItem('oauth_timestamp', Date.now().toString());
  
  const params = new URLSearchParams({
    client_id: process.env.REACT_APP_OAUTH_CLIENT_ID,
    redirect_uri: `${window.location.origin}/auth/callback`,
    response_type: 'code',
    scope: 'openid profile email',
    state: stateStr,
    provider,
  });

  window.location.href = `${process.env.REACT_APP_API_URL}/auth/oauth?${params.toString()}`;
}, []);
```

---

### 🟡 #16: Watch App Security Gaps
**File:** [watch/UserCalibration.swift](watch/UserCalibration.swift)  
**Severity:** MEDIUM (6/10)

**Issues:**
- UserDefaults stores sensitive calibration data in plaintext
- No encryption for motion classification models
- No authentication to backend (future enhancement)
- Accelerometer/gyroscope data unencrypted

**Fix:**
```swift
import CryptoKit

struct UserCalibration {
  private let key = "user_calibration"
  private let encryptionKey = try! SymmetricKey(size: .bits256)
  
  mutating func save(calibration: CalibrationData) {
    let encoder = JSONEncoder()
    let data = try! encoder.encode(calibration)
    
    let sealedBox = try! AES.GCM.seal(data, using: encryptionKey)
    UserDefaults.standard.set(sealedBox.combined, forKey: key)
  }
  
  func load() -> CalibrationData? {
    guard let encryptedData = UserDefaults.standard.data(forKey: key) else { return nil }
    let sealedBox = try! AES.GCM.SealedBox(combined: encryptedData)
    let data = try! AES.GCM.open(sealedBox, using: encryptionKey)
    return try! JSONDecoder().decode(CalibrationData.self, from: data)
  }
}
```

---

### 🟡 #17: Public Endpoint Abuse / ID Enumeration
**File:** [backend/server.js](backend/server.js) - Line 348  
**Severity:** MEDIUM (5/10)

**Issues:**
- `/public/:userId` accepts any numeric ID
- No throttling prevents enumeration
- Attacker can iterate 1-9999 to find all users

**Fix:** (Already covered in #8 + add UUID requirement)

---

### 🟡 #18: Database Backup Encryption
**File:** [scripts/all-in-one-worktrack.sh](scripts/all-in-one-worktrack.sh)  
**Severity:** MEDIUM (6/10)

**Issues:**
- Backups stored unencrypted
- No backup integrity verification
- Backup retention unclear

**Fix:**
```bash
backup_database() {
  local backup_file="/opt/backups/worktrack-db-$(date +%Y%m%d-%H%M%S).sql.gpg"
  
  # Backup with encryption
  sudo -u postgres pg_dump worktrack | \
    gpg --trust-model always --encrypt \
        -r "backup@worktrack.local" \
        > "$backup_file"
  
  # Verify integrity
  gpg --verify "$backup_file" || exit 1
  
  # Rotate backups (keep 30 days)
  find /opt/backups -name "*.sql.gpg" -mtime +30 -delete
  
  chmod 600 "$backup_file"
}
```

---

## LOW-PRIORITY ENHANCEMENTS

### 🟢 #19: Add 2FA/MFA Support
**Priority:** LOW (nice to have)  
**Recommendation:** Implement TOTP (Time-based One-Time Password)  

```bash
npm install speakeasy qrcode
```

---

### 🟢 #20: Rate Limiting Needs Tuning
**Current:** 5 auth/15min, 100 global/15min  
**Recommendation:**
- Auth: 3 attempts / 15 min per email
- Workout POST: 100/min per user
- Public endpoint: 30/min per IP

---

## REMEDIATION PRIORITY MATRIX

| Priority | Items | Timeline | Effort | Impact |
|----------|-------|----------|--------|--------|
| 🔴 CRITICAL | #1, #2, #3, #4, #5, #6 | IMMEDIATE | 4-6 hrs | 10/10 |
| 🟠 HIGH | #7, #8, #9, #10 | 24 hours | 2-3 hrs | 7-8/10 |
| 🟡 MEDIUM | #11-18 | 1 week | 4-6 hrs | 5-6/10 |
| 🟢 LOW | #19, #20 | 2 weeks | 2-3 hrs | 3-4/10 |

---

## DEPLOYMENT CHECKLIST

- [ ] All CRITICAL items fixed and tested
- [ ] Environment variables validated on startup
- [ ] CSRF tokens enforced on all state-changing endpoints
- [ ] Database encryption enabled
- [ ] HTTPS forced in production
- [ ] Security headers complete
- [ ] OAuth/SAML state validation implemented
- [ ] Rate limiting tuned
- [ ] Backup encryption enabled
- [ ] Audit logging to external SIEM
- [ ] Penetration testing completed
- [ ] Security headers verified (use https://securityheaders.com)

---

## Recommended Next Steps

1. **Immediate (Next 4 hours):**
   - Fix hardcoded secrets (#1, #2)
   - Implement CSRF validation (#5)
   - Remove JWT from response body (#3)

2. **Short-term (Next 24 hours):**
   - Encrypt database (#6)
   - Secure mobile token storage (#4)
   - Fix CORS and HTTP headers (#7, #10, #11)

3. **Medium-term (Next week):**
   - Implement comprehensive logging (#13)
   - Add password complexity (#12)
   - Enable backup encryption (#18)

4. **Long-term (Before production):**
   - Implement 2FA (#19)
   - Penetration testing
   - Security audit by external firm

---

**Generated by:** Security Audit Agent  
**Report Status:** 🟠 Action Required  
**Next Review:** After remediation completion

