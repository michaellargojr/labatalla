import Foundation

// Insights: what the check-ins add up to, worked out without being asked. Each one is a plain
// statement of a pattern with the numbers behind it: where the hours went, what sleep did to the
// day after, which reason keeps coming back, where a plan and the pace disagree. They are read
// as a general reads a map: where the line is holding and where it is not. No blame in the words.

enum InsightArea: String, CaseIterable, Identifiable {
    case sleep, goals, reasons, time, work, estimates, importance
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sleep: return "Sleep"
        case .goals: return "Goals"
        case .reasons: return "Reasons"
        case .time: return "Time"
        case .work: return "Work"
        case .estimates: return "Estimates"
        case .importance: return "Importance"
        }
    }
    var symbol: String {
        switch self {
        case .sleep: return "moon.fill"
        case .goals: return "flag.fill"
        case .reasons: return "quote.bubble.fill"
        case .time: return "hourglass"
        case .work: return "briefcase.fill"
        case .estimates: return "calendar"
        case .importance: return "scalemass.fill"
        }
    }
}

struct Insight: Identifiable, Equatable {
    var id: String
    var area: InsightArea
    var title: String
    var detail: String
    /// Higher is shown first.
    var weight: Int
    var goalId: String? = nil
}

struct InsightInput {
    var goals: [Goal]
    var marks: [Mark]
    var sleep: [SleepLog]
    var plans: [MonthPlan] = []
    var duels: [Duel] = []
    var settings: Settings = Settings()
    var today: String = LaBatalla.today()
}

/// Every pattern the data shows right now, the heaviest first.
func insights(_ x: InsightInput) -> [Insight] {
    var out: [Insight] = []
    out += sleepInsights(x)
    out += sleepAndGoals(x)
    out += reasonInsights(x)
    out += paceInsights(x)
    out += importanceInsights(x)
    out += timeInsights(x)
    out += workInsights(x)
    out += weekdayInsights(x)
    out += smallSessions(x)
    out += coverage(x)
    return out.sorted { ($1.weight, $0.id) < ($0.weight, $1.id) }
}

/// The few to show first: the strongest from each area before a second from any, so one area
/// with a lot to say does not crowd out the rest. Kept in the order they came in.
func headline(_ all: [Insight], limit: Int) -> [Insight] {
    guard all.count > limit else { return all }
    var picked: [String] = []
    var seen: Set<InsightArea> = []
    for i in all where !seen.contains(i.area) {
        seen.insert(i.area)
        picked.append(i.id)
    }
    for i in all where picked.count < limit && !picked.contains(i.id) {
        picked.append(i.id)
    }
    let keep = Set(picked.prefix(limit))
    return all.filter { keep.contains($0.id) }
}

private func active(_ x: InsightInput) -> [Goal] {
    x.goals.filter { $0.isActive(on: x.today) }.sorted { ($0.order, $0.name) < ($1.order, $1.name) }
}

// MARK: Sleep

