import CoreML


struct ClassifiedWindow {
let label: String
let confidence: Double
}


class WorkoutClassifier {
let model = ExerciseClassifierV2()
let calibration = UserCalibration()


func classify(features: Features) -> ClassifiedWindow {
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


let confidence = prediction.labelProbabilities[prediction.label] ?? 0
return ClassifiedWindow(label: prediction.label, confidence: confidence)
} catch {
return ClassifiedWindow(label: "Unknown", confidence: 0)
}
}
}