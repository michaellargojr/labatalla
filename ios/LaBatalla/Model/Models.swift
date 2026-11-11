import Foundation

// The types. A Goal is something you are fighting for; a Mark is one day's answer to "did you?",
// with its minutes and its reason; a SleepLog is one night. Everything else (which days light up,
// hours, pace, patterns) is worked out from those in the other files of Model/.

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
    var full: String { ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][rawValue - 1] }
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

/// What sort of goal it is, which decides what its check-in asks and whether hours are counted.
enum GoalKind: String, Codable, CaseIterable, Identifiable {
    /// A project or a skill: it is built in sessions, and the hours are counted.
    case time
    /// A rule to keep: no hours, you either kept it that day or not (eating, drinking, bedtime).
    case adherence
    /// A job: hours in, money out.
    case work
    /// A result other goals get you to. It has no check-in of its own.
    case outcome

    var id: String { rawValue }
    var label: String {
        switch self {
        case .time: return "Takes hours"
        case .adherence: return "A rule to keep"
        case .work: return "Work"
        case .outcome: return "A result"
        }
    }
    var detail: String {
        switch self {
        case .time: return "A project or a skill. You put in sessions and the hours add up."
        case .adherence: return "No hours needed. Each day you either kept it or not: eating, drinking, bedtime."
        case .work: return "Your job. Hours in, money out."
        case .outcome: return "A finish line that other goals get you to. No check-in of its own."
        }
    }
    var symbol: String {
        switch self {
        case .time: return "hourglass"
        case .adherence: return "checkmark.seal.fill"
        case .work: return "briefcase.fill"
        case .outcome: return "flag.checkered"
        }
    }
    /// What the daily check-in asks.
    var question: String {
        switch self {
        case .time: return "Did you work on this?"
        case .adherence: return "Did you keep it?"
        case .work: return "Did you work?"
        case .outcome: return ""
        }
    }
    /// Whether a day's mark carries time.
    var countsTime: Bool { self == .time || self == .work }
    /// Whether it shows up in the day's check-in.
    var hasCheckIn: Bool { self != .outcome }
}

/// How a job pays and what it asks, for a goal of kind `.work`.
struct WorkSetup: Codable, Hashable {
    /// Fixed pay a month, after tax. 0 when there is none.
    var basePerMonth: Double = 0
    /// Pay per hour worked. 0 when there is none.
    var hourlyRate: Double = 0
    /// What one paid result is called: "meeting", "sale", "deal". Empty when pay is not per result.
    var unitName: String = ""
    /// Money per result, after tax.
    var unitValue: Double = 0
    /// Hours a day the job expects.
    var requiredHours: Double = 8
    /// Six months from now: money a month you want to be earning.
    var targetIncome: Double = 0
    /// Six months from now: hours a day you want to be working.
    var targetHours: Double = 8

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        basePerMonth = try c.decodeIfPresent(Double.self, forKey: .basePerMonth) ?? 0
        hourlyRate = try c.decodeIfPresent(Double.self, forKey: .hourlyRate) ?? 0
        unitName = try c.decodeIfPresent(String.self, forKey: .unitName) ?? ""
        unitValue = try c.decodeIfPresent(Double.self, forKey: .unitValue) ?? 0
        requiredHours = try c.decodeIfPresent(Double.self, forKey: .requiredHours) ?? 8
        targetIncome = try c.decodeIfPresent(Double.self, forKey: .targetIncome) ?? 0
        targetHours = try c.decodeIfPresent(Double.self, forKey: .targetHours) ?? 8
    }

    var paysPerResult: Bool { !unitName.trimmingCharacters(in: .whitespaces).isEmpty }
}

