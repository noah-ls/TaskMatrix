import Foundation

enum AppSettings {
    static let defaultAutoArchiveDays = 15

    private static let autoArchiveDaysKey = "autoArchiveDays"
    private static let range = 1...365

    static var autoArchiveDays: Int {
        get {
            guard let stored = UserDefaults.standard.object(forKey: autoArchiveDaysKey) as? Int else {
                return defaultAutoArchiveDays
            }
            return clamped(stored)
        }
        set {
            UserDefaults.standard.set(clamped(newValue), forKey: autoArchiveDaysKey)
        }
    }

    static func clamped(_ days: Int) -> Int {
        min(max(days, range.lowerBound), range.upperBound)
    }
}
