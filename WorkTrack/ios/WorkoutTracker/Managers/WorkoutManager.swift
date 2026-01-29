import Foundation

class WorkoutManager: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var pendingCount: Int = 0
    
    private let storage = WorkoutStorage()
    private let apiBaseURL = "http://localhost:3001"
    private var authToken: String?
    
    init(token: String? = nil) {
        self.authToken = token
        Task {
            await loadWorkoutHistory()
            await loadPendingWorkouts()
        }
    }
    
    // MARK: - API Operations
    
    func logWorkout(type: String, duration: Int, calories: Int, token: String) async {
        let workout = Workout(type: type, duration: duration, calories: calories)
        
        // Save to local history first
        do {
            try storage.saveWorkoutToHistory(workout)
            DispatchQueue.main.async {
                self.workouts.insert(workout, at: 0)
            }
        } catch {
            print("Failed to save workout locally: \(error)")
        }
        
        // Try to sync with backend
        await syncWorkout(workout, token: token)
    }
    
    private func syncWorkout(_ workout: Workout, token: String) async {
        let url = URL(string: "\(apiBaseURL)/workouts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "type": workout.type,
            "duration": workout.duration,
            "calories": workout.calories
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Successfully synced - no need to store offline
                return
            } else {
                // Save for later sync
                try storage.savePendingWorkout(workout)
                DispatchQueue.main.async {
                    self.pendingCount += 1
                }
            }
        } catch {
            // Network error - save for later sync
            do {
                try storage.savePendingWorkout(workout)
                DispatchQueue.main.async {
                    self.pendingCount += 1
                }
            } catch {
                print("Failed to save pending workout: \(error)")
            }
        }
    }
    
    // MARK: - Sync Pending Workouts
    
    func syncPendingWorkouts(token: String) async {
        do {
            var pending = try storage.getPendingWorkouts()
            guard !pending.isEmpty else { return }
            
            var syncedCount = 0
            var remainingWorkouts: [Workout] = []
            
            for workout in pending {
                if await syncWorkoutToBackend(workout, token: token) {
                    syncedCount += 1
                } else {
                    remainingWorkouts.append(workout)
                }
            }
            
            // Update pending workouts
            let data = try JSONEncoder().encode(remainingWorkouts)
            UserDefaults.standard.set(data, forKey: "pending_workouts")
            
            DispatchQueue.main.async {
                self.pendingCount = remainingWorkouts.count
            }
        } catch {
            print("Failed to sync pending workouts: \(error)")
        }
    }
    
    private func syncWorkoutToBackend(_ workout: Workout, token: String) async -> Bool {
        let url = URL(string: "\(apiBaseURL)/workouts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "type": workout.type,
            "duration": workout.duration,
            "calories": workout.calories
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Local Data Loading
    
    @MainActor
    private func loadWorkoutHistory() async {
        do {
            self.workouts = try storage.getWorkoutHistory()
        } catch {
            print("Failed to load workout history: \(error)")
        }
    }
    
    @MainActor
    private func loadPendingWorkouts() async {
        do {
            let pending = try storage.getPendingWorkouts()
            self.pendingCount = pending.count
        } catch {
            print("Failed to load pending workouts: \(error)")
        }
    }
}
