# Workout Tracker - Local Deployment Instructions

This README provides instructions to **build and run the Workout Tracker app locally**, including backend, web dashboard, mobile app, and Apple Watch functionality.

---

## Prerequisites

* **Node.js** >= 22 (LTS)
* **npm** >= 9
* **Docker** >= 20
* **Xcode** (for Apple Watch and iOS builds)
* **Expo CLI** (for mobile app)

Install Expo CLI globally if not installed:

```bash
npm install -g expo-cli
```

---

## 1️⃣ Clone Repository

```bash
git clone <your-repo-url>
cd workout-tracker
```

---

## 2️⃣ Backend Setup

1. Navigate to backend folder:

```bash
cd backend
```

2. Install dependencies:

```bash
npm install
```

3. Start the backend server:

```bash
node server.js
```

The backend runs at: `http://localhost:3001`

### Optional: Docker Build

```bash
docker build -t workout-backend ./backend
docker run -p 3001:3001 workout-backend
```

---

## 3️⃣ Web Dashboard Setup

1. Navigate to web folder:

```bash
cd web
```

2. Install dependencies:

```bash
npm install
```

3. Start the web server:

```bash
npm run dev
```

Open the dashboard at: `http://localhost:5173`

### Features

* Authenticated dashboard with charts and summaries
* Public shareable pages for workouts

---

## 4️⃣ Mobile App Setup (iOS & Android)

1. Navigate to mobile folder:

```bash
cd mobile
```

2. Install dependencies:

```bash
npm install
```

3. Start Expo development server:

```bash
npx expo start
```

* Scan QR code for Android/iOS Expo Go app
* Ensure backend server is running (`http://localhost:3001`)

The mobile app will automatically sync workouts to the backend.

---

## 5️⃣ Apple Watch Setup

1. Open `WorkoutWatchApp.xcodeproj` in Xcode
2. Ensure your Apple Watch target has `ExerciseClassifier.mlmodel` included
3. Build and run on your paired Apple Watch

The watch app uses **CoreML** for motion classification and syncs results to the backend automatically.

---

## 6️⃣ Docker Compose (All-in-One Option)

Alternatively, you can start backend and web at once using Docker Compose:

```bash
docker compose up --build
```

* Backend: `http://localhost:3001`
* Web dashboard: `http://localhost:5173`

Note: Mobile and Apple Watch apps still require native environment (Expo/Xcode).

---

## 7️⃣ Public Pages

* Dashboard generates a public link for each user: `http://localhost:5173/public/<userId>`
* Public pages are **read-only and aggregated** for privacy.

---

## 8️⃣ Summary

* Backend: Node.js + SQLite + Express
* Web: React + Vite + Chart.js
* Mobile: React Native (Expo)
* Watch: SwiftUI + CoreML + HealthKit
* ML Exercise Classification: CoreML model on Apple Watch
* Analytics: Per-exercise summary + trends
* Public Pages: Read-only shareable pages

All components are compatible locally and integrate seamlessly for a **full self-hosted workout tracker** experience.
