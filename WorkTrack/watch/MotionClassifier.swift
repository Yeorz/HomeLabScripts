import CoreMotion


class MotionClassifier {
let manager = CMMotionManager()


func classify(_ samples: [CMAcceleration]) -> String {
let variance = samples.map { abs($0.x) }.reduce(0,+) / Double(samples.count)
return variance > 0.5 ? "Strength" : "Walking"
}
}