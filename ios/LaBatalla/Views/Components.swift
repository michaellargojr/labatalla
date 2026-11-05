import SwiftUI

// Shared building blocks. Everything is a rounded rectangle; color means a goal, blue means the app.

struct Card<Content: View>: View {
    @Environment(\.palette) private var p
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// A text field's box, on the elevated grey.
struct FieldBox<Content: View>: View {
    @Environment(\.palette) private var p
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }
}

/// "THIS WEEK": the small bold caption over a block.
struct SectionLabel: View {
    @Environment(\.palette) private var p
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(p.muted)
    }
}

extension ScreenTitle where Trailing == EmptyView {
    init(_ title: String) { self.init(title) { EmptyView() } }
}

/// The big title at the top of a tab, with room on the right for a button.
struct ScreenTitle<Trailing: View>: View {
    @Environment(\.palette) private var p
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }
    var body: some View {
        HStack(alignment: .center) {
            Text(title).font(.system(size: 34, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

enum PillStyle { case primary, secondary, danger }

struct PillButton: View {
    @Environment(\.palette) private var p
    let title: String
    var style: PillStyle = .secondary
    var icon: String? = nil
    var full: Bool = false
    var height: CGFloat = 44
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title).font(.system(size: height > 50 ? 18 : 16, weight: style == .primary ? .bold : .semibold))
            }
            .frame(maxWidth: full ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, 18)
            .foregroundStyle(fg)
            .background(bg, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    private var bg: Color {
        switch style {
        case .primary: return p.accent
        case .secondary: return p.elevated
        case .danger: return p.dangerSoft
        }
    }
    private var fg: Color {
        switch style {
        case .primary: return p.onAccent
        case .secondary: return p.text
        case .danger: return p.danger
        }
    }
}

/// A choice in a row of choices. Blue when picked.
struct Chip: View {
    @Environment(\.palette) private var p
    let text: String
    var on: Bool = false
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(text).font(.system(size: 14, weight: on ? .bold : .semibold))
            }
            .foregroundStyle(on ? p.onAccent : p.text)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A square check. Filled with the goal's color when on.
struct RectCheck: View {
    @Environment(\.palette) private var p
    let on: Bool
    var color: Color? = nil
    var size: CGFloat = 30
    var body: some View {
        let fill = color ?? p.accent
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        ZStack {
            shape.fill(on ? fill : p.elevated)
            shape.strokeBorder(on ? fill : p.border, lineWidth: 1.5)
            if on {
                Image(systemName: "checkmark").font(.system(size: size * 0.5, weight: .heavy)).foregroundStyle(p.onBand)
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy(duration: 0.2), value: on)
    }
}

/// A goal's symbol on a square of its color.
struct GoalIcon: View {
    @Environment(\.palette) private var p
    let goal: Goal
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: goal.symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(p.onBand)
            .frame(width: size, height: size)
            .background(p.color(goal.color), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// "6 years" with its symbol. Long term is blue, since it is the one the app is about.
struct HorizonTag: View {
    @Environment(\.palette) private var p
    let horizon: Horizon
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: horizon.symbol).font(.system(size: 10, weight: .bold))
            Text(horizon.label).font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(horizon == .sixYears ? p.accent : p.secondary)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(horizon == .sixYears ? p.accentSoft : p.elevated, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// A badge a day earned, as a small blue pill.
struct BadgeChip: View {
    @Environment(\.palette) private var p
    let badge: Badge
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: badge.symbol).font(.system(size: 12, weight: .bold))
            Text(badge.title).font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(p.onAccent)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(p.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// A number with a small word under it, on the elevated grey.
struct StatTile: View {
    @Environment(\.palette) private var p
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).monospacedDigit().foregroundStyle(p.text).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(p.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct Divider1: View {
    @Environment(\.palette) private var p
    var body: some View { Rectangle().fill(p.line).frame(height: 1) }
}

/// A quiet note where a list would be: never a scolding.
struct EmptyNote: View {
    @Environment(\.palette) private var p
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(p.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// The page background, under everything on a tab.
struct ScreenBackground: ViewModifier {
    @Environment(\.palette) private var p
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(p.bg.ignoresSafeArea())
    }
}

extension View {
    func screen() -> some View { modifier(ScreenBackground()) }
}
