import Foundation

/// A goal the Ideas sheet offers. Small, concrete, and worded so a tired day can still do it.
/// Each is one of two sorts: something that takes hours, or a rule that takes none.
struct Starter: Identifiable, Hashable {
    let name: String
    let symbol: String
    let horizon: Horizon
    let schedule: Schedule
    let why: String
    var kind: GoalKind = .adherence
    /// The planned session, for ideas that take hours.
    var minutes: Int = 0
    var id: String { name }

    func goal(color: GoalColor) -> Goal {
        Goal(name: name, color: color, horizon: horizon, symbol: symbol, schedule: schedule, why: why,
             kind: kind, sessionMinutes: kind == .time ? minutes : 0)
    }
}

enum Starters {
    static let all: [Starter] = [
        // Takes hours: built in sessions, and the hours are counted.
        Starter(name: "Lift", symbol: "dumbbell.fill", horizon: .sixYears, schedule: .timesPerWeek(3),
                why: "Strength is the one thing that keeps paying.", kind: .time, minutes: 60),
        Starter(name: "Build the thing", symbol: "laptopcomputer", horizon: .sixYears, schedule: .weekdays(Weekday.workdays),
                why: "One honest hour on the project that is mine.", kind: .time, minutes: 60),
        Starter(name: "Learn a language", symbol: "character.bubble.fill", horizon: .sixYears, schedule: .timesPerWeek(3),
                why: "A little, often, for a long time.", kind: .time, minutes: 30),
        Starter(name: "Read", symbol: "book.fill", horizon: .sixYears, schedule: .daily,
                why: "Twenty minutes a day is a dozen books a year.", kind: .time, minutes: 15),
        Starter(name: "Learn something hard", symbol: "brain.head.profile", horizon: .sixYears, schedule: .timesPerWeek(4),
                why: "Time on the skill that scares me.", kind: .time, minutes: 30),
        Starter(name: "Cardio", symbol: "figure.run", horizon: .sixMonths, schedule: .timesPerWeek(3),
                why: "The body I have in six years is built this week.", kind: .time, minutes: 30),
        Starter(name: "Tidy up", symbol: "house.fill", horizon: .sixMonths, schedule: .daily,
                why: "A clear desk by the time I sit down.", kind: .time, minutes: 15),
        // Rules to keep: no hours, you either kept it that day or not.
        Starter(name: "Eat only what I planned", symbol: "fork.knife", horizon: .sixMonths, schedule: .daily,
                why: "The plan is made when I am not hungry."),
        Starter(name: "Stop eating when full", symbol: "scalemass.fill", horizon: .sixMonths, schedule: .daily,
                why: "Enough is a decision."),
        Starter(name: "10,000 steps", symbol: "shoeprints.fill", horizon: .sixMonths, schedule: .daily,
                why: "The phone counts them; I only answer yes or no."),
        Starter(name: "No alcohol", symbol: "drop.fill", horizon: .sixMonths, schedule: .daily,
                why: "Tomorrow morning is worth more."),
        Starter(name: "No sugar drinks", symbol: "drop.fill", horizon: .sixMonths, schedule: .daily,
                why: "Water does the job."),
        Starter(name: "In bed by my target", symbol: "bed.double.fill", horizon: .sixYears, schedule: .daily,
                why: "Every good day starts the night before."),
        Starter(name: "No phone in bed", symbol: "moon.fill", horizon: .sixMonths, schedule: .daily,
                why: "The phone charges in the other room."),
        Starter(name: "Sunscreen before going out", symbol: "sun.max.fill", horizon: .sixYears, schedule: .daily,
                why: "Skin keeps the score."),
        Starter(name: "Take my vitamins", symbol: "pills.fill", horizon: .sixMonths, schedule: .daily,
                why: "Thirty seconds."),
        Starter(name: "Spend nothing unplanned", symbol: "banknote.fill", horizon: .sixYears, schedule: .daily,
                why: "Future me is counting on it."),
        Starter(name: "Plan tomorrow", symbol: "pencil", horizon: .sixMonths, schedule: .daily,
                why: "Three things, written down tonight."),
        Starter(name: "Call family", symbol: "phone.fill", horizon: .sixYears, schedule: .timesPerWeek(2),
                why: "They will not be here forever."),
    ]
}
