# Workout Tracker - Web App

Secure, production-ready React web application with OAuth/SSO/SAML authentication.

## Setup

### Prerequisites
- Node.js 18+
- npm 9+

### Installation

```bash
cd web
npm install
```

### Development

```bash
npm run dev
```

Opens at `http://localhost:5173`

### Production Build

```bash
npm run build
```

## Architecture

### File Structure

```
src/
├── pages/
│   ├── LoginPage.jsx          # Auth UI with OAuth/SAML
│   ├── OAuthCallback.jsx      # OAuth callback handler
│   ├── SAMLCallback.jsx       # SAML callback handler
│   └── PublicPage.jsx         # Public profile sharing
├── components/
│   └── Charts.jsx             # Workout trend charts
├── contexts/
│   └── AuthContext.jsx        # Global auth state
├── utils/
│   └── security.js            # XSS, CSRF, validation
├── dashboard.jsx              # Authenticated dashboard
├── app.jsx                    # App routing
└── main.jsx                   # Entry point
```

### Key Features

- **Multi-Auth Support**: Email/password, OAuth2 (Google/GitHub), SAML
- **Offline-Ready**: Progressive enhancement for offline
- **XSS/CSRF Protected**: Sanitization, CSRF tokens, secure headers
- **Rate Limiting**: Prevents brute force attacks
- **Input Validation**: Email, password, workout data
- **Audit Logging**: Security events tracked server-side

## Security Implementation

### Frontend Security (`utils/security.js`)

```javascript
// XSS Protection
sanitizeInput(userText)      // Removes HTML tags
sanitizeHTML(htmlContent)    // Allows safe tags only

// CSRF Protection
getCSRFToken()               // Gets/generates CSRF token
secureApiCall(url, options)  // Adds CSRF token to requests

// Input Validation
validators.email(email)
validators.password(password)
validators.workoutType(type)

// Rate Limiting
createRateLimiter(maxAttempts, windowMs)
```

### Authentication Flow

```
User Login/Register
    ↓
Rate Limit Check (5/15min)
    ↓
Input Validation (email, password)
    ↓
Secure API Call (CSRF token, httpOnly cookies)
    ↓
JWT Token in httpOnly Cookie
    ↓
Authenticated Request (Bearer token in header)
```

### OAuth/SAML Flow

```
User clicks OAuth/SAML button
    ↓
Generate state parameter (CSRF protection)
    ↓
Redirect to provider login
    ↓
Provider redirects to /auth/callback with code
    ↓
Validate state parameter
    ↓
Exchange code for token
    ↓
Set httpOnly cookie
    ↓
Redirect to dashboard
```

## API Endpoints

### Authentication

- `POST /auth/register` - Register new user
- `POST /auth/login` - Login with email/password
- `POST /auth/logout` - Logout user
- `GET /auth/session` - Check current session
- `POST /auth/csrf-token` - Get CSRF token
- `GET /auth/oauth` - Initiate OAuth flow
- `POST /auth/oauth/callback` - Handle OAuth callback
- `GET /auth/saml/login` - Initiate SAML login
- `POST /auth/saml/callback` - Handle SAML assertion

### Workouts

- `POST /workouts` - Log new workout (authenticated)
- `GET /analytics/summary` - Workout summary stats (authenticated)
- `GET /analytics/trends` - 30-day trends (authenticated)

### Public

- `GET /public/:userId` - Public profile (no auth required)

## Environment Variables

```env
REACT_APP_OAUTH_CLIENT_ID=your-oauth-client-id
REACT_APP_API_URL=http://localhost:3001
```

## Security Best Practices

✅ **Implemented**

- Parameterized queries (no SQL injection)
- Input/output sanitization (no XSS)
- CSRF tokens on state-changing requests
- Rate limiting on auth endpoints
- HTTPS-only cookies (production)
- httpOnly flag prevents JavaScript access
- SameSite=Strict prevents cross-site requests
- Helmet.js security headers
- Audit logging
- Password hashing (bcrypt 12 rounds)

⚠️ **Consider for Future**

- 2FA (TOTP, WebAuthn)
- Device fingerprinting
- API key management
- Refresh token rotation
- Security event webhooks
- SIEM integration

See [SECURITY.md](../SECURITY.md) for full security documentation.

## Common Issues

**OAuth redirect_uri mismatch**
- Ensure `http://localhost:5173/auth/callback` is registered in OAuth provider settings

**CORS errors**
- Check backend CORS configuration in server.js
- Ensure `FRONTEND_URL` env var matches your domain

**Cookie not persisting**
- Use `credentials: 'include'` in fetch calls
- Check browser's Allow-Cookies setting for localhost

## Performance

- Code splitting via React Router
- Lazy-loaded components
- Optimized Chart.js rendering
- Efficient re-renders with useCallback/useMemo
