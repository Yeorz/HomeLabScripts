import express from 'express';
import sqlite3 from 'sqlite3';
import cors from 'cors';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import session from 'express-session';
import cookieParser from 'cookie-parser';
import validator from 'validator';
import crypto from 'crypto';
import csurf from 'csurf';

// Validate required environment variables on startup
const requiredEnvVars = ['JWT_SECRET', 'SESSION_SECRET'];
requiredEnvVars.forEach(envVar => {
  if (!process.env[envVar]) {
    console.error(`\nFATAL ERROR: ${envVar} environment variable not set`);
    console.error('Set required variables:');
    console.error(`  export ${envVar}=$(openssl rand -base64 32)`);
    process.exit(1);
  }
});

const app = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", process.env.FRONTEND_URL || 'http://localhost:5173'],
      frameAncestors: ["'none'"],
    },
  },
  hsts: { maxAge: 31536000, includeSubDomains: true },
  frameguard: { action: 'deny' },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));
app.use(cookieParser());

// CORS with proper origin validation
const allowedOrigins = (process.env.CORS_ORIGINS || process.env.FRONTEND_URL || 'http://localhost:5173').split(',');
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.some(allowed => origin.includes(allowed.trim()))) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  allowedHeaders: ['Content-Type', 'X-CSRF-Token'],
  maxAge: 3600,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true,
});

app.use(limiter);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session middleware with hardened settings
app.use(session({
  secret: process.env.SESSION_SECRET,  // No fallback - env var required
  resave: false,
  saveUninitialized: false,  // Don't create empty sessions
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production' ? true : false,
    sameSite: 'strict',
    maxAge: 1 * 60 * 60 * 1000,  // Reduced to 1 hour
  },
  name: 'sessionId',  // Don't leak framework name
}));

// CSRF protection middleware
const csrfProtection = csurf({
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
  },
});

const db = new sqlite3.Database('db.sqlite');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  email TEXT UNIQUE,
  password TEXT,
  oauth_provider TEXT,
  oauth_id TEXT,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS workouts (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  type TEXT,
  duration INTEGER,
  calories INTEGER,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  action TEXT,
  ip_address TEXT,
  timestamp TEXT
);
`);

const generateToken = (userId) => {
  return jwt.sign(
    { id: userId, iat: Math.floor(Date.now() / 1000) },
    process.env.JWT_SECRET,  // No fallback
    { expiresIn: '24h' }
  );
};

const verifyToken = (token) => {
  try {
    return jwt.verify(token, process.env.JWT_SECRET);
  } catch (err) {
    return null;
  }
};

const logAudit = (userId, action, ip) => {
  db.run(
    'INSERT INTO audit_log(user_id, action, ip_address, timestamp) VALUES (?, ?, ?, datetime("now"))',
    [userId, action, ip],
    (err) => {
      if (err) console.error('Audit log error:', err);
    }
  );
};

const auth = (req, res, next) => {
  const token = req.cookies.token || req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const decoded = verifyToken(token);
  if (!decoded) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }

  req.user = decoded;
  next();
};

app.get('/auth/csrf-token', csrfProtection, (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});

app.post('/auth/register', csrfProtection, authLimiter, async (req, res) => {
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

app.post('/auth/login', csrfProtection, authLimiter, async (req, res) => {
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

      res.json({ user: { id: user.id, email: user.email } });
    });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/auth/session', (req, res) => {
  const token = req.cookies.token || req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ user: null });
  }

  const decoded = verifyToken(token);
  if (!decoded) {
    return res.status(401).json({ user: null });
  }

  db.get('SELECT id, email FROM users WHERE id = ?', [decoded.id], (err, user) => {
    if (!user) {
      return res.status(401).json({ user: null });
    }
    res.json({ user });
  });
});

app.post('/auth/logout', csrfProtection, (req, res) => {
  res.clearCookie('token');
  res.clearCookie('sessionId');
  res.json({ ok: true });
});

app.post('/workouts', csrfProtection, auth, (req, res) => {
  try {
    const { type, duration, calories } = req.body;

    if (!type || !duration || calories === undefined) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    if (!['Strength', 'Cardio', 'Flexibility'].includes(type)) {
      return res.status(400).json({ error: 'Invalid workout type' });
    }

    if (typeof duration !== 'number' || duration <= 0 || duration > 14400) {
      return res.status(400).json({ error: 'Invalid duration (1-14400 seconds)' });
    }

    if (typeof calories !== 'number' || calories < 0 || calories > 5000) {
      return res.status(400).json({ error: 'Invalid calories (0-5000)' });
    }

    db.run(
      'INSERT INTO workouts(user_id, type, duration, calories, created_at) VALUES (?, ?, ?, ?, datetime("now"))',
      [req.user.id, type, duration, calories],
      function(err) {
        if (err) {
          return res.status(500).json({ error: 'Failed to log workout' });
        }
        logAudit(req.user.id, 'log_workout', req.ip);
        res.json({ id: this.lastID, ok: true });
      }
    );
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/analytics/summary', auth, (req, res) => {
  db.all(
    `SELECT 
      type,
      COUNT(*) as sessions,
      SUM(duration) as total_minutes,
      SUM(calories) as calories
     FROM workouts
     WHERE user_id = ?
     GROUP BY type`,
    [req.user.id],
    (err, rows) => {
      if (err) {
        return res.status(500).json({ error: 'Failed to fetch summary' });
      }
      res.json(rows || []);
    }
  );
});

app.get('/analytics/trends', auth, (req, res) => {
  db.all(
    `SELECT 
      DATE(created_at) as day,
      SUM(calories) as calories,
      SUM(duration)/60 as minutes
     FROM workouts
     WHERE user_id = ?
     GROUP BY DATE(created_at)
     ORDER BY day DESC
     LIMIT 30`,
    [req.user.id],
    (err, rows) => {
      if (err) {
        return res.status(500).json({ error: 'Failed to fetch trends' });
      }
      res.json(rows || []);
    }
  );
});

app.get('/public/:userId', (req, res) => {
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
          return res.status(500).json({ error: 'Failed to fetch public data' });
        }
        res.json({
          workouts: rows || [],
        });
      }
    );
  });
});

app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(3001, () => {
  console.log('Backend running on http://localhost:3001');
});