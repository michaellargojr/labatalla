import Foundation

// Hours. What a plan adds up to before it starts (the setup questions show this, so the answers
// can be changed until they are realistic), and what the marks add up to once it is running:
// this week, this month, in all, and where the pace of the last weeks leads.

/// The arithmetic of a time goal's plan: so many sessions a week, so long each, toward a total.
struct TimePlan: Equatable {
    var sessionsPerWeek: Int
    var totalHours: Double
    var sessionMinutes: Int

    var weeklyMinutes: Int { sessionsPerWeek * sessionMinutes }

    /// Sessions that fit between two days at this many a week.
    func sessions(from: String, to: String) -> Double {
        Double(max(0, daysBetween(from, to))) / 7 * Double(sessionsPerWeek)
    }

    /// How long each session has to be for the total to fit by `day`. Nil when there is no total,
    /// no sessions, or less than one session of room.
    func sessionMinutesNeeded(from: String, by day: String) -> Int? {
        let n = sessions(from: from, to: day)
        guard totalHours > 0, n >= 1 else { return nil }
        return Int((totalHours * 60 / n).rounded())
    }

    /// Hours put in by `day` if the plan is kept from `from`.
    func hoursBy(_ day: String, from: String) -> Double {
        sessions(from: from, to: day) * Double(sessionMinutes) / 60
    }

    /// The day the total is reached if the plan is kept from `from`.
    func finishDay(from: String) -> String? {
        guard totalHours > 0, weeklyMinutes > 0 else { return nil }
        let days = totalHours * 60 / Double(weeklyMinutes) * 7
        return addDays(Int(days.rounded(.up)), to: from)
    }
}

extension Goal {
    var plan: TimePlan { TimePlan(sessionsPerWeek: schedule.daysPerWeek, totalHours: totalHours, sessionMinutes: sessionMinutes) }
}

/// "12h", "1.5h", "0h": hours for a line of text, without a trailing ".0".
func hoursLabel(_ hours: Double) -> String {
    let r = (hours * 10).rounded() / 10
    return r == r.rounded() ? "\(Int(r))h" : String(format: "%.1fh", r)
}

/// Minutes put into a goal from `from` through `to`.
func minutesWorked(_ goalId: String, _ marks: [Mark], from: String, to: String) -> Int {
    var total = 0
    for m in marks where m.goalId == goalId && m.done && m.day >= from && m.day <= to { total += m.minutes }
    return total
}

/// Days a goal got a yes from `from` through `to`.
func daysDone(_ goalId: String, _ marks: [Mark], from: String, to: String) -> Int {
    Set(marks.filter { $0.goalId == goalId && $0.done && $0.day >= from && $0.day <= to }.map(\.day)).count
}

/// Days the schedule plans from `from` through `to`. Times-a-week goals: their share of the days.
func plannedDays(_ schedule: Schedule, from: String, to: String) -> Int {
    guard from <= to else { return 0 }
    switch schedule {
    case .daily:
        return daysBetween(from, to) + 1
    case .weekdays(let days):
        return daysFrom(from, through: to).filter { days.contains(Weekday.of($0)) }.count
    case .timesPerWeek(let n):
        return Int((Double(daysBetween(from, to) + 1) / 7 * Double(n)).rounded())
    }
}

/// The trees and the forest for one goal: this week, this month, and in all, each against what
/// the plan asked. Minutes for goals that count time, days for every goal.
struct GoalProgress: Equatable {
    var weekMinutes: Int
    var weekTarget: Int
    var monthMinutes: Int
    var monthTarget: Int
    var totalMinutes: Int
    /// The goal's whole estimate in minutes. 0 when it has none.
    var totalTarget: Int
    var weekDays: Int
    var weekDaysTarget: Int
    var monthDays: Int
    var monthDaysTarget: Int
    var totalDays: Int
}

func progress(_ goal: Goal, marks: [Mark], today t: String, weekStart start: WeekStart) -> GoalProgress {
    let week = weekDays(t, start)
    let mStart = monthStart(t), mEnd = monthEnd(t)
    // A goal made mid-month is only asked for the rest of it.
    let from = max(mStart, goal.createdAt)
    let asked = plannedDays(goal.schedule, from: from, to: mEnd)
    let weekly = goal.weeklyMinutes
    let all = marks.filter { $0.goalId == goal.id && $0.done }
    return GoalProgress(
        weekMinutes: minutesWorked(goal.id, all, from: week[0], to: week[6]),
        weekTarget: weekly,
        monthMinutes: minutesWorked(goal.id, all, from: mStart, to: mEnd),
        monthTarget: goal.kind == .time ? asked * goal.sessionMinutes : 0,
        totalMinutes: all.reduce(0) { $0 + $1.minutes },
        totalTarget: Int((goal.totalHours * 60).rounded()),
        weekDays: daysDone(goal.id, all, from: week[0], to: week[6]),
        weekDaysTarget: goal.schedule.daysPerWeek,
        monthDays: daysDone(goal.id, all, from: mStart, to: mEnd),
        monthDaysTarget: asked,
        totalDays: Set(all.map(\.day)).count)
}

/// Minutes a week over the last `days` days (or since the goal began, if that is shorter). Nil
/// until there is a full week to read.
func recentWeeklyMinutes(_ goal: Goal, marks: [Mark], today t: String, days: Int = 28) -> Double? {
    let from = max(goal.createdAt, addDays(-(days - 1), to: t))
    let span = daysBetween(from, t) + 1
    guard span >= 7 else { return nil }
    return Double(minutesWorked(goal.id, marks, from: from, to: t)) / Double(span) * 7
}

/// The share of its plan a goal got over the last `days` days, 0...1 and beyond: minutes against
/// planned minutes when it counts time and has a session length, days against planned days otherwise.
func planShare(_ goal: Goal, marks: [Mark], today t: String, days: Int = 28) -> Double? {
    guard goal.kind.hasCheckIn else { return nil }
    let from = max(goal.createdAt, addDays(-(days - 1), to: t))
    guard daysBetween(from, t) + 1 >= 7 else { return nil }
    let asked = plannedDays(goal.schedule, from: from, to: t)
    guard asked > 0 else { return nil }
    if goal.kind == .time && goal.sessionMinutes > 0 {
        return Double(minutesWorked(goal.id, marks, from: from, to: t)) / Double(asked * goal.sessionMinutes)
    }
    return Double(daysDone(goal.id, marks, from: from, to: t)) / Double(asked)
}

/// Where the pace of the last weeks leads: the day the goal's hours would all be in.
func projectedFinish(_ goal: Goal, marks: [Mark], today t: String) -> String? {
    guard goal.kind == .time, goal.totalHours > 0, let pace = recentWeeklyMinutes(goal, marks: marks, today: t), pace > 0 else { return nil }
    let done = minutesWorked(goal.id, marks, from: "0000-00-00", to: t)
    let left = goal.totalHours * 60 - Double(done)
    if left <= 0 { return t }
    let days = (left / pace * 7).rounded(.up)
    // Past a century is not a date, it is a no.
    guard days < 36_500 else { return nil }
    return addDays(Int(days), to: t)
}

/// "62%" for 0.62.
func percentLabel(_ share: Double) -> String { "\(Int((share * 100).rounded()))%" }