func sleepInsights(_ x: InsightInput) -> [Insight] {
    var out: [Insight] = []
    let t = x.today
    let week = sleepLogs(x.sleep, from: addDays(-6, to: t), to: t)
    if week.count >= 3, let s = sleepStats(week) {
        if s.avgDebt >= 30 {
            out.append(Insight(id: "sleep.debt", area: .sleep,
                title: "Sleep is running \(durationLabel(roundMinutes(s.avgDebt, to: 5))) short a night",
                detail: "The last \(s.nights) nights logged averaged \(durationLabel(s.avgSlept)). Your baseline is \(durationLabel(s.avgNeed)). That is \(durationLabel(max(0, s.totalDebt))) owed over those nights.",
                weight: 90 + min(s.avgDebt / 15, 9)))
        } else {
            out.append(Insight(id: "sleep.ok", area: .sleep,
                title: "Sleep is at your baseline",
                detail: "The last \(s.nights) nights logged averaged \(durationLabel(s.avgSlept)) against a baseline of \(durationLabel(s.avgNeed)).",
                weight: 30))
        }
        if s.avgBedOffset >= 30 {
            out.append(Insight(id: "sleep.bedtime", area: .sleep,
                title: "Bedtime is running \(durationLabel(roundMinutes(s.avgBedOffset, to: 5))) past target",
                detail: "Target \(clockLabel(s.targetBed)). The last \(s.nights) nights averaged \(clockLabel(roundMinutes(s.avgBed, to: 5))).",
                weight: 70))
        }
        if s.avgWakeOffset <= -30 {
            out.append(Insight(id: "sleep.wake", area: .sleep,
                title: "Waking \(durationLabel(roundMinutes(-s.avgWakeOffset, to: 5))) before target",
                detail: "Target \(clockLabel(s.targetWake)). The last \(s.nights) mornings averaged \(clockLabel(roundMinutes(s.avgWake, to: 5))).",
                weight: 48))
        }
    }

    let month = sleepLogs(x.sleep, from: addDays(-29, to: t), to: t)
    let full = month.filter { $0.debt < SHORT_NIGHT_MINUTES }
    let short = month.filter { $0.debt >= SHORT_NIGHT_MINUTES }
    if full.count >= 3, short.count >= 3 {
        let a = Double(full.reduce(0) { $0 + $1.quality }) / Double(full.count)
        let b = Double(short.reduce(0) { $0 + $1.quality }) / Double(short.count)
        if a - b >= 1 {
            out.append(Insight(id: "sleep.quality", area: .sleep,
                title: "Quality follows hours",
                detail: "Nights at or near your baseline: quality \(oneDecimal(a)). Shorter nights: \(oneDecimal(b)). \(full.count) and \(short.count) nights in the last 30 days.",
                weight: 50))
        }
    }

    let rough = month.filter { $0.quality <= 5 || $0.debt >= 60 }
    if rough.count >= 3, let top = reasonCounts(rough.map(\.allReasons)).first, top.count >= 2 {
        out.append(Insight(id: "sleep.reason", area: .reasons,
            title: "\"\(top.reason)\" comes up most on rough nights",
            detail: "It was the reason on \(top.count) of the \(rough.count) nights in the last 30 days that were rated 5 or lower, or ran an hour or more short.",
            weight: 66))
    }
    return out
}

/// What a day asked and what it got, for the days that have a sleep log.
private struct DayLoad { var asked: Int; var done: Int; var short: Bool }

private func dayLoads(_ x: InsightInput, days: Int) -> [String: DayLoad] {
    let t = x.today
    let done = doneByDay(x.marks)
    let start = x.settings.weekStart
    var out: [String: DayLoad] = [:]
    for log in sleepLogs(x.sleep, from: addDays(-(days - 1), to: t), to: t) where log.day < t {
        // Asked is every goal due that day; a times-a-week goal done that day counts as asked too.
        let due = x.goals.filter { isDue($0, on: log.day, done: done, weekStart: start) }
        guard !due.isEmpty else { continue }
        let got = due.filter { done[log.day]?.contains($0.id) == true }.count
        out[log.day] = DayLoad(asked: due.count, done: got, short: log.debt >= SHORT_NIGHT_MINUTES)
    }
    return out
}

func sleepAndGoals(_ x: InsightInput) -> [Insight] {
    let loads = Array(dayLoads(x, days: 42).values)
    let rested = loads.filter { !$0.short }, short = loads.filter(\.short)
    guard rested.count >= 4, short.count >= 4 else { return [] }
    func rate(_ l: [DayLoad]) -> Double { Double(l.reduce(0) { $0 + $1.done }) / Double(max(1, l.reduce(0) { $0 + $1.asked })) }
    let a = rate(rested), b = rate(short)
    guard abs(a - b) >= 0.15 else { return [] }
    if a > b {
        return [Insight(id: "sleep.goals", area: .sleep,
            title: "Short nights cost the day after",
            detail: "After nights at or near your baseline you did \(percentLabel(a)) of what the day asked. After short nights, \(percentLabel(b)). \(rested.count) and \(short.count) days in the last six weeks.",
            weight: 88)]
    }
    return [Insight(id: "sleep.goals", area: .sleep,
        title: "Short nights have not cost the day after",
        detail: "After short nights you did \(percentLabel(b)) of what the day asked; after full ones, \(percentLabel(a)). \(short.count) and \(rested.count) days in the last six weeks.",
        weight: 40)]
}

// MARK: Reasons

