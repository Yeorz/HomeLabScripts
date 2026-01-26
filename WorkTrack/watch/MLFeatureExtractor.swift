import CoreMotion


struct MLFeatureExtractor {
static func extract(from samples: [(CMAcceleration, CMRotationRate)]) -> [String: Double] {
let count = Double(samples.count)


let accelX = samples.map { $0.0.x }.reduce(0,+) / count
let accelY = samples.map { $0.0.y }.reduce(0,+) / count
let accelZ = samples.map { $0.0.z }.reduce(0,+) / count


let gyroX = samples.map { $0.1.x }.reduce(0,+) / count
let gyroY = samples.map { $0.1.y }.reduce(0,+) / count
let gyroZ = samples.map { $0.1.z }.reduce(0,+) / count


return [
"accel_x_mean": accelX,
"accel_y_mean": accelY,
"accel_z_mean": accelZ,
"gyro_x_mean": gyroX,
"gyro_y_mean": gyroY,
"gyro_z_mean": gyroZ
]
}
}