import Foundation

class WorkoutStorage {
    private let pendingWorkoutsKey = "pending_workouts"
    private let workoutHistoryKey = "workout_history"
    
    // MARK: - Offline Storage
    
    func savePendingWorkout(_ workout: Workout) throws {
        var pending = try getPendingWorkouts()
        pending.append(workout)
        let data = try JSONEncoder().encode(pending)
        UserDefaults.standard.set(data, forKey: pendingWorkoutsKey)
    }
    
    func getPendingWorkouts() throws -> [Workout] {
        guard let data = UserDefaults.standard.data(forKey: pendingWorkoutsKey) else {
            return []
        }
        return try JSONDecoder().decode([Workout].self, from: data)
    }
    
    func removePendingWorkout(_ workout: Workout) throws {
        var pending = try getPendingWorkouts()
        pending.removeAll { $0.id == workout.id }
        let data = try JSONEncoder().encode(pending)
        UserDefaults.standard.set(data, forKey: pendingWorkoutsKey)
    }
    
    func clearAllPending() {
        UserDefaults.standard.removeObject(forKey: pendingWorkoutsKey)
    }
    
    // MARK: - Local History
    
    func saveWorkoutToHistory(_ workout: Workout) throws {
        var history = try getWorkoutHistory()
        history.insert(workout, at: 0)
        let data = try JSONEncoder().encode(history)
        UserDefaults.standard.set(data, forKey: workoutHistoryKey)
    }
    
    func getWorkoutHistory() throws -> [Workout] {
        guard let data = UserDefaults.standard.data(forKey: workoutHistoryKey) else {
            return []
        }
        return try JSONDecoder().decode([Workout].self, from: data)
    }
}

struct Workout: Codable, Identifiable {
    var id: String = UUID().uuidString
    let type: String
    let duration: Int // seconds
    let calories: Int
    var isPending: Bool = false
    let createdAt: Date = Date()
}