func reasonInsights(_ x: InsightInput) -> [Insight] {
    var out: [Insight] = []
    let t = x.today
    let from = addDays(-29, to: t)
    let recent = x.marks.filter { $0.day >= from && $0.day <= t }
    let sleepByDay = Dictionary(sleepLogs(x.sleep, from: from, to: t).map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })

    for g in active(x) where g.kind.hasCheckIn {
        let nos = recent.filter { $0.goalId == g.id && !$0.done }
        let stuck = nos.filter { $0.reasons.contains(NEXT_STEP_REASON) }.count
        if stuck >= 2 {
            out.append(Insight(id: "reason.step.\(g.id)", area: .reasons,
                title: "The next step is unclear for \(g.name)",
                detail: "\"\(NEXT_STEP_REASON)\" was the reason \(stuck) times in the last 30 days. That is about the goal, not the day: it may need a smaller first step, or a talk with the Oracle.",
                weight: 82, goalId: g.id))
        }
        guard nos.count >= 3, let top = reasonCounts(nos.map(\.allReasons)).first, top.count >= 2, top.reason != NEXT_STEP_REASON else { continue }
        var detail = "It was the reason \(top.count) of the \(nos.count) times the answer was no in the last 30 days."
        let days = nos.filter { $0.allReasons.contains(top.reason) }.map(\.day)
        let logged = days.compactMap { sleepByDay[$0] }
        let short = logged.filter { $0.debt >= SHORT_NIGHT_MINUTES }.count
        if logged.count >= 2, short * 2 >= logged.count {
            detail += " On \(short) of those \(logged.count) days, sleep had been under your baseline."
        }
        out.append(Insight(id: "reason.goal.\(g.id)", area: .reasons,
            title: "\"\(top.reason)\" is the usual reason for no on \(g.name)",
            detail: detail, weight: 74 + min(top.count, 6), goalId: g.id))
    }

    let allNos = recent.filter { !$0.done }
    if allNos.count >= 5 {
        let top = reasonCounts(allNos.map(\.allReasons)).prefix(3)
        if !top.isEmpty {
            out.append(Insight(id: "reason.all", area: .reasons,
                title: "The reasons given most, across every goal",
                detail: top.map { "\($0.reason) (\($0.count))" }.joined(separator: " - ") + ". Out of \(allNos.count) times the answer was no in the last 30 days.",
                weight: 56))
        }
    }
    return out
}

// MARK: Pace and dates

func paceInsights(_ x: InsightInput) -> [Insight] {
    var out: [Insight] = []
    let t = x.today
    for g in active(x) {
        if g.kind == .time, g.weeklyMinutes > 0, daysBetween(g.createdAt, t) >= 13,
           let pace = recentWeeklyMinutes(g, marks: x.marks, today: t) {
            let share = pace / Double(g.weeklyMinutes)
            let got = durationLabel(roundMinutes(Int(pace.rounded()), to: 5)), plan = durationLabel(g.weeklyMinutes)
            if share < 0.7 {
                out.append(Insight(id: "pace.under.\(g.id)", area: .goals,
                    title: "\(g.name) is getting \(got) a week of the \(plan) planned",
                    detail: "That is the average of the last four weeks. The plan and the week do not match yet; one of them moves.",
                    weight: 58 + g.importance, goalId: g.id))
            } else if share >= 1 {
                out.append(Insight(id: "pace.on.\(g.id)", area: .goals,
                    title: "\(g.name) is on plan",
                    detail: "\(got) a week over the last four weeks, against \(plan) planned.",
                    weight: 34, goalId: g.id))
            }
        }

        if g.kind == .time, g.totalHours > 0, daysBetween(g.createdAt, t) >= 13 {
            let done = minutesWorked(g.id, x.marks, from: "0000-00-00", to: t)
            let inSoFar = "\(hoursLabel(Double(done) / 60)) of \(hoursLabel(g.totalHours)) are in."
            if let finish = projectedFinish(g, marks: x.marks, today: t) {
                if let c = g.conservative, finish > c {
                    out.append(Insight(id: "finish.\(g.id)", area: .estimates,
                        title: "At this pace \(g.name) finishes around \(briefDay(finish, today: t))",
                        detail: "That is past your conservative date, \(briefDay(c, today: t)). \(inSoFar)",
                        weight: 71, goalId: g.id))
                } else if let r = g.reasonable, finish > r {
                    out.append(Insight(id: "finish.\(g.id)", area: .estimates,
                        title: "At this pace \(g.name) finishes around \(briefDay(finish, today: t))",
                        detail: "That is past your reasonable date, \(briefDay(r, today: t)). \(inSoFar)",
                        weight: 57, goalId: g.id))
                } else if let r = g.reasonable {
                    out.append(Insight(id: "finish.\(g.id)", area: .estimates,
                        title: "At this pace \(g.name) finishes around \(briefDay(finish, today: t))",
                        detail: "That is inside your reasonable date, \(briefDay(r, today: t)). \(inSoFar)",
                        weight: 33, goalId: g.id))
                }
            } else if let r = g.reasonable {
                out.append(Insight(id: "finish.\(g.id)", area: .estimates,
                    title: "\(g.name) has no pace to project yet",
                    detail: "No hours in the last four weeks. Your reasonable date is \(briefDay(r, today: t)). \(inSoFar)",
                    weight: 52, goalId: g.id))
            }
        }

        if let r = g.reasonable, r < t {
            out.append(Insight(id: "date.reasonable.\(g.id)", area: .estimates,
                title: "The reasonable date for \(g.name) has passed",
                detail: "It was \(briefDay(r, today: t)). Move it or mark the goal achieved; either way the first estimate is kept to learn from.",
                weight: 60, goalId: g.id))
        } else if let s = g.soonest, s < t {
            out.append(Insight(id: "date.soonest.\(g.id)", area: .estimates,
                title: "The soonest date for \(g.name) has passed",
                detail: "It was \(briefDay(s, today: t)). Worth remembering the next time a soonest date is picked.",
                weight: 38, goalId: g.id))
        }
    }

    for g in x.goals {
        guard let done = g.achievedAt, let r = g.reasonable else { continue }
        let d = daysBetween(r, done)
        let against = d == 0 ? "on your reasonable date" : d > 0 ? "\(d) days after your reasonable date" : "\(-d) days before your reasonable date"
        var detail = "Done \(briefDay(done, today: t)): \(against)."
        if let s = g.soonest { detail += " Soonest was \(briefDay(s, today: t))." }
        if let c = g.conservative { detail += " Conservative was \(briefDay(c, today: t))." }
        out.append(Insight(id: "achieved.\(g.id)", area: .estimates, title: "\(g.name): achieved", detail: detail, weight: 36, goalId: g.id))
    }
    return out
}

