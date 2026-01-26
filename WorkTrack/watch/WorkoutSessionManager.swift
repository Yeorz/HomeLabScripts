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

    func endSession() -> String {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()

        let features = FeatureExtractor.extractFeatures(accel: accelData, gyro: gyroData)
        let label = classifier.classify(features: features)

        // Clear buffers
        accelData.removeAll()
        gyroData.removeAll()

        return label
    }
}
