import Foundation
import CoreMotion

struct Features {
    var meanX: Double
    var meanY: Double
    var meanZ: Double
    var varX: Double
    var varY: Double
    var varZ: Double
    var magMean: Double
    var magVar: Double
}

class FeatureExtractor {
    static func extractFeatures(accel: [CMAccelerometerData], gyro: [CMGyroData]) -> Features {
        let n = Double(accel.count)
        let xs = accel.map { $0.acceleration.x }
        let ys = accel.map { $0.acceleration.y }
        let zs = accel.map { $0.acceleration.z }
        let mags = zip(xs, zip(ys, zs)).map { sqrt($0*$0 + $1.0*$1.0 + $1.1*$1.1) }

        func mean(_ arr: [Double]) -> Double { arr.reduce(0,+)/n }
        func variance(_ arr: [Double], mean: Double) -> Double { arr.map { ($0 - mean)*($0 - mean) }.reduce(0,+)/n }

        let meanX = mean(xs), meanY = mean(ys), meanZ = mean(zs)
        let varX = variance(xs, mean: meanX), varY = variance(ys, mean: meanY), varZ = variance(zs, mean: meanZ)
        let magMean = mean(mags), magVar = variance(mags, mean: magMean)

        return Features(meanX: meanX, meanY: meanY, meanZ: meanZ,
                        varX: varX, varY: varY, varZ: varZ,
                        magMean: magMean, magVar: magVar)
    }
}
