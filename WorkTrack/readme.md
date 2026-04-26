# WorkTrack

Self-hosted workout tracker with multiple frontends: a PHP web interface, a Node.js API, a React dashboard, a React Native mobile app, and an Apple Watch app.

---

## Overview

| Component | Stack | Location |
|---|---|---|
| **PHP Web Interface** | PHP 8.1+ · MariaDB | `webapp/` |
| **API Backend** | Node.js · Express · SQLite | `backend/` |
| **Web Dashboard** | React · Vite · Chart.js | `web/` |
| **Mobile App** | React Native · Expo | `mobile/` |
| **Apple Watch** | SwiftUI · CoreML · HealthKit | `watch/` · `ios/` |

---

## PHP Web Interface + Shared API (webapp/)

The PHP webapp is the single backend for all clients — web, iOS, React Native, and Apple Watch. No Node.js or npm required for the backend. Runs on any standard LAMP/LEMP stack.

### Requirements

- PHP 8.1 or higher
- MariaDB 10.6+ or MySQL 8+
- Apache or Nginx with PHP

### Installation

**1. Create the database**

```bash
mysql -u root -p < webapp/setup.sql
```

This creates the `worktrack` database, a `users` table, and seeds 174 exercises across 13 muscle groups.

**Existing installation?** Run the migration instead:

```bash
mysql -u root -p worktrack < webapp/migrate.sql
```

**2. Configure the database connection and JWT secret**

```bash
cp webapp/config.example.php webapp/config.php
```

Edit `webapp/config.php`:

```php
define('DB_HOST',    'localhost');
define('DB_NAME',    'worktrack');
define('DB_USER',    'your_user');
define('DB_PASS',    'your_password');

// Generate once with: php -r "echo bin2hex(random_bytes(32));"
define('JWT_SECRET', 'your_long_random_secret');
```

**3. Start the server (development)**

```bash
php -S 0.0.0.0:8080 -t .
```

- Web interface: `http://localhost:8080/webapp/`
- Mobile API base URL: `http://<your-LAN-IP>:8080`

The root `.htaccess` routes all API paths (`/auth/*`, `/workouts`, `/analytics/*`, `/public/*`) directly to the PHP backend so the apps need no path changes.

### Features

- **Dashboard** — total stats, recent workouts
- **Workout logging** — live timer, exercise search, set logging with weight/reps or time/distance, warm-up sets, auto-save via AJAX
- **History** — all workouts grouped by month, expandable detail view
- **Exercise library** — 174 built-in exercises, add custom exercises
- **Settings** — metric (kg/km) or imperial (lbs/miles), dark/light theme
- **No npm or Composer required** — pure PHP + vanilla JS
- **Shared API** — JWT-authenticated REST endpoints compatible with iOS, React Native, and Apple Watch

### File structure

```
.htaccess                   Routes /auth/*, /workouts, /analytics/*, /public/* to PHP API
webapp/
├── setup.sql               Database schema + 174 exercises + users table
├── migrate.sql             Migration for existing installations
├── config.php              Database credentials + JWT secret (git-ignored)
├── config.example.php      Example config
├── index.php               Dashboard
├── workout.php             Log a workout
├── history.php             Workout history
├── exercises.php           Exercise library
├── settings.php            Settings
├── import.php              Bulk exercise import tool
├── includes/
│   ├── db.php              PDO database connection
│   ├── functions.php       Helper functions (units, formatting)
│   ├── auth.php            JWT encode/decode, CORS, requireAuth()
│   ├── header.php          Navigation + HTML head
│   └── footer.php          Scripts + HTML close
├── api/
│   ├── auth.php            POST /login, /register  GET /session  POST /logout
│   ├── mobile.php          POST /workouts  GET /analytics/*  GET /public/:id
│   ├── workouts.php        Detailed workout CRUD (web UI)
│   ├── exercises.php       Exercise search/CRUD (web UI)
│   └── import.php          Bulk import API endpoint
├── data/
│   └── exercises.php       Full exercise dataset (174 entries)
└── assets/
    ├── css/style.css       Stylesheet (dark theme)
    └── js/app.js           Vanilla JavaScript
```

