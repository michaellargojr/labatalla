import Foundation

// The types. A Goal is a habit you are building; a Mark is one day you did it. Everything else
// (which days light up, which badges a day earns, runs) is worked out from those two in Scoring.swift.

/// The Six framework. Ask of anything you want to do: does it matter in six months, or in six years?
/// Six months is the short term. Six years is the long term, and the long term is what the battle is for.
enum Horizon: String, Codable, CaseIterable, Identifiable {
    case sixMonths, sixYears
    var id: String { rawValue }
    /// "6 months", "6 years".
    var label: String { self == .sixMonths ? "6 months" : "6 years" }
    /// "Short term", "Long term".
    var title: String { self == .sixMonths ? "Short term" : "Long term" }
    var question: String { self == .sixMonths ? "Matters in six months" : "Matters in six years" }
    var symbol: String { self == .sixMonths ? "bolt.fill" : "star.fill" }
}

/// Monday 1 ... Sunday 7, like ISO weeks.
enum Weekday: Int, Codable, CaseIterable, Identifiable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday
    var id: Int { rawValue }
    var short: String { ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][rawValue - 1] }
    var letter: String { ["M", "T", "W", "T", "F", "S", "S"][rawValue - 1] }
    static func of(_ day: String) -> Weekday { Weekday(rawValue: isoWeekday(day)) ?? .monday }
    static let workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<Weekday> = [.saturday, .sunday]
    static func < (a: Weekday, b: Weekday) -> Bool { a.rawValue < b.rawValue }
    /// The week's days in the order the calendar shows them.
    static func ordered(_ start: WeekStart) -> [Weekday] {
        start == .monday ? Array(allCases) : [.sunday] + Array(allCases.dropLast())
    }
}

/// When a goal asks for a mark. The badges only count a goal against a day it is asked of.
enum Schedule: Codable, Hashable {
    /// Every day.
    case daily
    /// Only these days of the week.
    case weekdays(Set<Weekday>)
    /// Any days, this many times a week. It is only asked of a day once the week could not be
    /// made without it, so a Monday never pushes you about a Saturday plan.
    case timesPerWeek(Int)

    var label: String {
        switch self {
        case .daily: return "Every day"
        case .weekdays(let days):
            if days.count == 7 { return "Every day" }
            if days == Weekday.workdays { return "Weekdays" }
            if days == Weekday.weekend { return "Weekends" }
            if days.isEmpty { return "No days" }
            return Weekday.allCases.filter { days.contains($0) }.map(\.short).joined(separator: " ")
        case .timesPerWeek(let n): return n == 1 ? "Once a week" : "\(n) times a week"
        }
    }

    /// Whether a goal on this schedule is planned for the weekday of `day` (times a week: any day).
    func includes(_ day: String) -> Bool {
        switch self {
        case .daily: return true
        case .weekdays(let days): return days.contains(Weekday.of(day))
        case .timesPerWeek: return true
        }
    }

    /// Days a week the schedule asks for, for pacing.
    var daysPerWeek: Int {
        switch self {
        case .daily: return 7
        case .weekdays(let days): return days.count
        case .timesPerWeek(let n): return n
        }
    }
}

/// A habit you are building. Its color is what shows on the calendar; everything you mark it on
/// gets a band of that color.
struct Goal: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var color: GoalColor
    var horizon: Horizon
    /// An SF Symbol name.
    var symbol: String
    var schedule: Schedule
    /// Why it matters, in your words. Shown on the goal's page and in the day sheet.
    var why: String
    /// The first day it counts. Days before it are not asked of you.
    var createdAt: String
    /// Set when the goal is retired: the day it stopped counting. Its history stays on the calendar.
    var archivedAt: String?
    /// Position in Goals and in every day's list.
    var order: Int

    init(id: String = uid(), name: String, color: GoalColor = .royal, horizon: Horizon = .sixYears,
         symbol: String = "checkmark", schedule: Schedule = .daily, why: String = "",
         createdAt: String = today(), archivedAt: String? = nil, order: Int = 0) {
        self.id = id; self.name = name; self.color = color; self.horizon = horizon; self.symbol = symbol
        self.schedule = schedule; self.why = why; self.createdAt = createdAt; self.archivedAt = archivedAt; self.order = order
    }

    /// Every field has a fallback, so a file written by an older or newer build always opens.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? uid()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Goal"
        color = (try? c.decode(GoalColor.self, forKey: .color)) ?? .royal
        horizon = (try? c.decode(Horizon.self, forKey: .horizon)) ?? .sixYears
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "checkmark"
        schedule = (try? c.decode(Schedule.self, forKey: .schedule)) ?? .daily
        why = try c.decodeIfPresent(String.self, forKey: .why) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? today()
        archivedAt = try c.decodeIfPresent(String.self, forKey: .archivedAt)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }

    var isArchived: Bool { archivedAt != nil }

    /// Counting on `day`: made on or before it and not yet retired.
    func isActive(on day: String) -> Bool {
        guard createdAt <= day else { return false }
        if let a = archivedAt, day >= a { return false }
        return true
    }
}

