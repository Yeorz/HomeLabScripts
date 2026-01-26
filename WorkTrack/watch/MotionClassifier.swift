import CoreML


class MotionClassifier {
private let model = try! ExerciseClassifier(configuration: MLModelConfiguration())


func classify(features: [String: Double]) -> String {
let input = ExerciseClassifierInput(
accel_x_mean: features["accel_x_mean"]!,
accel_y_mean: features["accel_y_mean"]!,
accel_z_mean: features["accel_z_mean"]!,
gyro_x_mean: features["gyro_x_mean"]!,
gyro_y_mean: features["gyro_y_mean"]!,
gyro_z_mean: features["gyro_z_mean"]!
)


let output = try! model.prediction(input: input)
return output.classLabel
}
}