/// Something you are fighting for. Its color is what shows on the calendar; every day you put
/// anything into it, even a few minutes, gets a band of that color.
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

    // What the setup questions capture: the first view of the goal, kept to compare with what happens.
    var kind: GoalKind
    /// The bigger goal this one serves, if any.
    var parentId: String?
    /// "How important is it for you to achieve this goal?" 1...10. 0 until answered.
    var importance: Int
    /// How you will know it is done.
    var finishLine: String
    /// The soonest it could possibly be done.
    var soonest: String?
    /// A reasonable day to have it done by.
    var reasonable: String?
    /// A very conservative day.
    var conservative: String?
    /// Hours you think it takes in all. 0 when it has no end (staying fit) or no hours (a rule).
    var totalHours: Double
    /// The planned length of one session, in minutes.
    var sessionMinutes: Int
    /// "How clear is the path from here to done?" 1...10. 0 until answered.
    var clarity: Int
    /// Goals this one pulls against, by id.
    var conflicts: [String]
    /// The day it was achieved.
    var achievedAt: String?
    /// How the job pays, for a work goal.
    var work: WorkSetup?

    init(id: String = uid(), name: String, color: GoalColor = .royal, horizon: Horizon = .sixYears,
         symbol: String = "checkmark", schedule: Schedule = .daily, why: String = "",
         createdAt: String = today(), archivedAt: String? = nil, order: Int = 0,
         kind: GoalKind = .time, parentId: String? = nil, importance: Int = 0, finishLine: String = "",
         soonest: String? = nil, reasonable: String? = nil, conservative: String? = nil,
         totalHours: Double = 0, sessionMinutes: Int = 0, clarity: Int = 0, conflicts: [String] = [],
         achievedAt: String? = nil, work: WorkSetup? = nil) {
        self.id = id; self.name = name; self.color = color; self.horizon = horizon; self.symbol = symbol
        self.schedule = schedule; self.why = why; self.createdAt = createdAt; self.archivedAt = archivedAt; self.order = order
        self.kind = kind; self.parentId = parentId; self.importance = importance; self.finishLine = finishLine
        self.soonest = soonest; self.reasonable = reasonable; self.conservative = conservative
        self.totalHours = totalHours; self.sessionMinutes = sessionMinutes; self.clarity = clarity
        self.conflicts = conflicts; self.achievedAt = achievedAt; self.work = work
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
        // A goal from before kinds existed was a yes-or-no habit: a rule to keep.
        kind = (try? c.decode(GoalKind.self, forKey: .kind)) ?? .adherence
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        importance = min(max(try c.decodeIfPresent(Int.self, forKey: .importance) ?? 0, 0), 10)
        finishLine = try c.decodeIfPresent(String.self, forKey: .finishLine) ?? ""
        soonest = try c.decodeIfPresent(String.self, forKey: .soonest)
        reasonable = try c.decodeIfPresent(String.self, forKey: .reasonable)
        conservative = try c.decodeIfPresent(String.self, forKey: .conservative)
        totalHours = max(0, try c.decodeIfPresent(Double.self, forKey: .totalHours) ?? 0)
        sessionMinutes = max(0, try c.decodeIfPresent(Int.self, forKey: .sessionMinutes) ?? 0)
        clarity = min(max(try c.decodeIfPresent(Int.self, forKey: .clarity) ?? 0, 0), 10)
        conflicts = try c.decodeIfPresent([String].self, forKey: .conflicts) ?? []
        achievedAt = try c.decodeIfPresent(String.self, forKey: .achievedAt)
        work = try? c.decodeIfPresent(WorkSetup.self, forKey: .work)
    }

    var isArchived: Bool { archivedAt != nil }
    var isAchieved: Bool { achievedAt != nil }

    /// Counting on `day`: made on or before it and not yet retired.
    func isActive(on day: String) -> Bool {
        guard createdAt <= day else { return false }
        if let a = archivedAt, day >= a { return false }
        return true
    }

    /// The job's setup, or the defaults when none was saved.
    var workSetup: WorkSetup { work ?? WorkSetup() }

    /// Minutes a week the plan asks for: sessions a week times the session length.
    var weeklyMinutes: Int { kind == .time ? schedule.daysPerWeek * sessionMinutes : 0 }
}

