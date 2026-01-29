# Web App Security Configuration

## Environment Variables

Create a `.env` file in the backend directory with:

```env
# Server
NODE_ENV=development
PORT=3001
FRONTEND_URL=http://localhost:5173

# Security
JWT_SECRET=your-very-long-random-jwt-secret-key-here
SESSION_SECRET=your-very-long-random-session-secret-key-here

# OAuth (configure with your providers)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret

# SAML (optional)
SAML_ENTRY_POINT=https://your-idp.example.com/sso
SAML_CERT=your-saml-certificate
```

Create `.env` in the web directory with:

```env
REACT_APP_OAUTH_CLIENT_ID=your-oauth-client-id
REACT_APP_API_URL=http://localhost:3001
```

## Security Features Implemented

### 1. **Authentication & Authorization**
- JWT tokens with 24-hour expiration
- Secure httpOnly cookies (prevent XSS access)
- Session-based authentication
- Rate limiting on auth endpoints (5 attempts/15 min)

### 2. **XSS Protection**
- DOMPurify sanitization for user input
- No innerHTML usage, only textContent
- Content Security Policy headers (via helmet)
- Input validation on all forms

### 3. **CSRF Protection**
- CSRF token generation per session
- Validation on state-changing requests (POST, PUT, DELETE)
- SameSite=Strict cookies
- CSRF token in X-CSRF-Token header

### 4. **Injection Prevention**
- SQL parameterized queries (prepared statements)
- Input validation with validator.js
- Email validation before storage
- Workout data type checking

### 5. **HTTPS & Transport Security**
- HSTS (HTTP Strict Transport Security) headers
- Secure flag on cookies (production only)
- SameSite=Strict cookie policy
- CORS with strict origin validation

### 6. **Rate Limiting**
- Global rate limit: 100 requests/15 min per IP
- Auth-specific: 5 attempts/15 min per user
- Prevents brute force attacks

### 7. **Data Protection**
- Passwords hashed with bcrypt (12 rounds)
- Sensitive data in httpOnly cookies
- Audit logging for security events
- Input/output sanitization

### 8. **OAuth/SSO/SAML**
- State parameter validation (CSRF protection)
- Secure callback handling
- Support for Google, GitHub, and enterprise SAML
- User creation/linking with OAuth providers

## Development vs Production

### Development (http://localhost:5173)
- Cookies not restricted to HTTPS
- CORS allows localhost
- Rate limiting more lenient
- Audit logs to console

### Production
- All cookies require HTTPS
- CORS restricts to configured origin
- Stricter rate limiting
- Audit logs to external service (recommended)

## Testing Security

```bash
# Test rate limiting
for i in {1..10}; do curl -X POST http://localhost:3001/auth/login -d '{}'; done

# Test CSRF (should fail without token)
curl -X POST http://localhost:3001/auth/logout

# Test SQL injection (should be safe)
curl -X POST http://localhost:3001/auth/login -d '{"email":"admin\\" OR 1=1--","password":"test"}'

# Test XSS (should be sanitized)
curl http://localhost:3001/public/1
```

## Future Enhancements

- [ ] Implement 2FA (TOTP/WebAuthn)
- [ ] Add API key management for integrations
- [ ] Implement refresh token rotation
- [ ] Add device fingerprinting
- [ ] Enable security event webhooks
- [ ] Setup SIEM/intrusion detection