/// One goal done on one day. Removing the mark is how a day is un-done; nothing is ever "missed".
struct Mark: Codable, Hashable, Identifiable {
    var id: String
    var goalId: String
    var day: String
    /// Milliseconds since 1970 when it was marked, so a day can tell morning marks from late ones.
    var at: Double
    var note: String?

    init(id: String = uid(), goalId: String, day: String, at: Double = Date().timeIntervalSince1970 * 1000, note: String? = nil) {
        self.id = id; self.goalId = goalId; self.day = day; self.at = at; self.note = note
    }

    /// Lenient like Goal: a mark with no id or time still opens.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? uid()
        goalId = try c.decode(String.self, forKey: .goalId)
        day = try c.decode(String.self, forKey: .day)
        at = try c.decodeIfPresent(Double.self, forKey: .at) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

/// What a day can earn. The long-term badge is the one the app is about: showing up for the
/// things that matter in six years, again and again.
enum Badge: String, Codable, CaseIterable, Identifiable, Hashable {
    /// Every short-term goal asked of the day was done.
    case shortTerm
    /// Every long-term goal asked of the day was done.
    case longTerm
    /// Everything asked of the day was done: the day's battle, won.
    case victory

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .shortTerm: return "bolt.fill"
        case .longTerm: return "star.fill"
        case .victory: return "crown.fill"
        }
    }
    var title: String {
        switch self {
        case .shortTerm: return "Short-term day"
        case .longTerm: return "Long-term day"
        case .victory: return "Battle won"
        }
    }
    var detail: String {
        switch self {
        case .shortTerm: return "Every 6-month goal asked of this day, done."
        case .longTerm: return "Every 6-year goal asked of this day, done."
        case .victory: return "Everything asked of this day, done."
        }
    }
}

/// The twelve colors a goal can have. Each has a bright shade for dark mode and a deeper one for
/// light mode, so bands read on both backgrounds.
enum GoalColor: String, Codable, CaseIterable, Identifiable {
    case royal, sky, teal, mint, lime, gold, orange, coral, rose, violet, indigo, slate
    var id: String { rawValue }

    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    func hex(dark: Bool) -> UInt32 {
        switch self {
        case .royal: return dark ? 0x3B7BFF : 0x1E5BE6
        case .sky: return dark ? 0x5BC0FF : 0x0E8FD6
        case .teal: return dark ? 0x2ED3C6 : 0x0E9C92
        case .mint: return dark ? 0x5DD68C : 0x1F9B5A
        case .lime: return dark ? 0xB5E04A : 0x6E9B10
        case .gold: return dark ? 0xFFC94D : 0xC7930A
        case .orange: return dark ? 0xFF9F43 : 0xD9731A
        case .coral: return dark ? 0xFF6B6B : 0xD9453D
        case .rose: return dark ? 0xFF7EB6 : 0xD1397F
        case .violet: return dark ? 0xB388FF : 0x7B4FD6
        case .indigo: return dark ? 0x7A8CFF : 0x4A5BD6
        case .slate: return dark ? 0x9AA7B8 : 0x5B6775
        }
    }

    /// The next color no active goal is using yet, so new goals come out different.
    static func next(after used: [GoalColor]) -> GoalColor {
        allCases.first { !used.contains($0) } ?? allCases[used.count % allCases.count]
    }
}

/// Symbols the goal editor offers. Any SF Symbol name works in a file; these are the ones on the grid.
enum GoalSymbols {
    static let all: [String] = [
        "checkmark", "star.fill", "flag.fill", "bolt.fill", "flame.fill", "target",
        "figure.run", "figure.walk", "dumbbell.fill", "figure.strengthtraining.traditional", "figure.yoga", "bicycle",
        "book.fill", "graduationcap.fill", "brain.head.profile", "pencil", "laptopcomputer", "lightbulb.fill",
        "bed.double.fill", "sun.max.fill", "moon.fill", "drop.fill", "fork.knife", "pills.fill",
        "heart.fill", "person.2.fill", "phone.fill", "house.fill", "bubble.left.fill", "hand.raised.fill",
        "dollarsign.circle.fill", "banknote.fill", "chart.line.uptrend.xyaxis", "cart.fill", "envelope.fill", "briefcase.fill",
        "music.note", "guitars.fill", "paintbrush.fill", "camera.fill", "leaf.fill", "globe",
    ]
}