// MARK: Importance

func importanceInsights(_ x: InsightInput) -> [Insight] {
    var out: [Insight] = []
    let rows = standings(goals: active(x), duels: x.duels, marks: x.marks, today: x.today)

    // Said against did: a goal rated well above another, getting much less of its plan.
    var worst: (hi: Standing, lo: Standing, gap: Double)?
    for hi in rows where hi.said > 0 {
        for lo in rows where lo.said > 0 && hi.said - lo.said >= 3 {
            guard let a = hi.did, let b = lo.did, b - a >= 0.25 else { continue }
            if worst == nil || b - a > worst!.gap { worst = (hi, lo, b - a) }
        }
    }
    if let w = worst, let a = w.hi.did, let b = w.lo.did {
        out.append(Insight(id: "importance.did", area: .importance,
            title: "You rated \(w.hi.name) \(w.hi.said) and \(w.lo.name) \(w.lo.said). The days went the other way.",
            detail: "Over the last four weeks \(w.lo.name) got \(percentLabel(b)) of its plan and \(w.hi.name) got \(percentLabel(a)).",
            weight: 73, goalId: w.hi.id))
    }

    // Said against chose: the lower-rated goal won the head-to-head.
    let pool = active(x)
    for d in x.duels.sorted(by: { $0.at > $1.at }) {
        guard let a = pool.first(where: { $0.id == d.a }), let b = pool.first(where: { $0.id == d.b }) else { continue }
        let winner = d.winner == a.id ? a : b, loser = d.winner == a.id ? b : a
        guard winner.importance > 0, loser.importance - winner.importance >= 2 else { continue }
        if out.contains(where: { $0.id == "importance.chose" }) { break }
        out.append(Insight(id: "importance.chose", area: .importance,
            title: "Head to head, you chose \(winner.name) over \(loser.name)",
            detail: "You rated \(loser.name) \(loser.importance) and \(winner.name) \(winner.importance). When only one could happen, the lower number won.",
            weight: 68, goalId: loser.id))
    }

    for g in pool where g.clarity > 0 && g.clarity <= UNCLEAR_PATH {
        out.append(Insight(id: "path.\(g.id)", area: .goals,
            title: "The path to \(g.name) is not clear yet",
            detail: "You rated it \(g.clarity) of 10. A first goal could simply be: find out how. Ask the Oracle what you are not seeing.",
            weight: 62 + g.importance, goalId: g.id))
    }
    return out
}

