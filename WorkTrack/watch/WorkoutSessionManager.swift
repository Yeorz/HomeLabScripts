import WatchKit
import CoreMotion


class WorkoutSessionManager {
let motionManager = CMMotionManager()
let classifier = WorkoutClassifier()


var accelData: [CMAccelerometerData] = []
var gyroData: [CMGyroData] = []


func startSession() {
motionManager.accelerometerUpdateInterval = 1.0 / 50.0
motionManager.gyroUpdateInterval = 1.0 / 50.0


motionManager.startAccelerometerUpdates(to: .main) { data, _ in
if let d = data { self.accelData.append(d) }
}


motionManager.startGyroUpdates(to: .main) { data, _ in
if let d = data { self.gyroData.append(d) }
}
}

func endSessionWithConfirmation(completion: @escaping (String) -> Void) {
let features = FeatureExtractor.extractFeatures(accel: accelData, gyro: gyroData)
let detected = classifier.classify(features: features)


WKHostingController(rootView: WorkoutConfirmationView(detectedLabel: detected) { confirmedLabel in
UserCalibration().reinforce(label: confirmedLabel)
completion(confirmedLabel)
})


accelData.removeAll()
gyroData.removeAll()
}

func endSession() -> String {
motionManager.stopAccelerometerUpdates()
motionManager.stopGyroUpdates()

func reinforceLabel(_ label: String) {
UserCalibration().reinforce(label: label)
}

let features = FeatureExtractor.extractFeatures(accel: accelData, gyro: gyroData)
let label = classifier.classify(features: features)


// Clear buffers
accelData.removeAll()
gyroData.removeAll()

var segments: [WorkoutSegment] = []
var currentLabel: String?
var confidenceSum = 0.0
var windowCount = 0


func processWindow(features: Features, windowDuration: TimeInterval) {
let result = classifier.classify(features: features)
guard result.confidence > 0.6 else { return } // confidence threshold


if currentLabel == nil || result.label != currentLabel {
if let label = currentLabel {
segments.append(WorkoutSegment(
label: label,
duration: windowDuration * Double(windowCount),
avgConfidence: confidenceSum / Double(windowCount)
))
}
currentLabel = result.label
confidenceSum = result.confidence
windowCount = 1
} else {
confidenceSum += result.confidence
windowCount += 1
}
}


func endSession() -> [WorkoutSegment] {
if let label = currentLabel {
segments.append(WorkoutSegment(
label: label,
duration: windowDuration * Double(windowCount),
avgConfidence: confidenceSum / Double(windowCount)
))
}
let result = segments
segments.removeAll()
return result
}

return label
}
}