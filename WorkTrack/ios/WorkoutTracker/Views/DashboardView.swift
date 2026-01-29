import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var networkManager: NetworkManager
    @StateObject private var workoutManager = WorkoutManager()
    @State private var showingLogWorkout = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Status bar
                HStack {
                    Image(systemName: networkManager.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(networkManager.isConnected ? .green : .red)
                    
                    if workoutManager.pendingCount > 0 {
                        Text("Pending: \(workoutManager.pendingCount)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    Button(action: { authManager.logout() }) {
                        Text("Logout")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Workout buttons
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            if let token = authManager.token {
                                await workoutManager.logWorkout(
                                    type: "Strength",
                                    duration: 1800,
                                    calories: 220,
                                    token: token
                                )
                            }
                        }
                    }) {
                        VStack {
                            Image(systemName: "dumbbell.fill")
                            Text("Strength")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        Task {
                            if let token = authManager.token {
                                await workoutManager.logWorkout(
                                    type: "Cardio",
                                    duration: 2400,
                                    calories: 350,
                                    token: token
                                )
                            }
                        }
                    }) {
                        VStack {
                            Image(systemName: "heart.fill")
                            Text("Cardio")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        Task {
                            if let token = authManager.token {
                                await workoutManager.logWorkout(
                                    type: "Flexibility",
                                    duration: 1200,
                                    calories: 100,
                                    token: token
                                )
                            }
                        }
                    }) {
                        VStack {
                            Image(systemName: "figure.mind.and.body")
                            Text("Flex")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                
                // Sync pending button
                if workoutManager.pendingCount > 0 && networkManager.isConnected {
                    Button(action: {
                        Task {
                            if let token = authManager.token {
                                await workoutManager.syncPendingWorkouts(token: token)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Sync Pending Workouts")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                }
                
                // Workout history
                Text("Workout History")
                    .font(.headline)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                List {
                    ForEach(workoutManager.workouts) { workout in
                        WorkoutRow(workout: workout)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Workout Tracker")
            .background(Color(.systemGray5))
        }
        .onAppear {
            // Sync pending when connection is established
            Task {
                if networkManager.isConnected, let token = authManager.token {
                    await workoutManager.syncPendingWorkouts(token: token)
                }
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.type)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if workout.isPending {
                    Label("Pending", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            HStack(spacing: 16) {
                Label("\(workout.duration / 60)m \(workout.duration % 60)s", systemImage: "timer")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Label("\(workout.calories) kcal", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(
            workout.isPending ?
            Color.orange.opacity(0.1) :
            Color.white
        )
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
        .environmentObject(NetworkManager())
}
