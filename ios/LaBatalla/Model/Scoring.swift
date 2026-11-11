import Foundation

// What the calendar shows for a day, worked out from the goals and the marks. Nothing here
// counts misses: a day is its colors and its badges, and a day with none is just an uncolored day.

/// One day, summed up.
struct DaySummary: Equatable {
    let day: String
    /// Goals marked that day, in Goals order. Their colors are the day's bands.
    var done: [Goal]
    /// Goals asked of that day: active, and planned for it by their schedule.
    var due: [Goal]
    var badges: Set<Badge>

    var colors: [GoalColor] { done.map(\.color) }
    var isColored: Bool { !done.isEmpty }
    /// Goals asked of the day and not yet marked: what is still open, never "missed".
    var open: [Goal] {
        let ids = Set(done.map(\.id))
        return due.filter { !ids.contains($0.id) }
    }
    func done(_ h: Horizon) -> [Goal] { done.filter { $0.horizon == h } }
    func due(_ h: Horizon) -> [Goal] { due.filter { $0.horizon == h } }
    /// The one badge a tile shows: the crown, else the star, else the bolt.
    var topBadge: Badge? {
        if badges.contains(.victory) { return .victory }
        if badges.contains(.longTerm) { return .longTerm }
        if badges.contains(.shortTerm) { return .shortTerm }
        return nil
    }
}

/// Which goal ids were marked on each day.
typealias DoneByDay = [String: Set<String>]

/// Only a yes colors a day. A no is an answer too, but it is never on the calendar.
func doneByDay(_ marks: [Mark]) -> DoneByDay {
    var out: DoneByDay = [:]
    for m in marks where m.done { out[m.day, default: []].insert(m.goalId) }
    return out
}

/// Whether `goal` is asked of `day`. Daily and weekday goals: whenever planned. Times-a-week
/// goals: when marked that day, or once the rest of the week could not make the count without it.
func isDue(_ goal: Goal, on day: String, done: DoneByDay, weekStart start: WeekStart) -> Bool {
    guard goal.kind.hasCheckIn, goal.isActive(on: day) else { return false }
    switch goal.schedule {
    case .daily:
        return true
    case .weekdays(let days):
        return days.contains(Weekday.of(day))
    case .timesPerWeek(let n):
        if done[day]?.contains(goal.id) == true { return true }
        let week = weekDays(day, start)
        let before = week.filter { $0 < day && done[$0]?.contains(goal.id) == true }.count
        let needed = max(0, n - before)
        guard needed > 0 else { return false }
        let left = week.filter { $0 >= day }.count
        return needed >= left
    }
}

/// Everything the calendar needs to know about `day`. `goals` are all of them, retired ones too,
/// so a retired goal's old marks keep their color.
func summarize(_ day: String, goals: [Goal], done: DoneByDay, weekStart start: WeekStart) -> DaySummary {
    let ids = done[day] ?? []
    let marked = goals.filter { ids.contains($0.id) }
    let due = goals.filter { isDue($0, on: day, done: done, weekStart: start) }
    var badges = Set<Badge>()
    func complete(_ h: Horizon) -> Bool {
        let asked = due.filter { $0.horizon == h }
        return !asked.isEmpty && asked.allSatisfy { ids.contains($0.id) }
    }
    if complete(.sixMonths) { badges.insert(.shortTerm) }
    if complete(.sixYears) { badges.insert(.longTerm) }
    if !due.isEmpty && due.allSatisfy({ ids.contains($0.id) }) { badges.insert(.victory) }
    return DaySummary(day: day, done: marked, due: due, badges: badges)
}

/// Summaries for many days, sharing one pass over the marks.
func summarize(_ days: [String], goals: [Goal], marks: [Mark], weekStart start: WeekStart) -> [String: DaySummary] {
    let done = doneByDay(marks)
    var out: [String: DaySummary] = [:]
    for d in days { out[d] = summarize(d, goals: goals, done: done, weekStart: start) }
    return out
}

// MARK: Runs

/// How many planned days (or weeks, for a times-a-week goal) in a row a goal has been marked.
/// Today does not break a run before it is over, and days the goal is not planned for never do.
struct Streak: Equatable {
    var current: Int
    var best: Int
    /// "day" or "week".
    var unit: String

    func text(_ n: Int) -> String { "\(n) \(unit)\(n == 1 ? "" : "s")" }
    var currentText: String { text(current) }
    var bestText: String { text(best) }
}

func streak(_ goal: Goal, done: DoneByDay, weekStart start: WeekStart, today t: String = today()) -> Streak {
    let firstMark = done.filter { $0.value.contains(goal.id) }.keys.min()
    let from = min(goal.createdAt, firstMark ?? goal.createdAt)
    let to = min(t, goal.archivedAt.map { addDays(-1, to: $0) } ?? t)
    guard from <= to else { return Streak(current: 0, best: 0, unit: "day") }
    func marked(_ d: String) -> Bool { done[d]?.contains(goal.id) == true }

    if case .timesPerWeek(let n) = goal.schedule {
        var current = 0, best = 0
        let thisWeek = weekStart(to, start)
        for w in weekStarts(from: from, to: to, start) {
            let count = weekDays(w, start).filter(marked).count
            if count >= n { current += 1; best = max(best, current) }
            else if w != thisWeek { current = 0 }
        }
        return Streak(current: current, best: best, unit: "week")
    }

    var current = 0, best = 0
    var d = from
    while d <= to {
        if goal.schedule.includes(d) {
            if marked(d) { current += 1; best = max(best, current) }
            else if d != t { current = 0 }
        }
        d = addDays(1, to: d)
    }
    return Streak(current: current, best: best, unit: "day")
}

/// How many days a goal has been marked, ever.
func totalMarks(_ goal: Goal, done: DoneByDay) -> Int { done.values.filter { $0.contains(goal.id) }.count }

/// How many days a goal has been marked in the month holding `day`.
func marksInMonth(_ goal: Goal, month day: String, done: DoneByDay) -> Int {
    let m = monthStart(day)
    return done.filter { monthStart($0.key) == m && $0.value.contains(goal.id) }.count
}

// MARK: Month totals

/// The lines under a month's grid. Only what happened, never what did not.
struct MonthStats: Equatable {
    /// Days with at least one mark.
    var colored: Int
    /// Days every asked goal was done.
    var victories: Int
    /// Days every long-term goal asked was done.
    var longTerm: Int
    /// Days every short-term goal asked was done.
    var shortTerm: Int
    /// Marks in all.
    var marks: Int

    var isEmpty: Bool { colored == 0 }
}

func monthStats(_ summaries: [DaySummary]) -> MonthStats {
    MonthStats(colored: summaries.filter(\.isColored).count,
               victories: summaries.filter { $0.badges.contains(.victory) }.count,
               longTerm: summaries.filter { $0.badges.contains(.longTerm) }.count,
               shortTerm: summaries.filter { $0.badges.contains(.shortTerm) }.count,
               marks: summaries.reduce(0) { $0 + $1.done.count })
}

/// "12 days colored", "1 day colored".
func coloredText(_ n: Int) -> String { n == 1 ? "1 day colored" : "\(n) days colored" }
/// "3 battles won", "1 battle won".
func victoriesText(_ n: Int) -> String { n == 1 ? "1 battle won" : "\(n) battles won" }
/// "6 long-term days".
func longTermText(_ n: Int) -> String { n == 1 ? "1 long-term day" : "\(n) long-term days" }
/// "4 short-term days".
func shortTermText(_ n: Int) -> String { n == 1 ? "1 short-term day" : "\(n) short-term days" }
