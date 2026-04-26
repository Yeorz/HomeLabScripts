import Foundation

/// Syncs completed workouts from the Watch to the WorkTrack backend.
///
/// Token flow: The iOS companion app stores the JWT in a shared App Group
/// UserDefaults (suite name: group.com.example.workouttracker).
/// If no token is available the sync is silently skipped — the workout is
/// recorded locally and can be retried next time the app is opened.
class WatchSyncManager {

    static let shared = WatchSyncManager()

    // Change this to match your server address.
    // For local development with `php -S 0.0.0.0:8080` on the same network,
    // replace 192.168.x.x with your Mac's LAN IP.
    private let baseURL = "http://localhost:8080"

    // Shared App Group — must be enabled in both the iOS and Watch targets in Xcode.
    // If the App Group is not configured yet, falls back to the Watch's own UserDefaults.
    private var token: String? {
        let shared = UserDefaults(suiteName: "group.com.example.workouttracker")
        return shared?.string(forKey: "jwt_token")
            ?? UserDefaults.standard.string(forKey: "jwt_token")
    }

    private init() {}

    /// Sync a completed workout session.
    /// - Parameters:
    ///   - confirmedLabel: The exercise type confirmed by the user (e.g. "Strength")
    ///   - segments: Individual exercise segments detected by the ML classifier
    ///   - totalDuration: Total workout duration in seconds
    func sync(confirmedLabel: String,
              segments: [WorkoutSegment],
              totalDuration: TimeInterval) {

        guard let token = self.token else {
            print("[WatchSyncManager] No auth token available — skipping sync.")
            return
        }

        guard let url = URL(string: "\(baseURL)/workouts") else { return }

        let segmentPayload: [[String: Any]] = segments.map { seg in
            ["label": seg.label, "duration": seg.duration, "confidence": seg.avgConfidence]
        }

        let payload: [String: Any] = [
            "type":     confirmedLabel,
            "duration": Int(totalDuration),
            "calories": 0,          // HealthKit calories can be added here in a future update
            "segments": segmentPayload,
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody   = body
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)",   forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("[WatchSyncManager] Sync failed: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse {
                print("[WatchSyncManager] Sync response: \(http.statusCode)")
            }
        }.resume()
    }
}
