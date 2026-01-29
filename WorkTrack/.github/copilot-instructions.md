# WorkTrack Codebase Instructions for AI Agents

## Architecture Overview

WorkTrack is a multi-platform workout tracking system with four core components:

- **Backend** (`backend/`): Express.js + SQLite3. Handles user auth (JWT), workout CRUD, and analytics via REST API
- **Web** (`web/`): React SPA with authenticated dashboard and public shareable pages. Path-based routing: `/public/*` renders `Public.jsx`, all others render `Dashboard.jsx` **(Being rewritten for OAuth/SSO/SAML)**
- **iOS** (`ios/`): Native SwiftUI app with offline-first architecture. Stores pending workouts in UserDefaults, syncs via NWPathMonitor
- **Watch** (`watch/`): iOS watchOS app with ML-based motion classification. Classifies workouts using accelerometer/gyroscope data

## Critical Data Flows

1. **Authentication**: JWT tokens stored in localStorage (web)/UserDefaults (iOS). Bearer token in Authorization headers for all authenticated requests
2. **Workout Sync Pipeline**: App captures workouts → stores offline if no network → syncs via POST to `/workouts` when connected
3. **ML Classification**: Watch collects 50-sample motion buffer (0.1s intervals) → FeatureExtractor transforms data → MotionClassifier predicts activity type
4. **Analytics**: Dashboard fetches `/analytics/summary` and `/analytics/trends` from backend, renders trends with Charts component

## Key Files by Function

| Pattern | File | Purpose |
|---------|------|---------|
| Auth middleware | [backend/auth.js](backend/auth.js) | JWT verification for protected routes |
| DB schema | [backend/server.js](backend/server.js#L17-L30) | SQLite tables: users, workouts |
| iOS app entry | [ios/WorkoutTracker/WorkoutTrackerApp.swift](ios/WorkoutTracker/WorkoutTrackerApp.swift) | SwiftUI app root, auth routing |
| iOS auth manager | [ios/WorkoutTracker/Managers/AuthManager.swift](ios/WorkoutTracker/Managers/AuthManager.swift) | JWT login/register, token persistence |
| iOS sync logic | [ios/WorkoutTracker/Managers/WorkoutManager.swift](ios/WorkoutTracker/Managers/WorkoutManager.swift) | Offline queue, background sync |
| iOS network monitor | [ios/WorkoutTracker/Managers/NetworkManager.swift](ios/WorkoutTracker/Managers/NetworkManager.swift) | NWPathMonitor connectivity detection |
| ML feature extraction | [watch/MLFeatureExtractor.swift](watch/MLFeatureExtractor.swift) | Transforms motion samples to model input |
| Web routing | [web/src/app.jsx](web/src/app.jsx#L6-L11) | Path-based conditional rendering |

## Project-Specific Conventions

1. **Port Setup**: Backend runs on 3001, Web on 5173 (Vite default). Both configured in docker-compose.yml and package.json
2. **Token Management**: "secret" hardcoded as JWT secret (insecure—replace in production)
3. **Offline-First Mobile**: Always attempt POST to backend; catch errors and queue in AsyncStorage as fallback
4. **ML Model Location**: CoreML model at `watch/ExerciseClassifierV2.mlmodel` via MLModel framework
5. **CORS Enabled**: Backend uses cors() middleware; web/mobile communicate across localhost ports

## Development Workflows

```bash
# Full stack setup (docker backend + web)
docker-compose up

# Individual services
cd backend && npm install && node server.js
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

- Watch app requires Xcode and physical device/simulator (not in docker-compose)
- iOS UserDefaults key is `pending_workouts`—changing it breaks offline queue recovery
- Web Dashboard requires auth; public pages accessible via `/public/{userId}` without token
- ML model requires retraining if motion sensor hardware changes significantly
- iOS app token stored with key `jwt_token` in UserDefaults
