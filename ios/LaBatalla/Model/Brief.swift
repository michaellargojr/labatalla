import Foundation

// The battlefield brief: everything the app knows, written out as plain text. It is what the
// Oracle reads before it answers, and what "Copy my brief" puts on the clipboard. Facts only,
// in the same words the app uses; the reading of them is left to whoever gets the brief.

func battlefieldBrief(_ x: InsightInput) -> String {
    let t = x.today
    var out: [String] = ["LA BATALLA - battlefield brief for \(mediumDay(t)) (\(Weekday.of(t).full))", ""]
    out += briefSleep(x)
    out.append("")

    let goals = x.goals.filter { $0.isActive(on: t) }.sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    let names = Dictionary(x.goals.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    if goals.isEmpty {
        out.append("GOALS: none set yet.")
    } else {
        out.append("GOALS (\(goals.count) active)")
        for g in goals { out += briefGoal(g, x, names: names) }
    }
    out.append("")

    let achieved = x.goals.filter(\.isAchieved)
    if !achieved.isEmpty {
        out.append("ACHIEVED")
        for g in achieved {
            var line = "- \(g.name), done \(mediumDay(g.achievedAt ?? t))"
            if let r = g.reasonable { line += " (reasonable date was \(mediumDay(r)))" }
            out.append(line)
        }
        out.append("")
    }

    let rows = standings(goals: goals, duels: x.duels, marks: x.marks, today: t).filter { $0.played > 0 }
    if !rows.isEmpty {
        out.append("HEAD TO HEAD (if only one of two could happen, which)")
        for r in rows.sorted(by: { ($1.wins, $0.name) < ($0.wins, $1.name) }) {
            out.append("- \(r.name): won \(r.wins) of \(r.played)" + (r.said > 0 ? ", rated \(r.said)/10" : ""))
        }
        out.append("")
    }

    let b = timeBudget(goals: goals, sleepNeed: x.settings.sleepNeedMinutes, today: t)
    out.append("THE WEEK IF EVERY PLAN IS KEPT (168h)")
    out.append("- Sleep at the baseline: \(durationLabel(b.sleep))")
    out.append("- Work: \(durationLabel(b.work))")
    out.append("- Goals that take hours: \(durationLabel(b.goals))")
    out.append(b.left >= 0 ? "- Left for everything else: \(durationLabel(b.left)), \(durationLabel(b.leftPerDay)) a day"
                           : "- Over by \(durationLabel(-b.left))")
    out.append("")

    let open = goals.flatMap { g in openQuestions(g, goals: x.goals, duels: x.duels, today: t).map { (g.name, $0) } }
    if !open.isEmpty {
        out.append("QUESTIONS THE SETUP LEFT OPEN")
        for (name, q) in open { out.append("- \(name): \(q.title). \(q.detail)") }
        out.append("")
    }

    let seen = insights(x)
    if !seen.isEmpty {
        out.append("PATTERNS THE APP SEES")
        for i in seen { out.append("- \(i.title). \(i.detail)") }
    }
    return out.joined(separator: "\n")
}

private func briefSleep(_ x: InsightInput) -> [String] {
    let t = x.today
    let s = x.settings
    var out = ["SLEEP",
               "- Baseline (the sleep this person needs): \(durationLabel(s.sleepNeedMinutes))",
               "- Target bedtime \(clockLabel(s.targetBedMinute)), target wake time \(clockLabel(s.targetWakeMinute))"]
    for days in [7, 30] {
        let logs = sleepLogs(x.sleep, from: addDays(-(days - 1), to: t), to: t)
        guard let st = sleepStats(logs) else { continue }
        var line = "- Last \(days) days, \(st.nights) nights logged: slept \(durationLabel(st.avgSlept)) on average"
        line += ", quality \(oneDecimal(st.avgQuality))/10"
        line += ", bedtime around \(clockLabel(roundMinutes(st.avgBed, to: 5)))"
        line += ", up around \(clockLabel(roundMinutes(st.avgWake, to: 5)))"
        line += ", \(st.shortNights) short nights"
        line += st.totalDebt > 0 ? ", \(durationLabel(st.totalDebt)) owed against the baseline" : ", nothing owed against the baseline"
        out.append(line)
    }
    let month = sleepLogs(x.sleep, from: addDays(-29, to: t), to: t)
    if month.isEmpty { out.append("- No nights logged in the last 30 days.") }
    let reasons = reasonCounts(month.map(\.allReasons)).prefix(5).map { "\($0.reason) (\($0.count))" }
    if !reasons.isEmpty { out.append("- Reasons given with the sleep check-ins: " + reasons.joined(separator: ", ")) }
    return out
}

private func briefGoal(_ g: Goal, _ x: InsightInput, names: [String: String]) -> [String] {
    let t = x.today
    var head = "- \(g.name) [\(g.kind.label)]"
    head += g.importance > 0 ? ", importance \(g.importance)/10" : ", importance not rated"
    if g.kind != .adherence { head += g.clarity > 0 ? ", path clarity \(g.clarity)/10" : ", path clarity not rated" }
    var lines = [head]
    if !g.why.isEmpty { lines.append("  Why: \(g.why)") }
    if !g.finishLine.isEmpty { lines.append("  Finish line: \(g.finishLine)") }
    var dates: [String] = []
    if let d = g.soonest { dates.append("soonest \(mediumDay(d))") }
    if let d = g.reasonable { dates.append("reasonable \(mediumDay(d))") }
    if let d = g.conservative { dates.append("conservative \(mediumDay(d))") }
    if !dates.isEmpty { lines.append("  Dates set on \(mediumDay(g.createdAt)): " + dates.joined(separator: ", ")) }
    if let parent = g.parentId, let n = names[parent] { lines.append("  Serves: \(n)") }
    let against = g.conflicts.compactMap { names[$0] }
    if !against.isEmpty { lines.append("  Pulls against: " + against.joined(separator: ", ")) }
    guard g.kind.hasCheckIn else { return lines }

    let pr = progress(g, marks: x.marks, today: t, weekStart: x.settings.weekStart)
    switch g.kind {
    case .time:
        var plan = "  Plan: \(g.schedule.label.lowercased())"
        if g.sessionMinutes > 0 { plan += ", \(durationLabel(g.sessionMinutes)) a session, \(durationLabel(g.weeklyMinutes)) a week" }
        if g.totalHours > 0 { plan += ", estimated \(hoursLabel(g.totalHours)) in all" }
        lines.append(plan)
        lines.append("  Hours in: this week \(durationLabel(pr.weekMinutes)), this month \(durationLabel(pr.monthMinutes)), in all \(hoursLabel(Double(pr.totalMinutes) / 60))")
        if let f = projectedFinish(g, marks: x.marks, today: t) {
            lines.append("  At the pace of the last four weeks the hours are all in around \(mediumDay(f))")
        }
    case .work:
        lines += briefWork(g, x)
    case .adherence, .outcome:
        lines.append("  Plan: \(g.schedule.label.lowercased())")
        lines.append("  Days kept: this week \(pr.weekDays) of \(pr.weekDaysTarget), this month \(pr.monthDays) of \(pr.monthDaysTarget), in all \(pr.totalDays)")
    }
    if let share = planShare(g, marks: x.marks, today: t) {
        lines.append("  Share of its plan it got, last four weeks: \(percentLabel(share))")
    }

    let from = addDays(-29, to: t)
    let recent = x.marks.filter { $0.goalId == g.id && $0.day >= from && $0.day <= t }
    let nos = recent.filter { !$0.done }
    let yeses = recent.filter(\.done)
    lines.append("  Check-ins, last 30 days: yes \(yeses.count), no \(nos.count)")
    let whyNo = reasonCounts(nos.map(\.allReasons)).prefix(4).map { "\($0.reason) (\($0.count))" }
    if !whyNo.isEmpty { lines.append("  Reasons given with no: " + whyNo.joined(separator: ", ")) }
    let whyYes = reasonCounts(yeses.map(\.allReasons)).prefix(3).map { "\($0.reason) (\($0.count))" }
    if !whyYes.isEmpty { lines.append("  Reasons given with yes: " + whyYes.joined(separator: ", ")) }
    return lines
}

private func briefWork(_ g: Goal, _ x: InsightInput) -> [String] {
    let t = x.today
    let sign = x.settings.currency
    let w = g.workSetup
    var lines: [String] = []
    var pay: [String] = []
    if w.basePerMonth > 0 { pay.append("\(money(w.basePerMonth, sign)) fixed a month") }
    if w.hourlyRate > 0 { pay.append("\(money(w.hourlyRate, sign)) an hour") }
    if w.paysPerResult { pay.append("\(money(w.unitValue, sign)) per \(w.unitName)") }
    lines.append("  Pay (after tax): " + (pay.isEmpty ? "not set" : pay.joined(separator: ", ")))
    lines.append("  Works \(g.schedule.label.lowercased()), job expects \(hoursOfDayLabel(w.requiredHours)) a day")
    if w.targetIncome > 0 {
        var line = "  Six-month target: \(money(w.targetIncome, sign)) a month at \(hoursOfDayLabel(w.targetHours)) a day"
        if let need = neededPerHour(income: w.targetIncome, hoursPerDay: w.targetHours, workdays: workdaysPerMonth(g.schedule)) {
            line += ", which needs \(money(need, sign)) an hour"
        }
        lines.append(line)
    }
    if let plan = monthPlan(x.plans, goalId: g.id, month: t) {
        let p = monthPace(g, plan: plan, marks: x.marks, today: t)
        var line = "  \(planTitle(month: t, setOn: plan.setOn)): wants \(money(plan.income, sign)) at \(hoursOfDayLabel(plan.hoursPerDay)) a day"
        line += "; so far \(money(p.earned, sign)) in \(durationLabel(p.minutes)) over \(p.daysWorked) days"
        if let r = p.perHour { line += ", \(money(r, sign)) an hour" }
        if let n = p.neededPerHour { line += " (the number needs \(money(n, sign)) an hour)" }
        line += ", \(p.workdaysLeft) work days left"
        lines.append(line)
    } else {
        lines.append("  No number set for this month yet")
    }
    let recent = workTotals(g, marks: x.marks, from: addDays(-29, to: t), to: t)
    if recent.daysWorked > 0 {
        var line = "  Last 30 days: \(recent.daysWorked) days worked, \(durationLabel(recent.minutes)), \(money(recent.earned, sign)) earned"
        if let r = recent.perHour { line += ", \(money(r, sign)) an hour" }
        if w.paysPerResult { line += ", \(recent.units) \(w.unitName)s" }
        lines.append(line)
    }
    return lines
}
