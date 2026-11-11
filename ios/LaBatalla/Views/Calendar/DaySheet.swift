import SwiftUI

/// The slide-up for one day, and the daily check-in. Sleep first, then every goal asked of the
/// day: yes or no, how long when it counts time, and the reason. Two taps a goal on a normal
/// day. Past days can be answered too; nothing scolds for a day that went by.
struct DaySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let day: String
    /// The goal whose answer is open for its dial and its reason.
    @State private var open: String?
    @State private var sleeping = false
    @State private var planning: Goal?

    var body: some View {
        let s = store.summary(day)
        let t = today()
        let future = day > t
        let dueIds = Set(s.due.map(\.id))
        let extra = store.activeGoals.filter { $0.kind.hasCheckIn && $0.isActive(on: day) && !dueIds.contains($0.id) }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(s, future: future)
                if !s.badges.isEmpty { badgeRow(s) }
                if !future { sleepCard }
                if day == t {
                    ForEach(store.jobsNeedingPlan(today: t)) { g in planCard(g) }
                }
                if s.due.isEmpty && extra.isEmpty {
                    EmptyNote(store.activeGoals.isEmpty
                              ? "No goals yet. Set one in Goals and it will show up here."
                              : "Nothing was planned for this day.")
                } else {
                    if !s.due.isEmpty { list(future ? "Planned" : "The battle", s.due, future: future) }
                    if !extra.isEmpty { list(future ? "Also possible" : "Also open", extra, future: future) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: s.badges.count) { old, new in store.settings.haptics && new > old }
        .sensoryFeedback(.impact(weight: .light), trigger: s.done.count) { _, _ in store.settings.haptics }
        #if DEBUG
        .onAppear {
            // "-answer": answer the first goals of the day, so the open card can be looked at.
            guard DebugLaunch.has("-answer"), open == nil else { return }
            let due = store.summary(day).due
            if let g = due.first(where: { $0.kind == .time }) {
                store.answer(g.id, on: day, done: true)
                open = g.id
            }
            if let g = due.first(where: { $0.kind == .adherence }) {
                store.answer(g.id, on: day, done: false)
                store.toggleReason("Tired", for: g.id, on: day)
            }
        }
        #endif
        .sheet(isPresented: $sleeping) {
            SleepCheckInView(day: day)
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

    private func header(_ s: DaySummary, future: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(dayDate(day).formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 28, weight: .heavy)).tracking(-0.4).foregroundStyle(p.text)
                if let r = relativeDay(day) {
                    Text(r).font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent)
                        .padding(.horizontal, 8).frame(height: 24)
                        .background(p.accentSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
            Text(dayDate(day).formatted(.dateTime.month(.wide).day().year()))
                .font(.system(size: 15)).foregroundStyle(p.muted)
            if !future && !s.done.isEmpty {
                HStack(spacing: 6) {
                    ForEach(s.done) { g in
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(p.color(g.color)).frame(width: 14, height: 14)
                    }
                    Text(s.done.count == 1 ? "1 colored" : "\(s.done.count) colored")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(p.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private func badgeRow(_ s: DaySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Badge.allCases.reversed().filter { s.badges.contains($0) }) { b in BadgeChip(badge: b) }
            }
            if let top = s.topBadge {
                Text(top.detail).font(.system(size: 13)).foregroundStyle(p.muted)
            }
        }
    }

    /// The night that ended this morning: one button when it is not logged, one line when it is.
    private var sleepCard: some View {
        let log = store.sleepLog(on: day)
        let shape = RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
        return Button { sleeping = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(p.onAccent)
                    .frame(width: 40, height: 40)
                    .background(p.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(log == nil ? "Sleep check-in" : "Slept \(durationLabel(log?.sleptMinutes ?? 0))")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                    Text(sleepLine(log)).font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                if log == nil {
                    Text("Start").font(.system(size: 14, weight: .bold)).foregroundStyle(p.onAccent)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(p.accent, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted)
                }
            }
            .padding(12)
            .background(log == nil ? p.accentSoft : p.elevated, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private func sleepLine(_ log: SleepLog?) -> String {
        guard let l = log else { return "Last night, in a few seconds" }
        var parts = ["\(clockLabel(l.bedMinute)) to \(clockLabel(l.wakeMinute))", "quality \(l.quality)"]
        if let r = l.allReasons.first { parts.append(r) }
        return parts.joined(separator: " - ")
    }

    /// A job with no number for this month yet.
    private func planCard(_ g: Goal) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
        return Button { planning = g } label: {
            HStack(spacing: 12) {
                GoalIcon(goal: g, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Set the number for \(planWords(month: day, setOn: day))")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                        .multilineTextAlignment(.leading)
                    Text("\(g.name): what it should pay, and the hours a day").font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted)
            }
            .padding(12)
            .background(p.accentSoft, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private func list(_ title: String, _ goals: [Goal], future: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            VStack(spacing: 8) {
                ForEach(goals) { g in
                    CheckInCard(goal: g, day: day, enabled: !future, open: $open)
                }
            }
        }
    }
}

/// One goal's question for one day. Yes or No answers it; the answer then opens for its dial
/// (how long, when the goal counts time) and its reason. Tapping the chosen answer again takes
/// it back. A yes is filled with the goal's color. A no is just as plain as a yes: grey, no red.
struct CheckInCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let goal: Goal
    let day: String
    var enabled: Bool = true
    @Binding var open: String?

    var body: some View {
        let mark = store.mark(goal.id, on: day)
        let color = p.color(goal.color)
        let shape = RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
        let isOpen = open == goal.id && mark != nil
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                GoalIcon(goal: goal, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Text(subtitle(mark)).font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { if mark != nil { withAnimation(.snappy(duration: 0.22)) { open = isOpen ? nil : goal.id } } }
                answer("Yes", on: mark?.done == true, fill: color, text: p.onBand) { choose(true, mark) }
                answer("No", on: mark?.done == false, fill: p.border, text: p.text) { choose(false, mark) }
            }
            if isOpen, let m = mark {
                detail(m, color: color)
            }
        }
        .padding(12)
        .background(mark?.done == true ? color.opacity(p.isDark ? 0.16 : 0.12) : p.elevated, in: shape)
        .opacity(enabled ? 1 : 0.6)
        .disabled(!enabled)
        .accessibilityElement(children: .contain)
    }

    private func answer(_ title: String, on: Bool, fill: Color, text: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: on ? .heavy : .semibold))
                .foregroundStyle(on ? text : p.text)
                .frame(width: 52, height: 40)
                .background(on ? fill : p.card, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(on ? .clear : p.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.name): \(title)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func choose(_ done: Bool, _ mark: Mark?) {
        withAnimation(.snappy(duration: 0.22)) {
            if mark?.done == done {
                // The same answer again takes it back.
                store.clearAnswer(goal.id, on: day)
                if open == goal.id { open = nil }
            } else {
                store.answer(goal.id, on: day, done: done)
                open = goal.id
            }
        }
    }

    /// Under the name: the question until it is answered, then the answer in a line.
    private func subtitle(_ mark: Mark?) -> String {
        guard let m = mark else { return goal.kind.question }
        var parts: [String] = []
        if m.done {
            if goal.kind.countsTime && m.minutes > 0 { parts.append(durationLabel(m.minutes)) }
            if goal.kind == .work && goal.workSetup.paysPerResult && m.units > 0 {
                parts.append("\(m.units) \(goal.workSetup.unitName)\(m.units == 1 ? "" : "s")")
            }
            if parts.isEmpty { parts.append("Yes") }
        } else {
            parts.append("No")
        }
        if let r = m.allReasons.first { parts.append(r) } else { parts.append("reason?") }
        return parts.joined(separator: " - ")
    }

    @ViewBuilder
    private func detail(_ m: Mark, color: Color) -> some View {
        let set = ReasonSet.of(goal.kind, done: m.done)
        if m.done && goal.kind == .time {
            DialRow(title: "How long", value: minutes(m), values: DialValues.session, major: DialValues.isHour,
                    tint: color, detail: weekLine) { $0 <= 5 ? "A few min" : durationLabel($0) }
        }
        if m.done && goal.kind == .work {
            DialRow(title: "Hours worked", value: minutes(m), values: DialValues.workDay, major: DialValues.isHour,
                    tint: color) { durationLabel($0) }
            if goal.workSetup.paysPerResult {
                CountRow(title: "\(goal.workSetup.unitName.capitalizedFirst)s today",
                         value: Binding(get: { m.units }, set: { v in store.updateMark(goal.id, on: day) { $0.units = v } }),
                         detail: goal.workSetup.unitValue > 0 ? "\(money(goal.workSetup.unitValue, store.settings.currency)) each" : nil)
            }
        }
        ReasonPicker(choices: reasonChoices(set, used: store.reasonsUsed(set)),
                     picked: m.reasons, note: m.note ?? "", tint: m.done ? color : nil,
                     toggle: { store.toggleReason($0, for: goal.id, on: day) },
                     setNote: { store.setNote(goal.id, on: day, $0) })
    }

    private func minutes(_ m: Mark) -> Binding<Int> {
        Binding(get: { store.mark(goal.id, on: day)?.minutes ?? m.minutes },
                set: { v in store.updateMark(goal.id, on: day) { $0.minutes = v } })
    }

    /// "2h 15m of 6h this week", beside the dial.
    private var weekLine: String? {
        guard goal.weeklyMinutes > 0 else { return nil }
        let pr = store.progressOf(goal, today: day)
        return "\(durationLabel(pr.weekMinutes)) of \(durationLabel(pr.weekTarget)) this week"
    }
}
