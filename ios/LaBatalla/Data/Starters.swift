import Foundation

/// A goal the Ideas sheet offers. Small, concrete, and worded so a tired day can still do it.
struct Starter: Identifiable, Hashable {
    let name: String
    let symbol: String
    let horizon: Horizon
    let schedule: Schedule
    let why: String
    var id: String { name }

    func goal(color: GoalColor) -> Goal {
        Goal(name: name, color: color, horizon: horizon, symbol: symbol, schedule: schedule, why: why)
    }
}

enum Starters {
    static let all: [Starter] = [
        // Six years: the long game.
        Starter(name: "Move my body", symbol: "figure.run", horizon: .sixYears, schedule: .daily,
                why: "The body I have in six years is built this week."),
        Starter(name: "Lift", symbol: "dumbbell.fill", horizon: .sixYears, schedule: .timesPerWeek(3),
                why: "Strength is the one thing that keeps paying."),
        Starter(name: "Read 10 pages", symbol: "book.fill", horizon: .sixYears, schedule: .daily,
                why: "Ten pages a day is a dozen books a year."),
        Starter(name: "Build the thing", symbol: "laptopcomputer", horizon: .sixYears, schedule: .weekdays(Weekday.workdays),
                why: "One honest hour on the project that is mine."),
        Starter(name: "Put money away", symbol: "banknote.fill", horizon: .sixYears, schedule: .timesPerWeek(1),
                why: "Future me is counting on it."),
        Starter(name: "Call family", symbol: "phone.fill", horizon: .sixYears, schedule: .timesPerWeek(2),
                why: "They will not be here forever."),
        Starter(name: "In bed by midnight", symbol: "bed.double.fill", horizon: .sixYears, schedule: .daily,
                why: "Every good day starts the night before."),
        Starter(name: "Learn something hard", symbol: "brain.head.profile", horizon: .sixYears, schedule: .weekdays(Weekday.workdays),
                why: "Twenty minutes on the skill that scares me."),
        // Six months: the short game.
        Starter(name: "Drink water", symbol: "drop.fill", horizon: .sixMonths, schedule: .daily,
                why: "A full bottle before noon."),
        Starter(name: "Walk outside", symbol: "sun.max.fill", horizon: .sixMonths, schedule: .daily,
                why: "Daylight on my face, even ten minutes."),
        Starter(name: "Inbox to zero", symbol: "envelope.fill", horizon: .sixMonths, schedule: .weekdays(Weekday.workdays),
                why: "Nothing waiting on me overnight."),
        Starter(name: "Tidy for 10 minutes", symbol: "house.fill", horizon: .sixMonths, schedule: .daily,
                why: "A clear desk by the time I sit down."),
        Starter(name: "Plan tomorrow", symbol: "pencil", horizon: .sixMonths, schedule: .daily,
                why: "Three things, written down tonight."),
        Starter(name: "No phone in bed", symbol: "moon.fill", horizon: .sixMonths, schedule: .daily,
                why: "The phone charges in the other room."),
    ]
}
