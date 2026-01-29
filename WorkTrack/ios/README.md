# WorkoutTracker iOS App

Native iOS app for workout tracking with offline-first sync.

## Project Structure

```
ios/WorkoutTracker/
├── WorkoutTrackerApp.swift          # App entry point & routing
├── Managers/
│   ├── AuthManager.swift            # JWT authentication
│   ├── NetworkManager.swift         # Network connectivity monitoring
│   ├── WorkoutManager.swift         # Workout sync & local storage
│   └── WorkoutStorage.swift         # Workout data persistence
└── Views/
    ├── AuthView.swift               # Login/Register UI
    └── DashboardView.swift          # Main workout tracking UI
```

## Features

- **Native Swift/SwiftUI** UI with iOS-first design
- **Offline-First Sync**: Workouts queued locally, synced when connected
- **Network Monitoring**: Real-time connectivity detection via NWPathMonitor
- **JWT Authentication**: Secure token-based auth with UserDefaults persistence
- **Workout History**: Local storage with pending status indicators

## Development Setup

### Requirements
- Xcode 15+
- iOS 14+
- Swift 5.9+

### Running the App

1. Open in Xcode:
```bash
open ios/WorkoutTracker.xcodeproj
```

2. Select target "WorkoutTracker" and device/simulator

3. Build and run (Cmd+R)

### Connecting to Backend

Update API URL in `Managers/AuthManager.swift` and `Managers/WorkoutManager.swift`:

```swift
private let apiBaseURL = "http://localhost:3001"  // Local development
// or
private let apiBaseURL = "https://api.workouttracker.com"  // Production
```

## Data Persistence

- **Pending Workouts**: Stored in `UserDefaults` with key `pending_workouts`
- **Workout History**: Stored in `UserDefaults` with key `workout_history`
- **Auth Token**: Stored in `UserDefaults` with key `jwt_token`

## API Integration

Communicates with backend at:
- `POST /register` - User registration
- `POST /login` - User authentication
- `POST /workouts` - Submit workout (requires Bearer token)

Pending workouts are retried every 15 seconds when network becomes available.

## Key Design Decisions

1. **UserDefaults for Storage**: Simple, no migrations needed. Replace with Core Data/SwiftData for larger apps
2. **Async/Await**: Modern Swift concurrency patterns for network calls
3. **EnvironmentObject**: AuthManager and NetworkManager passed through view hierarchy for global state
4. **NWPathMonitor**: Lightweight network monitoring without deprecated Reachability
5. **No Third-Party Dependencies**: Pure SwiftUI + Foundation for maintainability
