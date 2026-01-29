import SwiftUI


struct WorkoutConfirmationView: View {
let detectedLabel: String
let onConfirm: (String) -> Void


let allLabels = ["Strength", "Cardio", "HIIT", "Yoga", "Rowing", "Core", "Stretch"]


var body: some View {
VStack {
Text("Detected:")
.font(.caption)
Text(detectedLabel)
.font(.headline)
.padding(.bottom, 8)


Button("Confirm") {
onConfirm(detectedLabel)
}
.padding(.bottom, 6)


Text("Or correct")
.font(.caption)


ScrollView {
ForEach(allLabels.filter { $0 != detectedLabel }, id: \.self) { label in
Button(label) {
onConfirm(label)
}
}
}
}
.padding()
}
}