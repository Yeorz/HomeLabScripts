# 🔐 WorkTrack Security Remediation Guide
**Priority:** CRITICAL  
**Estimated Time:** 4-6 hours for critical fixes  

---

## IMMEDIATE FIXES (Do This Now)

### Fix #1: Replace Hardcoded Secrets - auth.js

**Before:**
```javascript
// backend/auth.js
import jwt from "jsonwebtoken";

export function auth(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.sendStatus(401);
  try {
    req.user = jwt.verify(token, "secret");  // ⚠️ HARDCODED SECRET
    next();
  } catch {
    res.sendStatus(403);
  }
}
```

**After:**
```javascript
// backend/auth.js
import jwt from "jsonwebtoken";

if (!process.env.JWT_SECRET) {
  throw new Error('FATAL: JWT_SECRET environment variable not set');
}

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

**Action:**
```bash
# 1. Update the file
# 2. Add to .env
echo "JWT_SECRET=$(openssl rand -base64 32)" >> backend/.env

# 3. Restart backend
npm restart
```

---

### Fix #2: Replace Hardcoded Fallback Secrets - server.js

**Before:**
```javascript
// Lines 43-44
app.use(session({
  secret: process.env.SESSION_SECRET || 'super-secret-session-key',  // ⚠️ FALLBACK SECRET
  // ...
}));

// Lines 88-89
const generateToken = (userId) => {
  return jwt.sign(
    { id: userId, iat: Math.floor(Date.now() / 1000) },
    process.env.JWT_SECRET || 'super-secret-jwt-key',  // ⚠️ FALLBACK SECRET
    { expiresIn: '24h' }
  );
};
```

**After:**
```javascript
// Startup validation - ADD AT TOP OF FILE
const requiredEnvVars = ['JWT_SECRET', 'SESSION_SECRET'];
requiredEnvVars.forEach(envVar => {
  if (!process.env[envVar]) {
    console.error(`\n❌ FATAL ERROR: ${envVar} environment variable not set`);
    console.error('Set required variables:');
    console.error('  export JWT_SECRET=$(openssl rand -base64 32)');
    console.error('  export SESSION_SECRET=$(openssl rand -base64 32)');
    process.exit(1);
  }
});

// Session middleware - Lines 43-44
app.use(session({
  secret: process.env.SESSION_SECRET,  // ✅ NO FALLBACK
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 1 * 60 * 60 * 1000,  // Reduced to 1 hour
  },
}));

// Token generation - Lines 88-89
const generateToken = (userId) => {
  return jwt.sign(
    { id: userId, iat: Math.floor(Date.now() / 1000) },
    process.env.JWT_SECRET,  // ✅ NO FALLBACK
    { expiresIn: '24h' }
  );
};

// Token verification
const verifyToken = (token) => {
  try {
    return jwt.verify(token, process.env.JWT_SECRET);  // ✅ NO FALLBACK
  } catch (err) {
    return null;
  }
};
```

**Action:**
```bash
# Generate secrets
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)

# Add to backend/.env
cat >> backend/.env << EOF
JWT_SECRET=$JWT_SECRET
SESSION_SECRET=$SESSION_SECRET
EOF

# Or add to .env.production separately
```

---

### Fix #3: Remove JWT from Response Body

**Before:**
```javascript
// Lines 200-204, 233-238
app.post('/auth/register', authLimiter, async (req, res) => {
  // ...
  res.json({ user: { id: this.lastID, email }, token });  // ⚠️ TOKEN EXPOSED
});

app.post('/auth/login', authLimiter, async (req, res) => {
  // ...
  res.json({ user: { id: user.id, email: user.email }, token });  // ⚠️ TOKEN EXPOSED
});
```

**After:**
```javascript
app.post('/auth/register', authLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    if (!validator.isEmail(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    if (password.length < 12) {
      return res.status(400).json({ error: 'Password must be at least 12 characters' });
    }

    db.get('SELECT id FROM users WHERE email = ?', [email], async (err, existing) => {
      if (existing) {
        return res.status(409).json({ error: 'Email already registered' });
      }

      try {
        const hash = await bcrypt.hash(password, 12);
        db.run(
          'INSERT INTO users(email, password, created_at) VALUES (?, ?, datetime("now"))',
          [email, hash],
          function(err) {
            if (err) {
              return res.status(500).json({ error: 'Registration failed' });
            }

            logAudit(this.lastID, 'register', req.ip);
            const token = generateToken(this.lastID);
            
            res.cookie('token', token, {
              httpOnly: true,
              secure: process.env.NODE_ENV === 'production',
              sameSite: 'strict',
            });

            // ✅ ONLY RETURN USER DATA, NOT TOKEN
            res.json({ user: { id: this.lastID, email } });
          }
        );
      } catch (err) {
        res.status(500).json({ error: 'Registration failed' });
      }
    });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/auth/login', authLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    db.get('SELECT * FROM users WHERE email = ?', [email], async (err, user) => {
      if (!user || !(await bcrypt.compare(password, user.password))) {
        logAudit(null, 'failed_login', req.ip);
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      logAudit(user.id, 'login', req.ip);
      const token = generateToken(user.id);

      res.cookie('token', token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
      });

      // ✅ ONLY RETURN USER DATA, NOT TOKEN
      res.json({ user: { id: user.id, email: user.email } });
    });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});
