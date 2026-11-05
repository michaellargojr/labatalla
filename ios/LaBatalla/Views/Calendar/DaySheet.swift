import SwiftUI

/// The slide-up for one day: its badges, then every goal asked of it with a check to mark it,
/// then anything else that was open. Past days can be marked too; nothing scolds for a day that
/// went by. A future day only shows what is planned.
struct DaySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let day: String

    var body: some View {
        let s = store.summary(day)
        let t = today()
        let future = day > t
        let dueIds = Set(s.due.map(\.id))
        let extra = store.activeGoals.filter { $0.isActive(on: day) && !dueIds.contains($0.id) }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(s, future: future)
                if !s.badges.isEmpty { badgeRow(s) }
                if s.due.isEmpty && extra.isEmpty {
                    EmptyNote(store.activeGoals.isEmpty
                              ? "No goals yet. Set one in Goals and it will show up here."
                              : "Nothing was planned for this day.")
                } else {
                    if !s.due.isEmpty { list(future ? "Planned" : "The battle", s.due, s, future: future) }
                    if !extra.isEmpty { list(future ? "Also possible" : "Also open", extra, s, future: future) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .sensoryFeedback(.success, trigger: s.badges.count) { old, new in store.settings.haptics && new > old }
        .sensoryFeedback(.impact(weight: .light), trigger: s.done.count) { _, _ in store.settings.haptics }
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
                    Text(s.done.count == 1 ? "1 marked" : "\(s.done.count) marked")
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

    private func list(_ title: String, _ goals: [Goal], _ s: DaySummary, future: Bool) -> some View {
        let doneIds = Set(s.done.map(\.id))
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            VStack(spacing: 8) {
                ForEach(goals) { g in
                    GoalCheckRow(goal: g, on: doneIds.contains(g.id), enabled: !future) { store.toggle(g.id, on: day) }
                }
            }
        }
    }
}

/// A goal with its check, for a day. The whole row is the button.
struct GoalCheckRow: View {
    @Environment(\.palette) private var p
    let goal: Goal
    let on: Bool
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
        Button(action: action) {
            HStack(spacing: 12) {
                GoalIcon(goal: goal, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        HorizonTag(horizon: goal.horizon)
                        Text(goal.schedule.label).font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                RectCheck(on: on, color: p.color(goal.color))
            }
            .padding(12)
            .background(on ? p.color(goal.color).opacity(p.isDark ? 0.16 : 0.12) : p.elevated, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
        .accessibilityLabel(goal.name)
        .accessibilityValue(on ? "Done" : "Not yet")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
