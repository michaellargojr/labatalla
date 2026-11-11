import SwiftUI

/// A goal's page, and the questions that set one up. Setup is allowed to take a few minutes:
/// it captures the first view of the goal (how important, by when, how many hours, how clear
/// the path is) so that what happens later can be read against it. The page does the sums as
/// the answers go in, and lists whatever they leave open. A new goal is added with Add; an
/// existing one saves every change as it is made, so Back is always safe.
struct GoalEditorView: View {
    enum Mode: Hashable { case create, edit(String) }
    enum ScheduleKind: String, CaseIterable, Identifiable {
        case daily = "Every day", some = "Some days", times = "Times a week"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    @State private var draft = Goal(name: "", kind: .time)
    @State private var kind: ScheduleKind = .times
    @State private var days: Set<Weekday> = Weekday.workdays
    @State private var times = 3
    @State private var work = WorkSetup()
    @State private var baseText = ""
    @State private var unitValueText = ""
    @State private var rateText = ""
    @State private var incomeText = ""
    @State private var requiredMinutes = 8 * 60
    @State private var targetMinutes = 8 * 60
    @State private var confirmDelete = false
    @State private var prepared = false

    private var isNew: Bool {
        if case .create = mode { return true }
        return false
    }
    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var schedule: Schedule {
        switch kind {
        case .daily: return .daily
        case .some: return .weekdays(days)
        case .times: return .timesPerWeek(times)
        }
    }
    private var sign: String { store.settings.currency }

    /// The draft as it would be saved: its schedule and job folded in, its words trimmed, and
    /// its horizon taken from the reasonable date.
    private var current: Goal {
        var g = draft
        g.name = trimmedName
        g.schedule = schedule
        g.why = draft.why.trimmingCharacters(in: .whitespacesAndNewlines)
        g.finishLine = draft.finishLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if g.kind == .work {
            var w = work
            w.basePerMonth = typedNumber(baseText)
            w.unitValue = typedNumber(unitValueText)
            w.hourlyRate = typedNumber(rateText)
            w.targetIncome = typedNumber(incomeText)
            w.requiredHours = Double(requiredMinutes) / 60
            w.targetHours = Double(targetMinutes) / 60
            w.unitName = work.unitName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            g.work = w
        } else {
            g.work = nil
        }
        if g.kind != .time { g.totalHours = 0; g.sessionMinutes = 0 }
        if let r = g.reasonable { g.horizon = horizon(for: r) }
        return g
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            if prepared {
                VStack(alignment: .leading, spacing: 26) {
                    Group {
                        nameField
                        kindPicker
                        importanceBlock
                        if draft.kind == .time || draft.kind == .outcome { finishBlock }
                        if draft.kind != .work { datesBlock.id("dates") }
                        if draft.kind == .time { hoursBlock.id("hours") }
                        if draft.kind == .adherence { whenBlock("When is it asked?", "A rule is asked every day it applies. No hours are counted.") }
                        if draft.kind == .work { workBlock.id("work") }
                    }
                    Group {
                        if draft.kind != .adherence { pathBlock.id("path") }
                        relationsBlock
                        whyField
                        colorGrid
                        symbolGrid
                        openBlock.id("open")
                        if !isNew { dangerZone }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        #if DEBUG
        .onAppear {
            if let a = DebugLaunch.anchor {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { proxy.scrollTo(a, anchor: .top) }
            }
        }
        #endif
        }
        .scrollDismissesKeyboard(.interactively)
        .screen()
        .navigationTitle(isNew ? "New goal" : "Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(p.bg, for: .navigationBar)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }.fontWeight(.bold).disabled(trimmedName.isEmpty)
                }
            }
        }
        .onAppear(perform: prepare)
        .onChange(of: current) { _, g in
            // An existing goal saves as you go. A blank name is never saved.
            guard !isNew, prepared, !g.name.isEmpty else { return }
            store.put(g)
        }
        .confirmationDialog("Delete this goal and every day it colored?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete goal", role: .destructive) {
                store.delete(draft.id)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        }
    }

    // MARK: Pieces

