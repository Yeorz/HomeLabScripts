import CoreML

class WorkoutClassifier {
    let model = ExerciseClassifierV2() // New model

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
            return prediction.label
        } catch {
            return "Unknown"
        }
    }
}