### API endpoints (consumed by mobile/watch)

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/auth/csrf-token` | — | Get CSRF token |
| `POST` | `/auth/register` | — | Register user → `{token, user}` |
| `POST` | `/auth/login` | — | Login → `{token, user}` |
| `POST` | `/login` | — | iOS alias for `/auth/login` |
| `POST` | `/register` | — | iOS alias for `/auth/register` |
| `GET` | `/auth/session` | Bearer/cookie | Get current user |
| `POST` | `/auth/logout` | — | Clear session |
| `POST` | `/workouts` | Bearer | Log workout `{type, duration, calories, segments?}` |
| `GET` | `/analytics/summary` | Bearer | Workout summary by type |
| `GET` | `/analytics/trends` | Bearer | 30-day daily trends |
| `GET` | `/public/:userId` | — | Public workout data (90 days) |

---

## Node.js API Backend (backend/)

### Requirements

- Node.js 22+ (LTS)
- npm 9+

### Start

```bash
cd backend
npm install
node server.js
```

API runs at: `http://localhost:3001`

### Docker

```bash
docker build -t worktrack-backend ./backend
docker run -p 3001:3001 worktrack-backend
```

---

## React Web Dashboard (web/)

### Requirements

- Node.js 22+

### Start

```bash
cd web
npm install
npm run dev
```

Dashboard at: `http://localhost:5173`

**Features:** authenticated dashboard with charts and summaries, public shareable pages per user at `/public/<userId>`.

---

## React Native Mobile App (mobile/)

### Requirements

- Node.js 22+
- Expo CLI: `npm install -g expo-cli`

### Start

```bash
cd mobile
npm install
npx expo start
```

Scan the QR code with the Expo Go app (Android/iOS). Requires the backend running at `http://localhost:3001`.

---

## Apple Watch App (watch/ · ios/)

1. Open `WorkoutWatchApp.xcodeproj` in Xcode
2. Ensure `ExerciseClassifier.mlmodel` is included in the Watch target
3. Build and run on your paired Apple Watch

The Watch app uses **CoreML** for motion classification. After the user confirms the detected exercise in `WorkoutConfirmationView`, `WatchSyncManager` posts the workout (type, duration, classified segments) to `POST /workouts`.

### Token sharing (required for sync)

The Watch reads the JWT from a shared App Group UserDefaults (`group.com.example.workouttracker`). To enable this:

1. In Xcode, add the **App Groups** capability to both the iOS app target and the Watch target
2. Use the same group identifier: `group.com.example.workouttracker`
3. In the iOS `AuthManager`, write the token to the shared suite on login:

```swift
UserDefaults(suiteName: "group.com.example.workouttracker")?
    .set(loginResponse.token, forKey: "jwt_token")
```

Without this setup the sync is silently skipped; workouts are still recorded locally on the Watch.

### Server address for Watch

Edit `watch/WatchSyncManager.swift` and set `baseURL` to your server's LAN IP:

```swift
private let baseURL = "http://192.168.1.x:8080"
```

Localhost does not work on a physical Watch — it must be the Mac's network IP.

---

## All-in-one with Docker Compose

```bash
docker compose up --build
```

- Backend: `http://localhost:3001`
- Web dashboard: `http://localhost:5173`

> The mobile app and Apple Watch still require the native toolchain (Expo / Xcode).

---

## Summary

| Component | Technology |
|---|---|
| PHP web interface | PHP 8.1 · MariaDB · Vanilla JS |
| API backend | Node.js · Express · SQLite |
| Web dashboard | React · Vite · Chart.js |
| Mobile app | React Native · Expo |
| Apple Watch | SwiftUI · CoreML · HealthKit |
| Exercise library | 174 exercises · 13 muscle groups |
| Units | Metric (kg/km) default · Imperial (lbs/miles) optional |
