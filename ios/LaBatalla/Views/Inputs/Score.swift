import SwiftUI

/// One to ten, as ten squares in a row: tap one and every square up to it fills. One tap, no typing.
struct ScoreRow: View {
    @Environment(\.palette) private var p
    @Binding var value: Int
    var tint: Color? = nil
    var low: String? = nil
    var high: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                ForEach(1...10, id: \.self) { n in
                    let on = n <= value
                    Button { value = n } label: {
                        Text("\(n)")
                            .font(.system(size: 15, weight: n == value ? .heavy : .semibold)).monospacedDigit()
                            .foregroundStyle(on ? (tint == nil ? p.onAccent : p.onBand) : p.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background((on ? (tint ?? p.accent) : p.elevated).opacity(on && n != value ? 0.55 : 1),
                                        in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(n)")
                    .accessibilityAddTraits(n == value ? .isSelected : [])
                }
            }
            if low != nil || high != nil {
                HStack {
                    Text(low ?? "")
                    Spacer()
                    Text(high ?? "")
                }
                .font(.system(size: 12)).foregroundStyle(p.muted)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

/// A number picked with minus and plus, for small counts: results in a day, times a week.
struct CountRow: View {
    @Environment(\.palette) private var p
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...99
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                if let detail { Text(detail).font(.system(size: 13)).foregroundStyle(p.muted) }
            }
            Spacer(minLength: 8)
            button("minus") { value = max(range.lowerBound, value - 1) }
            Text("\(value)")
                .font(.system(size: 22, weight: .heavy)).monospacedDigit().foregroundStyle(p.text)
                .frame(minWidth: 34)
                .contentTransition(.numericText())
            button("plus") { value = min(range.upperBound, value + 1) }
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    private func button(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold))
                .foregroundStyle(p.text)
                .frame(width: 44, height: 40)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A thin bar: how much of something is in, against what was asked. It fills in the goal's
/// color and simply stops where the number stops; there is no color for "behind".
struct MeterBar: View {
    @Environment(\.palette) private var p
    let share: Double
    var color: Color? = nil
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * CGFloat(min(max(share, 0), 1))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous).fill(p.elevated)
                RoundedRectangle(cornerRadius: height / 2, style: .continuous).fill(color ?? p.accent)
                    .frame(width: share > 0 ? max(w, height) : 0)
            }
        }
        .frame(height: height)
    }
}

/// "This week   2h 15m of 6h" over its bar.
struct MeterRow: View {
    @Environment(\.palette) private var p
    let title: String
    let value: String
    let share: Double
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(p.secondary)
                Spacer(minLength: 8)
                Text(value).font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundStyle(p.text)
            }
            MeterBar(share: share, color: color)
        }
        .accessibilityElement(children: .combine)
    }
}
