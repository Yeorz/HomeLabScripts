import SwiftUI

struct WorkoutConfirmationView: View {
    let detectedLabel: String
    let segments: [WorkoutSegment]
    let totalDuration: TimeInterval
    let onConfirm: (String) -> Void

    // Convenience init for callers that don't yet pass segments/duration
    init(detectedLabel: String,
         segments: [WorkoutSegment] = [],
         totalDuration: TimeInterval = 0,
         onConfirm: @escaping (String) -> Void) {
        self.detectedLabel = detectedLabel
        self.segments      = segments
        self.totalDuration = totalDuration
        self.onConfirm     = onConfirm
    }

    let allLabels = ["Strength", "Cardio", "HIIT", "Yoga", "Rowing", "Core", "Stretch"]

    var body: some View {
        VStack {
            Text("Detected:")
                .font(.caption)
            Text(detectedLabel)
                .font(.headline)
                .padding(.bottom, 8)

            Button("Confirm") {
                confirm(detectedLabel)
            }
            .padding(.bottom, 6)

            Text("Or correct:")
                .font(.caption)

            ScrollView {
                ForEach(allLabels.filter { $0 != detectedLabel }, id: \.self) { label in
                    Button(label) {
                        confirm(label)
                    }
                }
            }
        }
        .padding()
    }

    private func confirm(_ label: String) {
        // Sync to backend before handing off to caller
        WatchSyncManager.shared.sync(
            confirmedLabel: label,
            segments:       segments,
            totalDuration:  totalDuration
        )
        onConfirm(label)
    }
}
