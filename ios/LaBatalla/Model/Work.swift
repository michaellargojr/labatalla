import Foundation

// Work. Every job shares two numbers: hours in and money out. Dividing one by the other gives
// the one that tells the truth about "earn more, work less": money per hour. A month's number
// and the hours wanted for it say what an hour has to be worth; the days logged say what it is.

/// "$7,000", "$79.50", "$0". Whole amounts and anything from 100 up have no cents.
func money(_ value: Double, _ symbol: String = "$") -> String {
    let a = abs(value)
    let whole = a >= 100 || a == a.rounded()
    let cents = whole ? 0 : Int(((a - a.rounded(.down)) * 100).rounded())
    var units = Int(whole ? a.rounded() : a.rounded(.down))
    var carry = cents
    if carry == 100 { units += 1; carry = 0 }
    var digits = String(units)
    var grouped = ""
    while digits.count > 3 {
        grouped = "," + String(digits.suffix(3)) + grouped
        digits = String(digits.dropLast(3))
    }
    grouped = digits + grouped
    let tail = whole ? "" : "." + (carry < 10 ? "0" : "") + String(carry)
    return (value < 0 ? "-" : "") + symbol + grouped + tail
}

/// What a stretch of work days added up to.
struct WorkTotals: Equatable {
    var minutes: Int
    var units: Int
    var earned: Double
    var daysWorked: Int

    var hours: Double { Double(minutes) / 60 }
    /// Money per hour worked. Nil until an hour is logged.
    var perHour: Double? { minutes > 0 ? earned / hours : nil }
    var avgMinutesPerDay: Int? { daysWorked > 0 ? minutes / daysWorked : nil }
}

/// Hours, results and money for a job from `from` through `to`. Money is results times their
/// value, plus hours times the hourly rate, plus anything entered by hand, plus the share of the
/// fixed monthly pay that the planned work days in the stretch stand for.
func workTotals(_ goal: Goal, marks: [Mark], from: String, to: String) -> WorkTotals {
    let w = goal.workSetup
    let mine = marks.filter { $0.goalId == goal.id && $0.done && $0.day >= from && $0.day <= to }
    let minutes = mine.reduce(0) { $0 + $1.minutes }
    let units = mine.reduce(0) { $0 + $1.units }
    let byHand: Double = mine.reduce(0) { $0 + $1.amount }
    let byResult: Double = Double(units) * w.unitValue
    let byHour: Double = Double(minutes) / 60 * w.hourlyRate
    var earned: Double = byResult + byHand + byHour
    if w.basePerMonth > 0, from <= to {
        var m = monthStart(from)
        while m <= to {
            let all = plannedDays(goal.schedule, from: m, to: monthEnd(m))
            let part = plannedDays(goal.schedule, from: max(m, from), to: min(monthEnd(m), to))
            if all > 0 { earned += w.basePerMonth * Double(part) / Double(all) }
            m = addMonths(1, to: m)
        }
    }
    return WorkTotals(minutes: minutes, units: units, earned: earned, daysWorked: Set(mine.map(\.day)).count)
}

/// What an hour has to be worth for `income` to come from `hoursPerDay` over `workdays` days.
func neededPerHour(income: Double, hoursPerDay: Double, workdays: Double) -> Double? {
    let hours = hoursPerDay * workdays
    guard income > 0, hours > 0 else { return nil }
    return income / hours
}

/// Work days in an average month for a schedule: its days a week times 52 over 12.
func workdaysPerMonth(_ schedule: Schedule) -> Double { Double(schedule.daysPerWeek) * 52 / 12 }

/// The plan for a job in the month holding `day`: the latest one set.
func monthPlan(_ plans: [MonthPlan], goalId: String, month day: String) -> MonthPlan? {
    plans.filter { $0.goalId == goalId && $0.month == monthKey(day) }.max { $0.setOn < $1.setOn }
}

/// "November", or "The rest of November" when the plan was set after the month began.
func planTitle(month day: String, setOn: String) -> String {
    setOn > monthStart(day) ? "The rest of \(monthName(day))" : monthName(day)
}

/// The same inside a sentence: "November", "the rest of November".
func planWords(month day: String, setOn: String) -> String {
    setOn > monthStart(day) ? "the rest of \(monthName(day))" : monthName(day)
}

extension String {
    /// "meeting" to "Meeting".
    var capitalizedFirst: String { prefix(1).uppercased() + String(dropFirst()) }
}

/// "7000", "79.5": a number as it is typed into a field.
func plainNumber(_ v: Double) -> String {
    if v == 0 { return "" }
    return v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
}

/// What was typed, as a number: commas and the money sign are ignored, anything else is 0.
func typedNumber(_ text: String) -> Double {
    let clean = text.filter { $0.isNumber || $0 == "." }
    return max(0, Double(clean) ?? 0)
}

/// Where a month stands against its number.
struct MonthPace: Equatable {
    var target: Double
    var plannedHoursPerDay: Double
    var earned: Double
    var minutes: Int
    var daysWorked: Int
    /// Planned work days from the day the plan was set to the end of the month.
    var workdays: Int
    var workdaysLeft: Int
    /// What an hour has been worth so far.
    var perHour: Double?
    /// What an hour has to be worth for the number to come from the planned hours.
    var neededPerHour: Double?
    /// The month's total if the days left go like the days so far.
    var projected: Double?
    /// Hours a day the rest of the number takes at the rate so far.
    var hoursPerDayAtThisRate: Double?

    var left: Double { max(0, target - earned) }
    var share: Double { target > 0 ? earned / target : 0 }
}

/// The plan covers the days from when it was set to the month's end; `today` splits them into
/// gone and left. Today counts as left until it has a mark.
func monthPace(_ goal: Goal, plan: MonthPlan, marks: [Mark], today t: String) -> MonthPace {
    let first = max(monthStart(plan.month + "-01"), plan.setOn)
    let last = monthEnd(plan.month + "-01")
    let upTo = min(t, last)
    let totals = workTotals(goal, marks: marks, from: first, to: upTo)
    let workdays = plannedDays(goal.schedule, from: first, to: last)
    let todayMarked = marks.contains { $0.goalId == goal.id && $0.day == t }
    let goneThrough = todayMarked || t > last ? upTo : addDays(-1, to: upTo)
    let gone = plannedDays(goal.schedule, from: first, to: goneThrough)
    let left = max(0, workdays - gone)
    let perHour = totals.perHour
    var atThisRate: Double?
    if let r = perHour, r > 0, left > 0 {
        atThisRate = max(0, plan.income - totals.earned) / r / Double(left)
    }
    return MonthPace(
        target: plan.income, plannedHoursPerDay: plan.hoursPerDay, earned: totals.earned, minutes: totals.minutes,
        daysWorked: totals.daysWorked, workdays: workdays, workdaysLeft: left, perHour: perHour,
        neededPerHour: neededPerHour(income: plan.income, hoursPerDay: plan.hoursPerDay, workdays: Double(workdays)),
        projected: gone > 0 ? totals.earned / Double(gone) * Double(workdays) : nil,
        hoursPerDayAtThisRate: atThisRate)
}

/// Whether a job has no plan for the month holding `day` yet: time to ask for one.
func needsMonthPlan(_ goal: Goal, plans: [MonthPlan], today t: String) -> Bool {
    goal.kind == .work && goal.isActive(on: t) && monthPlan(plans, goalId: goal.id, month: t) == nil
}

/// "4h", "6h 15m" for hours given as a number: 4, 6.25.
func hoursOfDayLabel(_ hours: Double) -> String { durationLabel(Int((hours * 60).rounded())) }