```

---

### Fix #4: Encrypt Mobile Token Storage

**Before:**
```javascript
// mobile/storage.js
const WORKOUT_KEY = 'pending_workouts';

export async function saveWorkoutOffline(workout) {
  const existing = JSON.parse(await AsyncStorage.getItem(WORKOUT_KEY)) || [];
  existing.push(workout);  // ⚠️ INCLUDES TOKEN IN PLAINTEXT
  await AsyncStorage.setItem(WORKOUT_KEY, JSON.stringify(existing));
}

export async function syncPendingWorkouts(token) {
  // Token passed around, stored in memory
  // ...
}
```

**After:**
```javascript
// mobile/storage.js
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Keychain from 'react-native-keychain';

const WORKOUT_KEY = 'pending_workouts';
const TOKEN_SERVICE = 'com.worktrack.jwt';

// ✅ SECURE TOKEN STORAGE
export async function saveTokenSecurely(token) {
  try {
    await Keychain.setGenericPassword(TOKEN_SERVICE, token, {
      accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED,
      storage: Keychain.STORAGE_TYPE.KC_ITEM_ATTRIBUTE_VALUE_TYPE_SECURE_UTF8_STR,
    });
  } catch (error) {
    console.error('Failed to save token:', error);
  }
}

export async function getTokenSecurely() {
  try {
    const credentials = await Keychain.getGenericPassword({
      service: TOKEN_SERVICE,
    });
    return credentials ? credentials.password : null;
  } catch (error) {
    console.error('Failed to retrieve token:', error);
    return null;
  }
}

export async function deleteTokenSecurely() {
  try {
    await Keychain.resetGenericPassword({ service: TOKEN_SERVICE });
  } catch (error) {
    console.error('Failed to delete token:', error);
  }
}

// ✅ SAVE WORKOUTS WITHOUT TOKEN
export async function saveWorkoutOffline(workout) {
  try {
    const existing = JSON.parse(await AsyncStorage.getItem(WORKOUT_KEY)) || [];
    // Remove token from stored data
    const { token, ...workoutWithoutToken } = workout;
    existing.push({
      ...workoutWithoutToken,
      savedAt: new Date().toISOString(),
    });
    await AsyncStorage.setItem(WORKOUT_KEY, JSON.stringify(existing));
  } catch (error) {
    console.error('Failed to save workout:', error);
  }
}

// ✅ FETCH TOKEN AT SYNC TIME
export async function syncPendingWorkouts() {
  try {
    const token = await getTokenSecurely();  // Retrieve from secure storage
    if (!token) {
      console.error('No token available for sync');
      return;
    }

    const existing = JSON.parse(await AsyncStorage.getItem(WORKOUT_KEY)) || [];
    if (existing.length === 0) return;

    const remaining = [];
    for (let workout of existing) {
      try {
        const res = await fetch("http://localhost:3001/workouts", {
          method: "POST",
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,  // ✅ TOKEN FROM KEYCHAIN
          },
          body: JSON.stringify(workout),
        });
        if (!res.ok) remaining.push(workout);
      } catch {
        remaining.push(workout);
      }
    }
    await AsyncStorage.setItem(WORKOUT_KEY, JSON.stringify(remaining));
  } catch (error) {
    console.error('Sync failed:', error);
  }
}
```

**Installation:**
```bash
cd mobile
npm install react-native-keychain
npx react-native link react-native-keychain
```

---

### Fix #5: Implement CSRF Protection

**Before:**
```javascript
// backend/server.js
app.post('/workouts', auth, (req, res) => {
  // ⚠️ NO CSRF VALIDATION
  // ...
});
```

**After:**
```bash
# Install CSRF package
npm install csurf
```

```javascript
// Add to backend/server.js (after imports)
import csrf from 'csurf';

// CSRF middleware
const csrfProtection = csrf({ 
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
  }
});

// Add CSRF token endpoint
app.get('/auth/csrf-token', csrfProtection, (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});

// Apply to all state-changing endpoints
app.post('/auth/register', csrfProtection, authLimiter, async (req, res) => {
  // Token validated automatically
  // ...
});

app.post('/auth/login', csrfProtection, authLimiter, async (req, res) => {
  // Token validated automatically
  // ...
});

app.post('/workouts', csrfProtection, auth, (req, res) => {
  // ✅ CSRF TOKEN VALIDATED
  // ...
});

