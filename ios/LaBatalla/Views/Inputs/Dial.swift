import SwiftUI

/// A dial laid flat: a strip of notches that slides sideways under a fixed needle and clicks
/// from one notch to the next. The value under the needle is the value. Used wherever a number
/// is only an estimate: times in 15-minute steps, hours slept, the length of a session.
struct RulerDial: View {
    @Environment(\.palette) private var p
    @Binding var value: Int
    /// Every notch, in order.
    let values: [Int]
    /// Notches drawn taller: the full hours on a clock.
    var major: (Int) -> Bool = { _ in false }
    var tint: Color? = nil

    /// The notch under the needle. It starts on the value, so the strip opens already turned to it.
    @State private var position: Int?
    /// False for the first moment, while the strip lays itself out: nothing it reports then is the hand.
    @State private var ready = false

    static let notch: CGFloat = 13
    static let height: CGFloat = 46

    init(value: Binding<Int>, values: [Int], major: @escaping (Int) -> Bool = { _ in false }, tint: Color? = nil) {
        self._value = value
        self.values = values
        self.major = major
        self.tint = tint
        self._position = State(initialValue: RulerDial.nearest(value.wrappedValue, in: values))
    }

    var body: some View {
        GeometryReader { geo in
            let side = max(0, (geo.size.width - Self.notch) / 2)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(values, id: \.self) { v in
                            tick(v).id(v)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, side, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $position, anchor: .center)
                .onAppear {
                    let start = Self.nearest(value, in: values)
                    position = start
                    proxy.scrollTo(start, anchor: .center)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        // Whatever the first layout did, the strip ends up on the value.
                        let now = Self.nearest(value, in: values)
                        if position != now {
                            position = now
                            proxy.scrollTo(now, anchor: .center)
                        }
                        ready = true
                    }
                }
                .onChange(of: value) { _, v in
                    // A change from outside (the step buttons, another dial) turns the strip to
                    // it at once: no animation, so no notch in between is ever read as the hand.
                    let n = Self.nearest(v, in: values)
                    guard position != n else { return }
                    position = n
                    proxy.scrollTo(n, anchor: .center)
                }
            }
        }
        .frame(height: Self.height)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(alignment: .center) {
            // The needle: fixed, in the app's blue unless a goal's color is given.
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(tint ?? p.accent)
                .frame(width: 3, height: Self.height - 8)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .onChange(of: position) { _, v in
            if ready, let v, v != value { value = v }
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    private func tick(_ v: Int) -> some View {
        let tall = major(v)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(tall ? p.secondary : p.border)
                .frame(width: 2, height: tall ? 22 : 12)
            Spacer(minLength: 0)
        }
        .frame(width: Self.notch, height: Self.height)
    }

    /// The notch closest to a value, for one that is not on the strip.
    static func nearest(_ v: Int, in values: [Int]) -> Int {
        values.min { abs($0 - v) < abs($1 - v) } ?? v
    }
}

/// A dial with its name, the value in large type, and a step button on each side for the last
/// notch or two.
struct DialRow: View {
    @Environment(\.palette) private var p
    let title: String
    @Binding var value: Int
    let values: [Int]
    var major: (Int) -> Bool = { _ in false }
    var tint: Color? = nil
    var detail: String? = nil
    let label: (Int) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                Spacer(minLength: 8)
                if let detail {
                    Text(detail).font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(1)
                }
                Text(label(value))
                    .font(.system(size: 22, weight: .heavy)).monospacedDigit().foregroundStyle(p.text)
                    .contentTransition(.numericText())
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                step("minus", -1)
                RulerDial(value: $value, values: values, major: major, tint: tint)
                step("plus", 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(label(value))
        .accessibilityAdjustableAction { direction in
            move(direction == .increment ? 1 : -1)
        }
    }

    private func step(_ icon: String, _ by: Int) -> some View {
        Button { move(by) } label: {
            Image(systemName: icon).font(.system(size: 15, weight: .bold))
                .foregroundStyle(p.text)
                .frame(width: 40, height: RulerDial.height)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func move(_ by: Int) {
        let i = values.firstIndex(of: value)
            ?? values.enumerated().min { abs($0.element - value) < abs($1.element - value) }?.offset ?? 0
        let next = min(max(i + by, 0), values.count - 1)
        if values.indices.contains(next) { value = values[next] }
    }
}

/// The notches the app's dials use.
enum DialValues {
    /// A whole day of clock times in 15-minute steps, centered on `center`. The numbers run past
    /// midnight in both directions; `clampMinute` turns one back into a minute of the day.
    static func clock(around center: Int) -> [Int] {
        let c = roundMinutes(center)
        return Array(stride(from: c - 12 * 60, to: c + 12 * 60, by: 15))
    }
    /// The value on a clock strip that stands for a minute of the day.
    static func onClock(_ minute: Int, around center: Int) -> Int {
        roundMinutes(center) + roundMinutes(clockOffset(minute, from: roundMinutes(center)))
    }
    /// Lengths of time in 15-minute steps up to `hours`.
    static func duration(upTo hours: Int, from start: Int = 0) -> [Int] {
        Array(stride(from: start, through: hours * 60, by: 15))
    }
    /// A session: "a few minutes" first, then 15-minute steps up to eight hours.
    static let session: [Int] = [5] + Array(stride(from: 15, through: 8 * 60, by: 15))
    /// Total hours for a goal: fine steps while small, coarse when large. 0 is "no end".
    static let totalHours: [Int] = [0, 5, 10, 15, 20, 25, 30, 40, 50, 60, 75, 100, 125, 150, 175, 200, 250, 300,
                                    400, 500, 600, 750, 1000, 1250, 1500, 2000, 3000, 5000, 10000]
    /// Hours of a work day in 15-minute steps, as minutes.
    static let workDay: [Int] = Array(stride(from: 15, through: 16 * 60, by: 15))

    static func isHour(_ m: Int) -> Bool { m % 60 == 0 }
}