    private func question(_ title: String, _ detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(p.text)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail).font(.system(size: 14)).foregroundStyle(p.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ left: String, _ right: String, strong: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left).font(.system(size: 14)).foregroundStyle(p.secondary)
            Spacer(minLength: 8)
            Text(right).font(.system(size: 15, weight: strong ? .heavy : .bold)).monospacedDigit().foregroundStyle(p.text)
        }
    }

    // MARK: Blocks

    private var nameField: some View {
        FieldBox {
            TextField("What are you fighting for?", text: $draft.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(p.text)
                .submitLabel(.done)
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            question("What sort of goal is it?")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(GoalKind.allCases) { k in
                    let on = draft.kind == k
                    Button { pick(k) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: k.symbol).font(.system(size: 17, weight: .bold))
                            Text(k.label).font(.system(size: 16, weight: .heavy))
                        }
                        .foregroundStyle(on ? p.onAccent : p.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(on ? p.accent : p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            note(draft.kind.detail)
        }
    }

    private var importanceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            question("How important is it for you to achieve this goal?", "Not by a certain time. Just that question, by itself.")
            ScoreRow(value: $draft.importance, low: "Would be nice", high: "Everything")
        }
    }

    private var finishBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            question("How will you know it is done?", "Something a stranger could check.")
            FieldBox {
                TextField("The finish line", text: $draft.finishLine, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(p.text)
                    .lineLimit(1...4)
            }
        }
    }

    private var datesBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            question("When?", draft.kind == .adherence
                     ? "Only if this rule has an end. Three dates, kept as they are today."
                     : "Three dates. They are kept as they are today, to compare with what happens.")
            DateQuestion(title: "The soonest you possibly could", day: $draft.soonest)
            DateQuestion(title: "A reasonable date", day: $draft.reasonable)
            DateQuestion(title: "A very conservative date", day: $draft.conservative)
            if let a = draft.soonest, let b = draft.reasonable, let c = draft.conservative, a > b || b > c {
                note("Soonest comes first, then reasonable, then conservative.")
            }
        }
    }

    private func whenBlock(_ title: String, _ detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            question(title, detail)
            HStack(spacing: 8) {
                ForEach(ScheduleKind.allCases) { k in Chip(text: k.rawValue, on: kind == k) { kind = k } }
            }
            if kind == .some {
                HStack(spacing: 6) {
                    ForEach(Weekday.ordered(store.settings.weekStart)) { d in
                        let on = days.contains(d)
                        Button {
                            if on { days.remove(d) } else { days.insert(d) }
                        } label: {
                            Text(d.letter).font(.system(size: 14, weight: .bold))
                                .foregroundStyle(on ? p.onAccent : p.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(on ? p.accent : p.card, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(d.short)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            if kind == .times {
                CountRow(title: times == 1 ? "Once a week" : "\(times) times a week", value: $times, range: 1...6)
            }
        }
    }

    /// Times a week, total hours, and what the two come to: the sums that let the answers be
    /// changed until they are realistic.
    private var hoursBlock: some View {
        let t = today()
        let g = current
        let plan = g.plan
        var ahead: [(String, String)] = []
        if let d = g.soonest, d > t { ahead.append(("soonest", d)) }
        if let d = g.reasonable, d > t { ahead.append(("reasonable", d)) }
        if let d = g.conservative, d > t { ahead.append(("conservative", d)) }
        let dates = ahead
        return VStack(alignment: .leading, spacing: 14) {
            whenBlock("How many times a week do you need to work on this?", nil)
            VStack(alignment: .leading, spacing: 10) {
                question("How many hours do you think it takes in all?", "Your honest guess. Leave it at none for something with no end, like staying fit.")
                DialRow(title: "Total hours", value: totalHoursBinding, values: DialValues.totalHours,
                        major: { $0 % 100 == 0 }) { $0 == 0 ? "None" : "\($0)h" }
            }
            if g.totalHours > 0 && !dates.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(hoursLabel(g.totalHours)) at \(g.schedule.label.lowercased()) means each session is")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(p.secondary)
                        ForEach(dates, id: \.0) { d in
                            let need = plan.sessionMinutesNeeded(from: t, by: d.1)
                            line("by \(briefDay(d.1, today: t)) (\(d.0))", need.map { durationLabel(roundMinutes($0, to: 5)) } ?? "no room")
                        }
                        if let r = g.reasonable, r > t, let need = plan.sessionMinutesNeeded(from: t, by: r) {
                            let fit = min(max(roundMinutes(need), 15), 8 * 60)
                            if fit != draft.sessionMinutes {
                                PillButton(title: "Use \(durationLabel(fit)) a session", icon: "arrow.down") { draft.sessionMinutes = fit }
                                    .padding(.top, 2)
                            }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                question("How long is one session?", "What you can really give it each time. Change it until the numbers below look true.")
                DialRow(title: "One session", value: sessionBinding, values: DialValues.session, major: DialValues.isHour) {
                    $0 <= 5 ? "A few min" : durationLabel($0)
                }
            }
            if g.sessionMinutes > 0 {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        line("Each week", durationLabel(plan.weeklyMinutes), strong: true)
                        ForEach(dates, id: \.0) { d in
                            line("by \(briefDay(d.1, today: t)) (\(d.0))", hoursLabel(plan.hoursBy(d.1, from: t)))
                        }
                        if g.totalHours > 0 {
                            Divider1()
                            line("You estimated", hoursLabel(g.totalHours))
                            if let f = plan.finishDay(from: t) {
                                line("All of it is in around", mediumDay(f), strong: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private var totalHoursBinding: Binding<Int> {
        Binding(get: { Int(draft.totalHours.rounded()) }, set: { draft.totalHours = Double($0) })
    }
    private var sessionBinding: Binding<Int> {
        Binding(get: { draft.sessionMinutes == 0 ? 60 : draft.sessionMinutes }, set: { draft.sessionMinutes = $0 })
    }

    /// The job: which days, how it pays, what it expects, and where it should be in six months.
    private var workBlock: some View {
        let g = current
        let w = g.workSetup
        let monthDays = workdaysPerMonth(g.schedule)
        let need = neededPerHour(income: w.targetIncome, hoursPerDay: w.targetHours, workdays: monthDays)
        let atRequired = neededPerHour(income: w.targetIncome, hoursPerDay: w.requiredHours, workdays: monthDays)
        return VStack(alignment: .leading, spacing: 18) {
            whenBlock("Which days do you work?", nil)
            VStack(alignment: .leading, spacing: 10) {
                question("How does it pay?", "After tax. Fill in whichever apply; leave the rest empty.")
                moneyField("Fixed pay a month", $baseText)
                moneyField("Pay per hour", $rateText)
                HStack(spacing: 8) {
                    FieldBox {
                        TextField("A result: sale, meeting, deal", text: $work.unitName)
                            .font(.system(size: 16)).foregroundStyle(p.text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    moneyField("Each pays", $unitValueText).frame(width: 130)
                }
                note("With pay per result, the daily check-in asks how many, and money per hour is worked out from it.")
            }
            VStack(alignment: .leading, spacing: 10) {
                question("How many hours a day does the job expect?")
                DialRow(title: "Expected", value: $requiredMinutes, values: DialValues.workDay, major: DialValues.isHour) { durationLabel($0) }
            }
            VStack(alignment: .leading, spacing: 10) {
                question("Six months from now", "Further than that is too far to see. What should it pay a month, and how many hours a day do you want to give it?")
                moneyField("Money a month", $incomeText)
                DialRow(title: "Hours a day", value: $targetMinutes, values: DialValues.workDay, major: DialValues.isHour) { durationLabel($0) }
            }
            if let need {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(money(w.targetIncome, sign)) a month at \(hoursOfDayLabel(w.targetHours)) a day")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(p.secondary)
                        line("An hour has to be worth", money(need, sign), strong: true)
                        if let atRequired, w.requiredHours != w.targetHours {
                            line("At the expected \(hoursOfDayLabel(w.requiredHours))", "\(money(atRequired, sign)) an hour")
                        }
                        line("Work days in a month", oneDecimal(monthDays))
                        note("Once a few days are logged, Insights shows what an hour is actually worth next to this.")
                    }
                }
            }
        }
    }

    private func moneyField(_ title: String, _ text: Binding<String>) -> some View {
        FieldBox {
            HStack(spacing: 6) {
                Text(sign).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.muted)
                TextField(title, text: text)
                    .font(.system(size: 16)).foregroundStyle(p.text)
                    .keyboardType(.decimalPad)
            }
        }
    }

    private var pathBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            question("How clear is the path from here to done?", "1 is no idea how. 10 is knowing every step.")
            ScoreRow(value: $draft.clarity, low: "No idea how", high: "Every step")
            if draft.clarity > 0 && draft.clarity <= UNCLEAR_PATH {
                note("Then the first goal may be to find out how: a few hours a week of looking into it. The Oracle, in Insights, is a place to start.")
            }
        }
    }

    /// What it serves, and what it pulls against.
    private var relationsBlock: some View {
        let others = store.activeGoals.filter { $0.id != draft.id && $0.parentId != draft.id }
        return Group {
            if !others.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        question("Does it serve a bigger goal?")
                        FlowLayout(spacing: 7) {
                            Chip(text: "No", on: draft.parentId == nil) { draft.parentId = nil }
                            ForEach(others) { o in
                                Chip(text: o.name, on: draft.parentId == o.id) { draft.parentId = o.id }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        question("Does it pull against another goal?", "Time, energy, or two things that cannot both be true. Tap any it competes with.")
                        FlowLayout(spacing: 7) {
                            ForEach(others) { o in
                                let on = draft.conflicts.contains(o.id)
                                Chip(text: o.name, on: on) {
                                    if on { draft.conflicts.removeAll { $0 == o.id } } else { draft.conflicts.append(o.id) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var whyField: some View {
        VStack(alignment: .leading, spacing: 10) {
            question("Why?")
            FieldBox {
                TextField("Why it matters, in your words", text: $draft.why, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(p.text)
                    .lineLimit(2...5)
            }
        }
    }

    private var colorGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Color on the calendar")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(GoalColor.allCases) { c in
                    let on = draft.color == c
                    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                    Button { draft.color = c } label: {
                        shape.fill(p.color(c))
                            .frame(height: 44)
                            .overlay {
                                if on { Image(systemName: "checkmark").font(.system(size: 16, weight: .heavy)).foregroundStyle(p.onBand) }
                            }
                            .overlay(shape.strokeBorder(on ? p.text : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.label)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var symbolGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Symbol")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(GoalSymbols.all, id: \.self) { s in
                    let on = draft.symbol == s
                    Button { draft.symbol = s } label: {
                        Image(systemName: s)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(on ? p.onBand : p.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(on ? p.color(draft.color) : p.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(s)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    /// What the answers leave open, and what the week looks like with this goal in it.
    private var openBlock: some View {
        let g = current
        let others = store.goals.filter { $0.id != g.id }
        let open = openQuestions(g, goals: others, duels: store.duels)
        let budget = timeBudget(goals: others + [g], sleepNeed: store.settings.sleepNeedMinutes)
        return VStack(alignment: .leading, spacing: 10) {
            if g.kind == .time || g.kind == .work {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your week with this in it").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.secondary)
                        line("Sleep at your baseline", durationLabel(budget.sleep))
                        line("Work", durationLabel(budget.work))
                        line("Goals that take hours", durationLabel(budget.goals))
                        Divider1()
                        line("Left for everything else", budget.left >= 0 ? "\(durationLabel(budget.leftPerDay)) a day" : "\(durationLabel(-budget.left)) over", strong: true)
                    }
                }
            }
            if !open.isEmpty {
                SectionLabel(open.count == 1 ? "1 question still open" : "\(open.count) questions still open")
                VStack(spacing: 8) {
                    ForEach(open) { q in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(q.title).font(.system(size: 15, weight: .bold)).foregroundStyle(p.text)
                            Text(q.detail).font(.system(size: 13)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                    }
                }
                note("Open questions are not errors. The goal can be added as it is, and they stay listed on its page.")
            }
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let done = draft.achievedAt {
                Card {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Achieved \(mediumDay(done))").font(.system(size: 17, weight: .heavy)).foregroundStyle(p.text)
                        if let r = draft.reasonable {
                            Text("Your reasonable date was \(mediumDay(r)).").font(.system(size: 14)).foregroundStyle(p.muted)
                        }
                    }
                }
            } else if !draft.isArchived {
                PillButton(title: "Achieved", style: .primary, icon: "flag.checkered", full: true) {
                    let d = today()
                    store.achieve(draft.id, on: d)
                    draft.achievedAt = d
                    draft.archivedAt = addDays(1, to: d)
                }
            }
            if draft.isArchived {
                PillButton(title: "Bring it back", style: .secondary, icon: "arrow.uturn.backward", full: true) {
                    store.unarchive(draft.id)
                    draft.archivedAt = nil
                    draft.achievedAt = nil
                }
            } else {
                PillButton(title: "Retire this goal", style: .secondary, icon: "archivebox", full: true) {
                    let d = today()
                    store.archive(draft.id, on: d)
                    draft.archivedAt = d
                }
            }
            PillButton(title: "Delete", style: .danger, icon: "trash", full: true) { confirmDelete = true }
            note("Retiring keeps every day it colored. Deleting removes them.")
        }
        .padding(.top, 8)
    }

    // MARK: Actions

    /// A new goal takes the defaults of its kind when the kind is picked.
    private func pick(_ k: GoalKind) {
        let defaults = Set(GoalKind.allCases.map(\.symbol) + ["checkmark"])
        if defaults.contains(draft.symbol) { draft.symbol = k.symbol }
        draft.kind = k
        guard isNew else { return }
        switch k {
        case .time: kind = .times; times = 3
        case .adherence, .outcome: kind = .daily
        case .work: kind = .some; days = Weekday.workdays
        }
    }

    private func prepare() {
        guard !prepared else { return }
        switch mode {
        case .create:
            draft.color = store.nextColor
            draft.symbol = draft.kind.symbol
        case .edit(let id):
            if let g = store.goal(id) {
                draft = g
                switch g.schedule {
                case .daily: kind = .daily
                case .weekdays(let d): kind = .some; days = d
                case .timesPerWeek(let n): kind = .times; times = n
                }
                let w = g.workSetup
                work = w
                baseText = plainNumber(w.basePerMonth)
                unitValueText = plainNumber(w.unitValue)
                rateText = plainNumber(w.hourlyRate)
                incomeText = plainNumber(w.targetIncome)
                requiredMinutes = roundMinutes(Int((w.requiredHours * 60).rounded()))
                targetMinutes = roundMinutes(Int((w.targetHours * 60).rounded()))
            }
        }
        prepared = true
    }

    private func add() {
        store.put(current)
        dismiss()
    }
}

/// One of the three dates: a row of quick jumps from today, and a calendar to land on the day.
struct DateQuestion: View {
    @Environment(\.palette) private var p
    let title: String
    @Binding var day: String?

    private static let jumps: [(String, Int)] = [("1 mo", 1), ("3 mo", 3), ("6 mo", 6), ("1 yr", 12), ("2 yr", 24)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                Spacer(minLength: 8)
                if let day {
                    Text(distanceWords(day)).font(.system(size: 13, weight: .semibold)).foregroundStyle(p.muted)
                }
            }
            HStack(spacing: 6) {
                ForEach(Self.jumps, id: \.0) { j in
                    let target = addMonthsKeepingDay(j.1, to: today())
                    Chip(text: j.0, on: day == target) { day = target }
                }
            }
            if day != nil {
                HStack(spacing: 8) {
                    DatePicker("", selection: date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Spacer(minLength: 0)
                    Button { day = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(p.muted)
                            .frame(width: 34, height: 34)
                            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear date")
                }
            }
        }
    }

    private var date: Binding<Date> {
        Binding(get: { dayDate(day ?? today()) }, set: { day = dayString($0) })
    }
}
