import CoreML


class WorkoutClassifier {
let model = ExerciseClassifierV2()
let calibration = UserCalibration()


func classify(features: Features) -> String {
do {
let input = ExerciseClassifierV2Input(
meanX: features.meanX,
meanY: features.meanY,
meanZ: features.meanZ,
varX: features.varX,
varY: features.varY,
varZ: features.varZ,
magMean: features.magMean,
magVar: features.magVar
)
let prediction = try model.prediction(input: input)
let profile = calibration.load()


// Apply bias if available
let bias = profile.labelBias[prediction.label] ?? 0
return bias > 0.1 ? prediction.label : prediction.label
} catch {
return "Unknown"
}
}
}