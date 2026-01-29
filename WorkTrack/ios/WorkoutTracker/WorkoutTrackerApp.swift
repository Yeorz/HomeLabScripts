import SwiftUI

@main
struct WorkoutTrackerApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var networkManager = NetworkManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                DashboardView()
                    .environmentObject(authManager)
                    .environmentObject(networkManager)
            } else {
                AuthView()
                    .environmentObject(authManager)
            }
        }
    }
}
