import HealthKit
import CoreMotion


class WorkoutManager {
private let motion = CMMotionManager()
private let classifier = MotionClassifier()
private var buffer: [(CMAcceleration, CMRotationRate)] = []


func start() {
motion.deviceMotionUpdateInterval = 0.1
motion.startDeviceMotionUpdates(to: .main) { data, _ in
guard let d = data else { return }
self.buffer.append((d.userAcceleration, d.rotationRate))


if self.buffer.count >= 50 {
let features = MLFeatureExtractor.extract(from: self.buffer)
let activity = self.classifier.classify(features: features)
print("Detected activity:", activity)
self.buffer.removeAll()
}
}
}
}