/// One answer to "did you?" for one goal on one day. A yes colors the day, however short the
/// session was. A no is kept too, with its reason: it is data, and it never shows as a miss.
struct Mark: Codable, Hashable, Identifiable {
    var id: String
    var goalId: String
    var day: String
    /// Milliseconds since 1970 when it was marked, so a day can tell morning marks from late ones.
    var at: Double
    /// The reason in the person's own words, when they typed one.
    var note: String?
    /// Yes or no.
    var done: Bool
    /// Minutes put in, for goals that count time.
    var minutes: Int
    /// Paid results that day, for work that pays per result.
    var units: Int
    /// Other money earned that day, for work.
    var amount: Double
    /// The reasons picked, in the order they were tapped.
    var reasons: [String]

    init(id: String = uid(), goalId: String, day: String, at: Double = Date().timeIntervalSince1970 * 1000, note: String? = nil,
         done: Bool = true, minutes: Int = 0, units: Int = 0, amount: Double = 0, reasons: [String] = []) {
        self.id = id; self.goalId = goalId; self.day = day; self.at = at; self.note = note
        self.done = done; self.minutes = minutes; self.units = units; self.amount = amount; self.reasons = reasons
    }

    /// Lenient like Goal: a mark with no id or time still opens, and an old mark is a yes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? uid()
        goalId = try c.decode(String.self, forKey: .goalId)
        day = try c.decode(String.self, forKey: .day)
        at = try c.decodeIfPresent(Double.self, forKey: .at) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note)
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? true
        minutes = max(0, try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 0)
        units = max(0, try c.decodeIfPresent(Int.self, forKey: .units) ?? 0)
        amount = try c.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        reasons = try c.decodeIfPresent([String].self, forKey: .reasons) ?? []
    }

    /// Whether any reason was given, picked or typed.
    var hasReason: Bool { !reasons.isEmpty || !(note ?? "").isEmpty }
    /// Every reason on the mark, the typed one last.
    var allReasons: [String] { reasons + ((note ?? "").isEmpty ? [] : [note ?? ""]) }
}

/// One night, reported the morning after. The baseline and targets of that day are kept with
/// it, so changing them later never rewrites the past.
struct SleepLog: Codable, Hashable, Identifiable {
    var id: String
    /// The day you woke up.
    var day: String
    /// Minute of the day you went to sleep, 0..<1440.
    var bedMinute: Int
    /// Minute of the day you woke up.
    var wakeMinute: Int
    /// Your estimate of the time actually asleep.
    var sleptMinutes: Int
    /// 1...10.
    var quality: Int
    var reasons: [String]
    var note: String
    var at: Double
    /// The sleep you needed that night.
    var needMinutes: Int
    var targetBedMinute: Int
    var targetWakeMinute: Int

    init(id: String = uid(), day: String, bedMinute: Int, wakeMinute: Int, sleptMinutes: Int, quality: Int,
         reasons: [String] = [], note: String = "", at: Double = Date().timeIntervalSince1970 * 1000,
         needMinutes: Int = 480, targetBedMinute: Int = 22 * 60 + 30, targetWakeMinute: Int = 7 * 60) {
        self.id = id; self.day = day; self.bedMinute = bedMinute; self.wakeMinute = wakeMinute
        self.sleptMinutes = sleptMinutes; self.quality = quality; self.reasons = reasons; self.note = note; self.at = at
        self.needMinutes = needMinutes; self.targetBedMinute = targetBedMinute; self.targetWakeMinute = targetWakeMinute
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? uid()
        day = try c.decode(String.self, forKey: .day)
        bedMinute = clampMinute(try c.decodeIfPresent(Int.self, forKey: .bedMinute) ?? 22 * 60 + 30)
        wakeMinute = clampMinute(try c.decodeIfPresent(Int.self, forKey: .wakeMinute) ?? 7 * 60)
        sleptMinutes = min(max(try c.decodeIfPresent(Int.self, forKey: .sleptMinutes) ?? 0, 0), 24 * 60)
        quality = min(max(try c.decodeIfPresent(Int.self, forKey: .quality) ?? 5, 1), 10)
        reasons = try c.decodeIfPresent([String].self, forKey: .reasons) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        at = try c.decodeIfPresent(Double.self, forKey: .at) ?? 0
        needMinutes = try c.decodeIfPresent(Int.self, forKey: .needMinutes) ?? 480
        targetBedMinute = clampMinute(try c.decodeIfPresent(Int.self, forKey: .targetBedMinute) ?? 22 * 60 + 30)
        targetWakeMinute = clampMinute(try c.decodeIfPresent(Int.self, forKey: .targetWakeMinute) ?? 7 * 60)
    }