app.post('/auth/logout', csrfProtection, (req, res) => {
  res.clearCookie('token');
  res.clearCookie('csrf_token');
  res.json({ ok: true });
});
```

**Frontend Update:**
```javascript
// web/src/utils/security.js
export const secureApiCall = async (url, options = {}) => {
  // ✅ FETCH CSRF TOKEN FROM BACKEND
  const csrfResponse = await fetch('http://localhost:3001/auth/csrf-token', {
    credentials: 'include',
  });
  const { csrfToken } = await csrfResponse.json();
  
  const headers = {
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken,  // ✅ FROM BACKEND
    ...options.headers,
  };

  const response = await fetch(url, {
    ...options,
    headers,
    credentials: 'include',
  });

  if (!response.ok) {
    const error = new Error(`API Error: ${response.status}`);
    error.status = response.status;
    throw error;
  }

  return response.json();
};
```

---

### Fix #6: Enable Database Encryption (SQLite)

**Option A: SQLite Cipher (Recommended for SQLite)**

```bash
# 1. Install SQLite with encryption support
brew install sqlcipher

# 2. Or rebuild sqlite3 package with cipher support
npm uninstall sqlite3
npm install sqlcipher

# 3. Create backend/db.js
```

**backend/db.js:**
```javascript
import sqlite3 from 'sqlite3';

// Enable encryption
const db = new sqlite3.Database('db.sqlite');

// Set encryption password
const encryptionPassword = process.env.SQLITE_CIPHER_KEY;

if (!encryptionPassword) {
  console.error('FATAL: SQLITE_CIPHER_KEY not set');
  process.exit(1);
}

db.run(`PRAGMA key = '${encryptionPassword.replace(/'/g, "''")}'`, (err) => {
  if (err) {
    console.error('Failed to set encryption key:', err);
    process.exit(1);
  }
  console.log('✅ Database encryption enabled');
});

export default db;
```

**Option B: Long-term - Switch to PostgreSQL (Production)**

```bash
# Run from deployment script
./scripts/advanced-setup.sh <CONTAINER_ID> setup-postgres
```

**.env setup:**
```env
DATABASE_URL=postgresql://worktrack:PASSWORD@localhost/worktrack
SQLITE_CIPHER_KEY=$(openssl rand -base64 32)
```

---

## TESTING YOUR FIXES

### Test #1: Verify Secrets Required
```bash
# Should fail without env vars
unset JWT_SECRET
unset SESSION_SECRET
npm start
# Expected: "FATAL: JWT_SECRET environment variable not set"
```

### Test #2: Verify CSRF Protection
```bash
# Should fail without CSRF token
curl -X POST http://localhost:3001/workouts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"Strength","duration":30,"calories":100}'

# Should return: 403 Forbidden (CSRF failure)
```

### Test #3: Verify Token Not in Response
```bash
curl -s -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Password123!"}' | jq .

# Should NOT contain "token" field, only "user"
```

### Test #4: Verify Token in Cookie
```bash
curl -s -i -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Password123!"}' | grep -i "set-cookie"

# Should see: Set-Cookie: token=...; HttpOnly; SameSite=Strict
```

---

## DEPLOYMENT STEPS

### Pre-deployment Checklist
```bash
# 1. Generate all secrets
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
SQLITE_CIPHER_KEY=$(openssl rand -base64 32)

# 2. Create .env.production
cat > backend/.env.production << EOF
NODE_ENV=production
PORT=3001
FRONTEND_URL=https://your-domain.com
JWT_SECRET=$JWT_SECRET
SESSION_SECRET=$SESSION_SECRET
SQLITE_CIPHER_KEY=$SQLITE_CIPHER_KEY
CORS_ORIGINS=https://your-domain.com
EOF

# 3. Test locally
source backend/.env.production
npm run dev

# 4. Run security tests (see above)

# 5. Commit (without .env values!)
git add backend/server.js backend/auth.js
git commit -m "fix: Critical security fixes - hardcoded secrets, CSRF, JWT exposure"

# 6. Deploy with env vars
docker run \
  -e JWT_SECRET="$JWT_SECRET" \
  -e SESSION_SECRET="$SESSION_SECRET" \
  -e SQLITE_CIPHER_KEY="$SQLITE_CIPHER_KEY" \
  worktrack-backend
```

---

## TIMELINE

| Step | Duration | Components |
|------|----------|------------|
| 1. Fix secrets | 30 min | auth.js, server.js |
| 2. Remove JWT from response | 15 min | server.js |
| 3. Add CSRF | 45 min | server.js, security.js |
| 4. Secure mobile tokens | 1 hr | storage.js, App.js |
| 5. Database encryption | 30 min | db.js setup |
| 6. Testing | 1 hr | All endpoints |
| 7. Documentation | 30 min | Update README |
| **TOTAL** | **~4-5 hours** | |

---

## Next Priority Fixes (Within 24 hours)

After critical fixes above, prioritize:
1. HTTP Security Headers (#11)
2. CORS Validation (#10)
3. Rate Limiting Tuning (#20)
4. Comprehensive Logging (#13)

See `SECURITY_AUDIT_REPORT.md` for detailed guidance.

