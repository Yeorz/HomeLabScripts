import HealthKit
import CoreMotion


class WorkoutManager {
let store = HKHealthStore()
let motion = CMMotionManager()


func start() {
let config = HKWorkoutConfiguration()
config.activityType = .other
let session = try! HKWorkoutSession(healthStore: store, configuration: config)
session.startActivity(with: .now)
}
}