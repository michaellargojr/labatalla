import SwiftUI

/// The trees and the forest for one goal: this week, this month and in all, each a bar against
/// what the plan asked. Hours for goals that count time, days for rules. A bar only ever shows
/// what is in; it has no color for behind.
struct GoalMeters: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let goal: Goal
    /// The day the week and the month are read from.
    var asOf: String = today()
    var showWeek: Bool = true
    var showTotal: Bool = true

    var body: some View {
        let pr = store.progressOf(goal, today: asOf)
        let color = p.color(goal.color)
        let month = monthName(asOf)
        VStack(alignment: .leading, spacing: 9) {
            if goal.kind.countsTime {
                let perDay = minutesPerDay
                let weekTarget = goal.kind == .work ? goal.schedule.daysPerWeek * perDay : pr.weekTarget
                let monthTarget = goal.kind == .work ? pr.monthDaysTarget * perDay : pr.monthTarget
                if showWeek {
                    MeterRow(title: "This week", value: amount(pr.weekMinutes, weekTarget), share: share(pr.weekMinutes, weekTarget), color: color)
                }
                MeterRow(title: month, value: amount(pr.monthMinutes, monthTarget), share: share(pr.monthMinutes, monthTarget), color: color)
                if showTotal && goal.kind == .time {
                    MeterRow(title: "In all", value: total(pr.totalMinutes, pr.totalTarget), share: share(pr.totalMinutes, pr.totalTarget), color: color)
                }
            } else {
                if showWeek {
                    MeterRow(title: "This week", value: days(pr.weekDays, pr.weekDaysTarget), share: share(pr.weekDays, pr.weekDaysTarget), color: color)
                }
                MeterRow(title: month, value: days(pr.monthDays, pr.monthDaysTarget), share: share(pr.monthDays, pr.monthDaysTarget), color: color)
                if showTotal {
                    HStack(alignment: .firstTextBaseline) {
                        Text("In all").font(.system(size: 13, weight: .semibold)).foregroundStyle(p.secondary)
                        Spacer(minLength: 8)
                        Text(pr.totalDays == 1 ? "1 day" : "\(pr.totalDays) days")
                            .font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundStyle(p.text)
                    }
                }
            }
        }
    }

    /// A work day's planned minutes: this month's number if there is one, else what the job expects.
    private var minutesPerDay: Int {
        guard goal.kind == .work else { return goal.sessionMinutes }
        let hours = store.plan(for: goal.id, month: asOf)?.hoursPerDay ?? goal.workSetup.requiredHours
        return Int((hours * 60).rounded())
    }

    private func amount(_ got: Int, _ target: Int) -> String {
        target > 0 ? "\(durationLabel(got)) of \(durationLabel(target))" : durationLabel(got)
    }

    private func total(_ got: Int, _ target: Int) -> String {
        let hours = hoursLabel(Double(got) / 60)
        return target > 0 ? "\(hours) of \(hoursLabel(Double(target) / 60))" : hours
    }

    private func days(_ got: Int, _ target: Int) -> String {
        target > 0 ? "\(got) of \(target) days" : (got == 1 ? "1 day" : "\(got) days")
    }

    private func share(_ got: Int, _ target: Int) -> Double {
        target > 0 ? Double(got) / Double(target) : (got > 0 ? 1 : 0)
    }
}

/// Twelve columns of seven squares for one goal: a week per column, oldest on the left. A day
/// with a yes has the goal's color.
struct WeekStrip: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let goal: Goal
    var today: String = LaBatalla.today()

    var body: some View {
        let start = store.settings.weekStart
        let done = store.done
        let weeks = weekStarts(from: addDays(-7 * 11, to: today), to: today, start)
        let color = p.color(goal.color)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                ForEach(weeks, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(weekDays(w, start), id: \.self) { d in
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(done[d]?.contains(goal.id) == true ? color : (d > today ? Color.clear : p.elevated))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            Text("Last 12 weeks").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(p.muted)
        }
        .accessibilityHidden(true)
    }
}

/// Said, chose, did: three readings of how much each goal matters, side by side.
struct StandingsTable: View {
    @Environment(\.palette) private var p
    let rows: [Standing]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                head("Said", 44)
                head("Chose", 56)
                head("Did", 52)
            }
            ForEach(rows) { r in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(p.color(r.color)).frame(width: 12, height: 12)
                    Text(r.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.text).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    cell(r.said > 0 ? "\(r.said)" : "-", 44)
                    cell(r.choseRank.map { "#\($0)" } ?? "-", 56)
                    cell(r.did.map { percentLabel($0) } ?? "-", 52)
                }
            }
        }
    }

    private func head(_ text: String, _ width: CGFloat) -> some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(p.muted)
            .frame(width: width, alignment: .trailing)
    }

    private func cell(_ text: String, _ width: CGFloat) -> some View {
        Text(text).font(.system(size: 15, weight: .bold)).monospacedDigit().foregroundStyle(p.text)
            .frame(width: width, alignment: .trailing)
    }
}

/// The last nights as bars, with a line at the baseline. A night not logged is a small stub.
struct SleepChart: View {
    @Environment(\.palette) private var p
    /// Oldest first.
    let days: [String]
    let logs: [String: SleepLog]
    let need: Int

    var body: some View {
        let longest = logs.values.map(\.sleptMinutes).max() ?? 0
        let top = CGFloat(max(need + 60, longest + 30, 60))
        VStack(spacing: 6) {
            GeometryReader { geo in
                let h = geo.size.height
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(days, id: \.self) { d in
                            bar(logs[d], height: h, top: top)
                        }
                    }
                    Rectangle().fill(p.text.opacity(0.6))
                        .frame(height: 1.5)
                        .offset(y: -h * CGFloat(need) / top)
                }
                .frame(width: geo.size.width, height: h, alignment: .bottomLeading)
            }
            .frame(height: 104)
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { d in
                    Text(Weekday.of(d).letter).font(.system(size: 10, weight: .bold)).foregroundStyle(p.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep over the last \(days.count) nights against a baseline of \(durationLabel(need))")
    }

    private func bar(_ log: SleepLog?, height h: CGFloat, top: CGFloat) -> some View {
        let tall: CGFloat = log.map { max(4, h * CGFloat($0.sleptMinutes) / top) } ?? 4
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(log == nil ? p.elevated : p.accent)
            .frame(height: tall)
            .frame(maxWidth: .infinity)
    }
}