// MARK: Time

func timeInsights(_ x: InsightInput) -> [Insight] {
    var out: [Insight] = []
    let pool = active(x)
    let b = timeBudget(goals: pool, sleepNeed: x.settings.sleepNeedMinutes, today: x.today)
    if b.work + b.goals > 0 {
        let parts = "A week has 168h. Sleep at your baseline takes \(durationLabel(b.sleep)), work \(durationLabel(b.work)), goals \(durationLabel(b.goals))."
        if b.left < 0 {
            out.append(Insight(id: "time.over", area: .time,
                title: "The plan asks for more hours than a week has",
                detail: parts + " That is \(durationLabel(-b.left)) over.", weight: 95))
        } else if b.leftPerDay < 4 * 60 {
            out.append(Insight(id: "time.tight", area: .time,
                title: "The plan leaves \(durationLabel(roundMinutes(b.leftPerDay, to: 5))) a day for everything else",
                detail: parts + " Eating, people, getting around and rest come out of what is left.", weight: 78))
        } else {
            out.append(Insight(id: "time.room", area: .time,
                title: "The plan leaves \(durationLabel(roundMinutes(b.leftPerDay, to: 5))) a day for everything else",
                detail: parts, weight: 22))
        }
    }

    var seen = Set<String>()
    for g in pool {
        for other in pool where g.conflicts.contains(other.id) {
            let key = g.id < other.id ? "\(g.id)|\(other.id)" : "\(other.id)|\(g.id)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if !x.duels.contains(where: { $0.isBetween(g.id, other.id) }) {
                out.append(Insight(id: "conflict.\(key)", area: .time,
                    title: "\(g.name) and \(other.name) pull against each other",
                    detail: "You marked them as competing. Decide which one wins when they collide, in Head to head.",
                    weight: 59, goalId: g.id))
            }
        }
    }
    return out
}

// MARK: Work

func workInsights(_ x: InsightInput) -> [Insight] {
    var out: [Insight] = []
    let t = x.today
    let sign = x.settings.currency
    for g in active(x) where g.kind == .work {
        let w = g.workSetup
        if let plan = monthPlan(x.plans, goalId: g.id, month: t) {
            let p = monthPace(g, plan: plan, marks: x.marks, today: t)
            if let rate = p.perHour, let need = p.neededPerHour, p.daysWorked >= 3 {
                if rate < need * 0.9 {
                    var detail = "\(money(p.earned, sign)) of \(money(p.target, sign)) so far in \(durationLabel(p.minutes))."
                    if let h = p.hoursPerDayAtThisRate {
                        detail += " At this rate the rest takes \(hoursOfDayLabel(h)) a day, against the \(hoursOfDayLabel(p.plannedHoursPerDay)) planned."
                    }
                    out.append(Insight(id: "work.rate.\(g.id)", area: .work,
                        title: "\(g.name) is paying \(money(rate, sign)) an hour. This month's number needs \(money(need, sign)).",
                        detail: detail, weight: 87, goalId: g.id))
                } else {
                    out.append(Insight(id: "work.rate.\(g.id)", area: .work,
                        title: "\(g.name) is paying \(money(rate, sign)) an hour, at or above what this month needs",
                        detail: "\(money(p.earned, sign)) of \(money(p.target, sign)) so far in \(durationLabel(p.minutes)). The number needs \(money(need, sign)) an hour at \(hoursOfDayLabel(p.plannedHoursPerDay)) a day.",
                        weight: 44, goalId: g.id))
                }
            }
        } else {
            out.append(Insight(id: "work.plan.\(g.id)", area: .work,
                title: "\(planTitle(month: t, setOn: t)) has no number yet for \(g.name)",
                detail: "Set what you want it to pay and the hours a day you want to give it. Money per hour follows from those two.",
                weight: 92, goalId: g.id))
        }

        // The six-month picture, against the last 30 days.
        let recent = workTotals(g, marks: x.marks, from: addDays(-29, to: t), to: t)
        if recent.daysWorked >= 5, let rate = recent.perHour,
           let need = neededPerHour(income: w.targetIncome, hoursPerDay: w.targetHours, workdays: workdaysPerMonth(g.schedule)) {
            if rate < need * 0.9 {
                let times = need / max(rate, 0.01)
                out.append(Insight(id: "work.six.\(g.id)", area: .work,
                    title: "\(money(w.targetIncome, sign)) a month at \(hoursOfDayLabel(w.targetHours)) a day needs \(money(need, sign)) an hour",
                    detail: "The last 30 days paid \(money(rate, sign)) an hour. The gap is \(oneDecimal(times))x. More hours at this rate do not close it inside \(hoursOfDayLabel(w.targetHours)) a day; the rate has to change.",
                    weight: 86, goalId: g.id))
            } else {
                out.append(Insight(id: "work.six.\(g.id)", area: .work,
                    title: "The six-month target is within today's rate",
                    detail: "\(money(w.targetIncome, sign)) a month at \(hoursOfDayLabel(w.targetHours)) a day needs \(money(need, sign)) an hour. The last 30 days paid \(money(rate, sign)).",
                    weight: 42, goalId: g.id))
            }
        }
        if recent.daysWorked >= 5, let avg = recent.avgMinutesPerDay {
            out.append(Insight(id: "work.hours.\(g.id)", area: .work,
                title: "Work days are averaging \(durationLabel(roundMinutes(avg, to: 5)))",
                detail: "The job expects \(hoursOfDayLabel(w.requiredHours)). Your six-month target is \(hoursOfDayLabel(w.targetHours)). \(recent.daysWorked) days worked in the last 30.",
                weight: 46, goalId: g.id))
        }
    }
    return out
}

