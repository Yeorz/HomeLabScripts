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

## PHP Web Interface (webapp/)

The simplest way to log workouts — no Node.js or npm required. Runs on any standard LAMP/LEMP stack.

### Requirements

- PHP 8.1 or higher
- MariaDB 10.6+ or MySQL 8+
- Apache or Nginx with PHP

### Installation

**1. Create the database**

```bash
mysql -u root -p < webapp/setup.sql
```

This creates the `worktrack` database and seeds 174 exercises across 13 muscle groups.

**2. Configure the database connection**

```bash
cp webapp/config.example.php webapp/config.php
```

Edit `webapp/config.php` with your credentials:

```php
define('DB_HOST', 'localhost');
define('DB_NAME', 'worktrack');
define('DB_USER', 'your_user');
define('DB_PASS', 'your_password');
```

**3. Point your web server at the project root**

For local development with the built-in PHP server:

```bash
php -S localhost:8080 -t .
```

Then open: `http://localhost:8080/webapp/`

### Features

- **Dashboard** — total stats, recent workouts
- **Workout logging** — live timer, exercise search, set logging with weight/reps or time/distance, warm-up sets, auto-save via AJAX
- **History** — all workouts grouped by month, expandable detail view
- **Exercise library** — 174 built-in exercises, add custom exercises
- **Settings** — metric (kg/km) or imperial (lbs/miles), dark/light theme
- **No npm or Composer required** — pure PHP + vanilla JS

### File structure

```
webapp/
├── setup.sql               Database schema + 174 exercises
├── config.php              Database credentials (git-ignored)
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
│   ├── header.php          Navigation + HTML head
│   └── footer.php          Scripts + HTML close
├── api/
│   ├── workouts.php        REST API for workouts and sets
│   ├── exercises.php       REST API for exercises
│   └── import.php          Bulk import API endpoint
├── data/
│   └── exercises.php       Full exercise dataset (174 entries)
└── assets/
    ├── css/style.css       Stylesheet (dark theme)
    └── js/app.js           Vanilla JavaScript
```

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

The Watch app uses **CoreML** for motion classification and syncs results to the backend automatically.

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
