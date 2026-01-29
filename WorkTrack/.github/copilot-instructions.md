# WorkTrack Codebase Instructions for AI Agents

## Architecture Overview

WorkTrack is a multi-platform workout tracking system with four core components:

- **Backend** (`backend/`): Express.js + SQLite3. Handles secure auth (JWT + httpOnly cookies), OAuth/SAML, workout CRUD, and analytics via REST API. Security: helmet, rate-limit, CSRF protection, input validation, audit logging.
- **Web** (`web/`): React SPA with OAuth/SSO/SAML support. Authenticated dashboard, public shareable profiles. React Router for routing. Security: XSS sanitization (DOMPurify), CSRF tokens, input validation, secure API calls.
- **iOS** (`ios/`): Native SwiftUI app with offline-first architecture. Stores pending workouts in UserDefaults, syncs via NWPathMonitor. JWT auth tokens in UserDefaults.
- **Watch** (`watch/`): iOS watchOS app with ML-based motion classification. Classifies workouts using accelerometer/gyroscope data.

## Critical Data Flows

1. **Authentication**: JWT tokens in httpOnly cookies (secure, not accessible to JavaScript). Bearer token in Authorization headers. OAuth2 (Google/GitHub) and SAML support for enterprise. Rate-limited auth endpoints.
2. **Workout Sync Pipeline**: App captures workouts → stores offline if no network → syncs via POST to `/workouts` when connected
3. **ML Classification**: Watch collects 50-sample motion buffer (0.1s intervals) → FeatureExtractor transforms data → MotionClassifier predicts activity type
4. **Security**: Frontend input sanitization (DOMPurify), CSRF tokens, backend parameterized queries, rate limiting, helmet headers, audit logging

## Key Files by Function

| Pattern | File | Purpose |
|---------|------|---------|
| Auth middleware | [backend/auth.js](backend/auth.js) or [backend/server.js](backend/server.js#L100-L120) | JWT verification for protected routes |
| DB schema | [backend/server.js](backend/server.js#L51-L76) | SQLite tables: users, workouts, audit_log |
| Web auth context | [web/src/contexts/AuthContext.jsx](web/src/contexts/AuthContext.jsx) | OAuth/SAML flows, session management |
| Web security utils | [web/src/utils/security.js](web/src/utils/security.js) | XSS sanitization, CSRF protection, validation |
| iOS app entry | [ios/WorkoutTracker/WorkoutTrackerApp.swift](ios/WorkoutTracker/WorkoutTrackerApp.swift) | SwiftUI app root, auth routing |
| iOS auth manager | [ios/WorkoutTracker/Managers/AuthManager.swift](ios/WorkoutTracker/Managers/AuthManager.swift) | JWT login/register, token persistence |
| iOS sync logic | [ios/WorkoutTracker/Managers/WorkoutManager.swift](ios/WorkoutTracker/Managers/WorkoutManager.swift) | Offline queue, background sync |
| ML feature extraction | [watch/MLFeatureExtractor.swift](watch/MLFeatureExtractor.swift) | Transforms motion samples to model input |

## Project-Specific Conventions

1. **Port Setup**: Backend runs on 3001, Web on 5173 (Vite default). Both configured in docker-compose.yml and package.json
2. **Token Management**: JWT tokens stored in httpOnly cookies (cannot be accessed by JavaScript). Replace hardcoded "secret" with env var `JWT_SECRET` in production
3. **Offline-First Mobile**: iOS app always attempts POST to backend; catches errors and queues in UserDefaults as fallback
4. **ML Model Location**: CoreML model at `watch/ExerciseClassifierV2.mlmodel` via MLModel framework
5. **CORS Enabled**: Backend uses cors() middleware; web/mobile communicate via configured origin
6. **XSS/CSRF Protection**: DOMPurify sanitizes input on frontend, CSRF tokens on requests, parameterized queries on backend
7. **Rate Limiting**: 5 auth attempts/15 min, 100 global requests/15 min per IP

## Development Workflows

```bash
# Full stack setup (docker backend + web)
docker-compose up

# Individual services
cd backend && npm install && npm run dev
cd web && npm install && npm run dev

# iOS app (native)
cd ios && open WorkoutTracker.xcodeproj
# Then in Xcode: select target, device/simulator, Cmd+R

# Watch: Open in Xcode, cmd+R to build/run
```

## Integration Points

- **Mobile ↔ Backend**: REST API at `http://localhost:3001` (change URL for prod)
- **Web ↔ Backend**: Same endpoint, localStorage persists token
- **Watch ↔ Backend**: Currently standalone (sends to HealthKit, not API)—future enhancement needed for watch-to-server sync
- **Database**: SQLite file at `backend/db.sqlite` persists across restarts

## Important Gotchas

## Important Gotchas

- Watch app requires Xcode and physical device/simulator (not in docker-compose)
- iOS UserDefaults key is `pending_workouts`—changing it breaks offline queue recovery
- Web Dashboard requires auth; public pages accessible via `/public/{userId}` without token (no auth token needed)
- ML model requires retraining if motion sensor hardware changes significantly
- iOS app token stored with key `jwt_token` in UserDefaults
- Backend JWT_SECRET must be 32+ characters random string, not "secret"
- OAuth/SAML callbacks must be registered with providers (e.g., `http://localhost:5173/auth/callback`)
- CSRF tokens validated on all POST/PUT/DELETE requests—missing token returns 403
