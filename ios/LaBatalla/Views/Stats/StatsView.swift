import SwiftUI

/// Progress: what this month has earned, then each goal with its run, its best, its total and
/// its last twelve weeks as a strip of small squares. Numbers only for what happened.
struct StatsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p

    var body: some View {
        let t = today()
        let start = store.settings.weekStart
        let goals = store.activeGoals
        let done = store.done
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle("Progress")
                if goals.isEmpty {
                    EmptyNote("Progress shows up here once there is a goal and a day marked.").padding(.horizontal, 16)
                } else {
                    monthCard(today: t)
                    ForEach(goals) { g in goalCard(g, done: done, start: start, today: t) }
                }
            }
            .padding(.bottom, 24)
        }
        .screen()
    }

    private func monthCard(today t: String) -> some View {
        let days = monthDays(t).filter { $0 <= t }
        let sums = store.summaries(days)
        let stats = monthStats(days.compactMap { sums[$0] })
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(monthTitle(t).month).font(.system(size: 20, weight: .heavy)).foregroundStyle(p.text)
                    Text("so far").font(.system(size: 14)).foregroundStyle(p.muted)
                }
                HStack(spacing: 8) {
                    StatTile(value: "\(stats.colored)", label: "DAYS COLORED")
                    StatTile(value: "\(stats.victories)", label: "BATTLES WON")
                }
                HStack(spacing: 8) {
                    StatTile(value: "\(stats.longTerm)", label: "LONG-TERM DAYS")
                    StatTile(value: "\(stats.shortTerm)", label: "SHORT-TERM DAYS")
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func goalCard(_ g: Goal, done: DoneByDay, start: WeekStart, today t: String) -> some View {
        let s = streak(g, done: done, weekStart: start, today: t)
        let weeks = weekStarts(from: addDays(-7 * 11, to: t), to: t, start)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    GoalIcon(goal: g, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(g.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text).lineLimit(2)
                        HStack(spacing: 6) {
                            HorizonTag(horizon: g.horizon)
                            Text(g.schedule.label).font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    StatTile(value: "\(s.current)", label: s.current == 1 ? s.unit.uppercased() + " RUN" : s.unit.uppercased() + "S RUN")
                    StatTile(value: "\(s.best)", label: "BEST")
                    StatTile(value: "\(totalMarks(g, done: done))", label: "DAYS")
                }
                strip(g, weeks: weeks, done: done, start: start, today: t)
                if !g.why.isEmpty {
                    Text(g.why).font(.system(size: 14)).italic().foregroundStyle(p.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    /// Twelve columns of seven squares: a week per column, oldest on the left.
    private func strip(_ g: Goal, weeks: [String], done: DoneByDay, start: WeekStart, today t: String) -> some View {
        let color = p.color(g.color)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                ForEach(weeks, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(weekDays(w, start), id: \.self) { d in
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(done[d]?.contains(g.id) == true ? color : (d > t ? Color.clear : p.elevated))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            Text("Last 12 weeks").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(p.muted)
        }
    }
}