    /// Sleep short of the need that night: positive when under, negative when over.
    var debt: Int { needMinutes - sleptMinutes }
    var allReasons: [String] { reasons + (note.isEmpty ? [] : [note]) }
}

/// A month's number for a job, set at the start of the month (or whenever the month was joined).
struct MonthPlan: Codable, Hashable, Identifiable {
    var id: String
    var goalId: String
    /// "yyyy-MM".
    var month: String
    /// Money wanted from the job this month, after tax.
    var income: Double
    /// Hours a day planned for it this month.
    var hoursPerDay: Double
    /// The day it was set. Past the 1st, the plan is for the rest of the month.
    var setOn: String

    init(id: String = uid(), goalId: String, month: String, income: Double, hoursPerDay: Double, setOn: String = today()) {
        self.id = id; self.goalId = goalId; self.month = month; self.income = income; self.hoursPerDay = hoursPerDay; self.setOn = setOn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? uid()
        goalId = try c.decode(String.self, forKey: .goalId)
        month = try c.decode(String.self, forKey: .month)
        income = try c.decodeIfPresent(Double.self, forKey: .income) ?? 0
        hoursPerDay = try c.decodeIfPresent(Double.self, forKey: .hoursPerDay) ?? 8
        setOn = try c.decodeIfPresent(String.self, forKey: .setOn) ?? (month + "-01")
    }
}

/// One head-to-head: "if only one of these two could happen, which?"
struct Duel: Codable, Hashable, Identifiable {
    var id: String
    var a: String
    var b: String
    var winner: String
    var at: Double

    init(id: String = uid(), a: String, b: String, winner: String, at: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id; self.a = a; self.b = b; self.winner = winner; self.at = at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? uid()
        a = try c.decode(String.self, forKey: .a)
        b = try c.decode(String.self, forKey: .b)
        winner = try c.decode(String.self, forKey: .winner)
        at = try c.decodeIfPresent(Double.self, forKey: .at) ?? 0
    }

    func isBetween(_ x: String, _ y: String) -> Bool { (a == x && b == y) || (a == y && b == x) }
}

/// One line of a talk with the Oracle.
struct OracleTurn: Codable, Hashable, Identifiable {
    var id: String
    /// True for what you asked, false for what the Oracle said.
    var mine: Bool
    var text: String
    var at: Double

    init(id: String = uid(), mine: Bool, text: String, at: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id; self.mine = mine; self.text = text; self.at = at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? uid()
        mine = try c.decodeIfPresent(Bool.self, forKey: .mine) ?? true
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        at = try c.decodeIfPresent(Double.self, forKey: .at) ?? 0
    }
}

/// A minute of the day, kept inside 0..<1440.
func clampMinute(_ m: Int) -> Int { ((m % 1440) + 1440) % 1440 }

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
        "hourglass", "checkmark.seal.fill", "flag.checkered", "scalemass.fill", "shoeprints.fill", "character.bubble.fill",
    ]
}
