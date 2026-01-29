import Foundation


struct CalibrationProfile: Codable {
var labelBias: [String: Double] // e.g. ["Strength": 0.15]
}


class UserCalibration {
private let key = "user_calibration"


func load() -> CalibrationProfile {
if let data = UserDefaults.standard.data(forKey: key),
let profile = try? JSONDecoder().decode(CalibrationProfile.self, from: data) {
return profile
}
return CalibrationProfile(labelBias: [:])
}


func save(_ profile: CalibrationProfile) {
if let data = try? JSONEncoder().encode(profile) {
UserDefaults.standard.set(data, forKey: key)
}
}


func reinforce(label: String) {
var profile = load()
profile.labelBias[label, default: 0] += 0.05
save(profile)
}
}