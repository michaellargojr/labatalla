import Foundation

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// The app's blue. Royal is the brand; Tech is the brighter blue phones use for links and buttons.
enum BlueScheme: String, Codable, CaseIterable, Identifiable {
    case royal, tech
    var id: String { rawValue }
    var label: String { self == .royal ? "Royal" : "Tech" }
}

/// The home-screen icon. Each is an app icon set in Assets.xcassets; nil is the primary one.
enum AppIconChoice: String, Codable, CaseIterable, Identifiable {
    case royal, tech, paper, star
    var id: String { rawValue }
    var label: String {
        switch self {
        case .royal: return "Royal"
        case .tech: return "Tech"
        case .paper: return "Paper"
        case .star: return "Star"
        }
    }
    var detail: String {
        switch self {
        case .royal: return "White mark on royal blue"
        case .tech: return "White mark on tech blue"
        case .paper: return "Blue mark on white"
        case .star: return "The lone star"
        }
    }
    var iconName: String? { self == .royal ? nil : "AppIcon-\(label)" }
}

enum WeekStart: String, Codable, CaseIterable, Identifiable {
    case monday, sunday
    var id: String { rawValue }
    var label: String { self == .monday ? "Monday" : "Sunday" }
}

let DEFAULT_MANTRA = "La batalla."

/// Settings. Every field decodes with a fallback, so a file from any build opens.
struct Settings: Codable, Hashable {
    var appearance: Appearance = .system
    var scheme: BlueScheme = .royal
    var icon: AppIconChoice = .royal
    var weekStart: WeekStart = .monday
    /// The small bolt, star or crown on a day's tile.
    var showBadges: Bool = true
    /// The line under the calendar's title. Your grandfather's, by default.
    var mantra: String = DEFAULT_MANTRA
    var haptics: Bool = true
    /// One local notification a day, at `reminderMinute` minutes past midnight. Off until turned on.
    var reminderOn: Bool = false
    var reminderMinute: Int = 20 * 60

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appearance = (try? c.decode(Appearance.self, forKey: .appearance)) ?? .system
        scheme = (try? c.decode(BlueScheme.self, forKey: .scheme)) ?? .royal
        icon = (try? c.decode(AppIconChoice.self, forKey: .icon)) ?? .royal
        weekStart = (try? c.decode(WeekStart.self, forKey: .weekStart)) ?? .monday
        showBadges = try c.decodeIfPresent(Bool.self, forKey: .showBadges) ?? true
        mantra = try c.decodeIfPresent(String.self, forKey: .mantra) ?? DEFAULT_MANTRA
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        reminderOn = try c.decodeIfPresent(Bool.self, forKey: .reminderOn) ?? false
        let minute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 20 * 60
        reminderMinute = min(max(minute, 0), 24 * 60 - 1)
    }
}
