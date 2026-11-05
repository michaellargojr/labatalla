import SwiftUI

/// One day. Filled with the colors of the goals marked that day, side by side, so a day with
/// three goals done shows three bands; a day with none is a plain tile. Today has an outline.
/// The small bolt, star or crown in the corner is the day's badge.
struct DayTile: View {
    /// Month tiles show the date; week tiles show the weekday over it.
    enum Style {
        case number, weekday
        var height: CGFloat { self == .number ? 46 : 56 }
    }

    @Environment(\.palette) private var p
    let day: String
    let summary: DaySummary?
    let style: Style
    var showBadge: Bool = true
    let tap: () -> Void

    var body: some View {
        let t = today()
        let colors = summary?.colors ?? []
        let lit = !colors.isEmpty
        let isToday = day == t
        let future = day > t
        let fg: Color = lit ? p.onBand : isToday ? p.text : future ? p.muted.opacity(0.45) : p.muted
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        Button(action: tap) {
            ZStack {
                if lit {
                    HStack(spacing: 0) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                            Rectangle().fill(p.color(c))
                        }
                    }
                } else {
                    shape.fill(p.card)
                }
                label(lit: lit).foregroundStyle(fg)
                if showBadge, let b = summary?.topBadge {
                    Image(systemName: b.symbol)
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(fg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: style.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(isToday ? (lit ? p.onBand.opacity(0.35) : p.accent) : .clear, lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel(accessibility(lit: lit))
    }

    @ViewBuilder
    private func label(lit: Bool) -> some View {
        if style == .weekday {
            VStack(spacing: 2) {
                Text(weekdayLetters(day)).font(.system(size: 11, weight: .bold))
                Text(dayNumber(day)).font(.system(size: 15, weight: .heavy)).monospacedDigit()
            }
        } else {
            Text(dayNumber(day)).font(.system(size: 15, weight: lit ? .heavy : .semibold)).monospacedDigit()
        }
    }

    private func accessibility(lit: Bool) -> String {
        var words = longDayTitle(day)
        if let s = summary, lit {
            words += ", " + s.done.map(\.name).joined(separator: ", ")
            if let b = s.topBadge { words += ", " + b.title }
        }
        return words
    }
}
