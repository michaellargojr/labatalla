import SwiftUI

/// Insights: the battlefield from above. First the patterns the check-ins add up to, stated
/// plainly and without being asked for. Then sleep, work, and every goal with its week, its
/// month and its total. Then what you said matters next to what you chose and what you did.
struct InsightsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var showAll = false
    @State private var oracle = false
    @State private var faceOff = false
    @State private var sleeping = false
    @State private var planning: Goal?

    /// How many patterns show before "Show all".
    private let first = 5

    var body: some View {
        let t = today()
        let found = insights(store.insightInput(today: t))
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle("Insights") {
                    PillButton(title: "Oracle", style: .primary, icon: "sparkles") { oracle = true }
                }
                if store.goals.isEmpty && store.sleep.isEmpty {
                    EmptyNote("Patterns show up here once there are a few check-ins: sleep each morning, a yes or no for each goal.")
                        .padding(.horizontal, 16)
                } else {
                    patterns(found).id("patterns")
                    sleepBlock(t).id("sleep")
                    workBlock(t).id("work")
                    goalsBlock(t).id("goals")
                    standingsBlock(t).id("standings")
                    monthBlock(t).id("month")
                }
            }
            .padding(.bottom, 24)
        }
        #if DEBUG
        .onAppear {
            if DebugLaunch.screen == "oracle" { oracle = true }
            if DebugLaunch.screen == "faceoff" { faceOff = true }
            if DebugLaunch.screen == "plan" { planning = store.workGoals.first }
            if DebugLaunch.has("-all") { showAll = true }
            if let a = DebugLaunch.anchor {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { proxy.scrollTo(a, anchor: .top) }
            }
        }
        #endif
        }
        .screen()
        .sheet(isPresented: $oracle) {
            OracleView()
                .presentationDetents([.large])
                .presentationBackground(p.bg)
        }
        .sheet(isPresented: $faceOff) {
            FaceOffView()
                .presentationDetents([.large])
                .presentationBackground(p.bg)
        }
        .sheet(isPresented: $sleeping) {
            SleepCheckInView(day: today())
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(p.card)
        }
        .sheet(item: $planning) { g in
            MonthPlanSheet(goal: g)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(p.card)
        }
    }

    private func block<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            content()
        }
        .padding(.horizontal, 16)
    }

    private func line(_ left: String, _ right: String, strong: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left).font(.system(size: 14)).foregroundStyle(p.secondary)
            Spacer(minLength: 8)
            Text(right).font(.system(size: 15, weight: strong ? .heavy : .bold)).monospacedDigit().foregroundStyle(p.text)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: Patterns

    private func patterns(_ found: [Insight]) -> some View {
        let shown = showAll ? found : Array(found.prefix(first))
        return block("What the days add up to") {
            if found.isEmpty {
                EmptyNote("Nothing stands out yet. Patterns need a week or two of check-ins.")
            } else {
                VStack(spacing: 8) {
                    ForEach(shown) { i in InsightCard(insight: i, goal: i.goalId.flatMap { store.goal($0) }) }
                }
                if found.count > first {
                    Chip(text: showAll ? "Show fewer" : "Show all \(found.count)", icon: showAll ? "chevron.up" : "chevron.down") {
                        withAnimation(.snappy(duration: 0.25)) { showAll.toggle() }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: Sleep

    private func sleepBlock(_ t: String) -> some View {
        let days = daysFrom(addDays(-13, to: t), through: t)
        let byDay = store.sleepByDay
        let week = sleepStats(sleepLogs(store.sleep, from: addDays(-6, to: t), to: t))
        let need = store.settings.sleepNeedMinutes
        return block("Sleep") {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SleepChart(days: days, logs: byDay, need: need)
                    Text("Last 14 nights. The line is your baseline, \(durationLabel(need)).")
                        .font(.system(size: 12)).foregroundStyle(p.muted)
                    if let s = week {
                        HStack(spacing: 8) {
                            StatTile(value: durationLabel(s.avgSlept), label: "AVG, 7 DAYS")
                            StatTile(value: oneDecimal(s.avgQuality), label: "QUALITY")
                            StatTile(value: durationLabel(max(0, s.totalDebt)), label: "OWED")
                        }
                        HStack(spacing: 8) {
                            StatTile(value: clockLabel(roundMinutes(s.avgBed, to: 5)), label: "TO SLEEP")
                            StatTile(value: clockLabel(roundMinutes(s.avgWake, to: 5)), label: "UP")
                        }
                    }
                    if byDay[t] == nil {
                        PillButton(title: "Sleep check-in", style: .primary, icon: "moon.fill", full: true) { sleeping = true }
                    }
                }
            }
        }
    }

    // MARK: Work

    @ViewBuilder
    private func workBlock(_ t: String) -> some View {
        let jobs = store.workGoals
        if !jobs.isEmpty {
            block("Work") {
                ForEach(jobs) { g in workCard(g, today: t) }
            }
        }
    }

    private func workCard(_ g: Goal, today t: String) -> some View {
        let sign = store.settings.currency
        let w = g.workSetup
        let plan = store.plan(for: g.id, month: t)
        let pace = plan.map { monthPace(g, plan: $0, marks: store.marks, today: t) }
        let sixMonth = neededPerHour(income: w.targetIncome, hoursPerDay: w.targetHours, workdays: workdaysPerMonth(g.schedule))
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    GoalIcon(goal: g, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text).lineLimit(2)
                        Text(plan.map { planTitle(month: t, setOn: $0.setOn) } ?? monthName(t))
                            .font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    Spacer(minLength: 8)
                    if plan != nil { Chip(text: "Change") { planning = g } }
                }
                if let pace {
                    MeterRow(title: "Earned", value: "\(money(pace.earned, sign)) of \(money(pace.target, sign))",
                             share: pace.share, color: p.color(g.color))
                    if let rate = pace.perHour { line("An hour is paying", money(rate, sign), strong: true) }
                    if let need = pace.neededPerHour { line("This month's number needs", "\(money(need, sign)) an hour") }
                    line("Hours so far", "\(durationLabel(pace.minutes)) over \(pace.daysWorked) days")
                    if let projected = pace.projected, pace.daysWorked >= 3 {
                        line("At this pace the month ends at", money(projected, sign))
                    }
                    line("Work days left", "\(pace.workdaysLeft)")
                } else {
                    PillButton(title: "Set the number for \(planWords(month: t, setOn: t))", style: .primary, full: true) { planning = g }
                }
                if let sixMonth {
                    Divider1()
                    line("In six months", "\(money(w.targetIncome, sign)) at \(hoursOfDayLabel(w.targetHours)) a day")
                    line("That needs", "\(money(sixMonth, sign)) an hour")
                }
            }
        }
    }

    // MARK: Goals

    @ViewBuilder
    private func goalsBlock(_ t: String) -> some View {
        let goals = store.activeGoals
        if !goals.isEmpty {
            block("Goals") {
                ForEach(goals) { g in goalCard(g, today: t) }
            }
        }
    }

    private func goalCard(_ g: Goal, today t: String) -> some View {
        let open = openQuestions(g, goals: store.goals, duels: store.duels, today: t)
        let served = store.children(of: g.id)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    GoalIcon(goal: g, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(g.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text).lineLimit(2)
                        Text(goalLine(g, today: t)).font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if g.importance > 0 { ImportanceTag(value: g.importance) }
                }
                if g.kind.hasCheckIn {
                    GoalMeters(goal: g, asOf: t)
                    WeekStrip(goal: g, today: t)
                }
                if g.kind == .time, let finish = projectedFinish(g, marks: store.marks, today: t) {
                    line("At this pace, done around", mediumDay(finish))
                }
                if !served.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Served by").font(.system(size: 13, weight: .semibold)).foregroundStyle(p.secondary)
                        ForEach(served) { c in
                            HStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(p.color(c.color)).frame(width: 12, height: 12)
                                Text(c.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.text).lineLimit(1)
                                Spacer(minLength: 8)
                                if let share = planShare(c, marks: store.marks, today: t) {
                                    Text("\(percentLabel(share)) of plan").font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundStyle(p.secondary)
                                }
                            }
                        }
                    }
                }
                if !open.isEmpty {
                    Text(open.count == 1 ? "1 question still open: \(open[0].title.lowercased())" : "\(open.count) questions still open, on its page in Goals")
                        .font(.system(size: 13)).foregroundStyle(p.accent)
                }
            }
        }
    }

    /// "Takes hours - 3 times a week - by Jun 21, 2027".
    private func goalLine(_ g: Goal, today t: String) -> String {
        var parts = [g.kind.label]
        if g.kind.hasCheckIn { parts.append(g.schedule.label) }
        if let r = g.reasonable { parts.append("by \(briefDay(r, today: t))") }
        if let parent = g.parentId, let n = store.goal(parent)?.name { parts.append("serves \(n)") }
        return parts.joined(separator: " - ")
    }

    // MARK: Said, chose, did

    @ViewBuilder
    private func standingsBlock(_ t: String) -> some View {
        let rows = standings(goals: store.activeGoals, duels: store.duels, marks: store.marks, today: t)
        if rows.count >= 2 {
            let count = duelCount(duelable(store.activeGoals, today: t), duels: store.duels)
            block("Said, chose, did") {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        StandingsTable(rows: rows)
                        Text("Said: the 1 to 10 you gave it. Chose: where it ranks when two goals go head to head and only one can happen. Did: the share of its plan it got in the last four weeks.")
                            .font(.system(size: 12)).foregroundStyle(p.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        PillButton(title: count.done == 0 ? "Head to head" : "Head to head - \(count.done) of \(count.of) decided",
                                   icon: "arrow.left.arrow.right", full: true) { faceOff = true }
                    }
                }
            }
        }
    }

    // MARK: The month

    private func monthBlock(_ t: String) -> some View {
        let days = monthDays(t).filter { $0 <= t }
        let sums = store.summaries(days)
        let stats = monthStats(days.compactMap { sums[$0] })
        return block("\(monthName(t)) so far") {
            HStack(spacing: 8) {
                StatTile(value: "\(stats.colored)", label: "DAYS COLORED")
                StatTile(value: "\(stats.victories)", label: "BATTLES WON")
                StatTile(value: "\(stats.marks)", label: "YESES")
            }
        }
    }
}

/// One pattern: where it is from, what it is, and the numbers behind it.
struct InsightCard: View {
    @Environment(\.palette) private var p
    let insight: Insight
    var goal: Goal? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.area.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(goal == nil ? p.accent : p.onBand)
                .frame(width: 36, height: 36)
                .background(goal.map { p.color($0.color) } ?? p.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.area.label.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(p.muted)
                Text(insight.title).font(.system(size: 16, weight: .bold)).foregroundStyle(p.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.detail).font(.system(size: 14)).foregroundStyle(p.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// "9" on a small square: the importance given at setup.
struct ImportanceTag: View {
    @Environment(\.palette) private var p
    let value: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("\(value)").font(.system(size: 16, weight: .heavy)).monospacedDigit().foregroundStyle(p.text)
            Text("of 10").font(.system(size: 9, weight: .bold)).foregroundStyle(p.muted)
        }
        .frame(width: 40, height: 40)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Importance \(value) of 10")
    }
}
