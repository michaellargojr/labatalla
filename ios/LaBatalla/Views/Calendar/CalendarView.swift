import SwiftUI

/// The main tab. Month: one month at a time, arrows or a sideways swipe to change it, with what
/// the month earned under the grid. Week: every week since the first mark, each a strip, with
/// This week at the bottom. A day you marked something on is filled with the colors of those
/// goals; today has an outline. Tap a day to see it and mark it.
struct CalendarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @AppStorage("calendarMode") private var modeRaw = CalendarMode.month.rawValue
    @State private var anchor = today()
    @State private var forward = true
    @State private var picked: DayPick?

    private var mode: CalendarMode { CalendarMode(rawValue: modeRaw) ?? .month }

    var body: some View {
        let start = store.settings.weekStart
        VStack(spacing: 0) {
            ScreenTitle("La batalla") { CalendarModeSwitch(modeRaw: $modeRaw) }
            if !store.settings.mantra.isEmpty {
                Text(store.settings.mantra)
                    .font(.system(size: 15, weight: .medium)).italic()
                    .foregroundStyle(p.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            switch mode {
            case .month: months(start)
            case .week: weeks(start)
            }
        }
        .screen()
        .sheet(item: $picked) { pick in
            DaySheet(day: pick.day)
                .presentationDetents([.fraction(0.78), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(p.card)
        }
    }

    // MARK: Month

    private func months(_ start: WeekStart) -> some View {
        let bounds = calendarBounds([store.firstDay], .month, start)
        let first = monthStart(anchor)
        let cells = monthGrid(first, start)
        let sums = store.summaries(cells.compactMap { $0 })
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                monthRow(first: first, bounds: bounds, start: start)
                // A ZStack, so the old and new month overlap while they slide.
                ZStack(alignment: .topLeading) {
                    MonthGridView(first: first, cells: cells, summaries: sums, start: start) { picked = DayPick(day: $0) }
                        .id(first)
                        .transition(.push(from: forward ? .trailing : .leading))
                }
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                    step(dx < 0 ? 1 : -1, bounds: bounds, start: start)
                })
                monthTotals(sums, first: first)
                legend
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .clipped()
        }
    }

    /// "November 2026" with the arrows.
    private func monthRow(first: String, bounds: ClosedRange<String>, start: WeekStart) -> some View {
        let t = monthTitle(first)
        return HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(t.month).foregroundStyle(p.text)
                Text(t.year).foregroundStyle(p.muted)
            }
            .font(.system(size: 22, weight: .heavy))
            .tracking(-0.3)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            arrow("chevron.left", label: "Earlier month", enabled: first > bounds.lowerBound) { step(-1, bounds: bounds, start: start) }
            arrow("chevron.right", label: "Later month", enabled: first < bounds.upperBound) { step(1, bounds: bounds, start: start) }
        }
    }

    private func arrow(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold))
                .foregroundStyle(p.text)
                .frame(width: 44, height: 44)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    private func step(_ by: Int, bounds: ClosedRange<String>, start: WeekStart) {
        let next = calendarStep(anchor, .month, start, by: by)
        guard bounds.contains(next) else { return }
        forward = by > 0
        withAnimation(.snappy(duration: 0.28)) { anchor = next }
    }

    /// What the month earned, in blue under the grid. Only days up to today count.
    private func monthTotals(_ sums: [String: DaySummary], first: String) -> some View {
        let t = today()
        let stats = monthStats(monthDays(first).filter { $0 <= t }.compactMap { sums[$0] })
        return Group {
            if !stats.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(coloredText(stats.colored))
                    if stats.victories > 0 { Text(victoriesText(stats.victories)) }
                    if stats.longTerm > 0 { Text(longTermText(stats.longTerm)) }
                    if stats.shortTerm > 0 { Text(shortTermText(stats.shortTerm)) }
                }
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(p.accent)
                .padding(.top, 2)
            }
        }
    }

    /// Which color is which goal.
    private var legend: some View {
        let goals = store.activeGoals
        return Group {
            if !goals.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(goals) { g in
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(p.color(g.color)).frame(width: 12, height: 12)
                            Text(g.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(p.secondary).lineLimit(1)
                        }
                    }
                }
                .padding(.top, 6)
            } else {
                Text("No goals yet. Set one in Goals, or tap Today.")
                    .font(.system(size: 14)).foregroundStyle(p.muted).padding(.top, 6)
            }
        }
    }

    // MARK: Week

    /// Every week from the first mark's to this one, oldest on top; opens at This week.
    private func weeks(_ start: WeekStart) -> some View {
        let t = today()
        let starts = weekStarts(from: store.firstDay, to: t, start)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(starts, id: \.self) { s in
                    WeekRow(weekStart: s, start: start, today: t) { picked = DayPick(day: $0) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .defaultScrollAnchor(.bottom)
    }
}

/// One week's strip, worked out only when it scrolls into view.
struct WeekRow: View {
    @Environment(AppStore.self) private var store
    let weekStart: String
    let start: WeekStart
    let today: String
    let tap: (String) -> Void

    var body: some View {
        let days = weekDays(weekStart, start)
        let sums = store.summaries(days)
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(weekLabel(weekStart, start, today: today))
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { d in
                    DayTile(day: d, summary: sums[d], style: .weekday, showBadge: store.settings.showBadges) { tap(d) }
                }
            }
        }
    }
}

/// The month's grid of tiles with the weekday letters over it.
struct MonthGridView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let first: String
    let cells: [String?]
    let summaries: [String: DaySummary]
    let start: WeekStart
    let tap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(weekDays(first, start), id: \.self) { d in
                    Text(weekdayLetters(d))
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(p.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(spacing: 6) {
                ForEach(0..<(cells.count / 7), id: \.self) { r in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { c in
                            if let d = cells[r * 7 + c] {
                                DayTile(day: d, summary: summaries[d], style: .number, showBadge: store.settings.showBadges) { tap(d) }
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: DayTile.Style.number.height)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DayPick: Identifiable {
    let day: String
    var id: String { day }
}