// MARK: Days of the week

func weekdayInsights(_ x: InsightInput) -> [Insight] {
    let t = x.today
    let done = doneByDay(x.marks)
    let start = x.settings.weekStart
    var asked: [Weekday: Int] = [:], got: [Weekday: Int] = [:], seen: [Weekday: Int] = [:]
    for day in daysFrom(addDays(-56, to: t), through: addDays(-1, to: t)) {
        let due = x.goals.filter { isDue($0, on: day, done: done, weekStart: start) }
        guard !due.isEmpty else { continue }
        let w = Weekday.of(day)
        seen[w, default: 0] += 1
        asked[w, default: 0] += due.count
        got[w, default: 0] += due.filter { done[day]?.contains($0.id) == true }.count
    }
    let rates: [(Weekday, Double)] = Weekday.allCases.compactMap { w -> (Weekday, Double)? in
        guard let n = seen[w], n >= 4, let a = asked[w], a > 0 else { return nil }
        return (w, Double(got[w] ?? 0) / Double(a))
    }
    guard rates.count >= 5, let best = rates.max(by: { $0.1 < $1.1 }), let worst = rates.min(by: { $0.1 < $1.1 }),
          best.1 - worst.1 >= 0.3 else { return [] }
    return [Insight(id: "weekday", area: .goals,
        title: "\(best.0.full)s carry the most, \(worst.0.full)s the least",
        detail: "Over the last eight weeks: \(percentLabel(best.1)) of what was asked on \(best.0.full)s, \(percentLabel(worst.1)) on \(worst.0.full)s.",
        weight: 45)]
}

// MARK: Small things

func smallSessions(_ x: InsightInput) -> [Insight] {
    let from = addDays(-29, to: x.today)
    let n = x.marks.filter { $0.done && $0.minutes > 0 && $0.minutes <= 15 && $0.day >= from && $0.day <= x.today }.count
    guard n >= 2 else { return [] }
    return [Insight(id: "small", area: .goals,
        title: "\(n) sessions of fifteen minutes or less this month",
        detail: "Each one colored its day like any other. Anything is better than nothing.",
        weight: 20)]
}

func coverage(_ x: InsightInput) -> [Insight] {
    var out: [Insight] = []
    let nights = Set(x.sleep.map(\.day)).count
    if nights < 7 {
        out.append(Insight(id: "cover.sleep", area: .sleep,
            title: nights == 0 ? "No nights logged yet" : nights == 1 ? "1 night logged" : "\(nights) nights logged",
            detail: "Sleep patterns start to show after about a week of check-ins.",
            weight: 12))
    }
    let answers = x.marks.count
    if !x.goals.isEmpty && answers < 10 {
        out.append(Insight(id: "cover.goals", area: .goals,
            title: answers == 0 ? "No check-ins yet" : answers == 1 ? "1 check-in so far" : "\(answers) check-ins so far",
            detail: "Goal patterns, and what the reasons add up to, show after a couple of weeks.",
            weight: 11))
    }
    return out
}
