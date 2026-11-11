import SwiftUI

/// In the order the bar shows them. Today is not a tab: the tile in the middle opens today's sheet.
enum AppTab: Hashable { case calendar, goals, insights, settings }

/// The floating bar: Calendar and Goals, the Today tile in the middle, then Insights and Settings.
/// The tile is the one thing in the bar with color, so it is the one that calls you.
struct BattleTabBar: View {
    @Environment(\.palette) private var p
    @Binding var tab: AppTab
    var onToday: () -> Void
    @Namespace private var lens

    static let height: CGFloat = 62

    var body: some View {
        HStack(spacing: 0) {
            item(.calendar, "Calendar", "calendar")
            item(.goals, "Goals", "flag.fill")
            TodayTile(action: onToday)
            item(.insights, "Insights", "binoculars.fill")
            item(.settings, "Settings", "slider.horizontal.3")
        }
        .padding(.horizontal, 4)
        .frame(height: Self.height)
        .modifier(FloatingGlass())
        // Same size and place as the system's bar: 360 wide on a 402 wide phone.
        .padding(.horizontal, 21)
        .sensoryFeedback(.selection, trigger: tab)
    }

    private func select(_ t: AppTab) {
        // Typing ends first, so a half-typed name is saved just like leaving its page.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard t != tab else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { tab = t }
    }

    private func item(_ t: AppTab, _ title: String, _ icon: String) -> some View {
        let on = tab == t
        return Button { select(t) } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 23, weight: .medium)).frame(height: 28)
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? p.accent : p.text)
            .frame(maxWidth: 64)
            .frame(height: 56)
            .background {
                if on {
                    Capsule().fill(p.isDark ? Color.black.opacity(0.55) : Color.black.opacity(0.06))
                        .matchedGeometryEffect(id: "lens", in: lens)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Liquid Glass where the system has it, frosted material before that.
private struct FloatingGlass: ViewModifier {
    @Environment(\.palette) private var p

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            content.background { Color.clear.glassEffect(.regular, in: Capsule()) }
        } else {
            frosted(content)
        }
        #else
        frosted(content)
        #endif
    }

    private func frosted(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(p.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(p.isDark ? 0.5 : 0.15), radius: 18, y: 8)
    }
}

/// The Today button: the star on a blue tile with Today under it, standing a little out of the bar.
struct TodayTile: View {
    @Environment(\.palette) private var p
    let action: () -> Void

    static let size: CGFloat = 54
    /// How far the tile stands above the bar's top edge.
    static let rise: CGFloat = 11
    static let gap: CGFloat = 2
    /// The width the bar keeps for it.
    static let slot: CGFloat = 84

    var body: some View {
        Color.clear
            .frame(width: Self.slot, height: BattleTabBar.height)
            .overlay(alignment: .top) {
                Button(action: action) {
                    VStack(spacing: Self.gap) {
                        StarShape().fill(p.onAccent)
                            .frame(width: Self.size * 0.52, height: Self.size * 0.52)
                            .frame(width: Self.size, height: Self.size)
                            .background(RoundedRectangle(cornerRadius: (Self.size * 0.3).rounded(), style: .continuous).fill(p.accent))
                        Text("Today").font(.system(size: 11, weight: .heavy)).foregroundStyle(p.accent).lineLimit(1)
                            .shadow(color: p.accent.opacity(0.55), radius: 3.5)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(y: -Self.rise)
                .accessibilityLabel("Today")
            }
    }
}

/// Month | Week, at the top right of the calendar.
struct CalendarModeSwitch: View {
    @Environment(\.palette) private var p
    @Binding var modeRaw: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarMode.allCases) { m in
                let on = modeRaw == m.rawValue
                Button { modeRaw = m.rawValue } label: {
                    Text(m.label)
                        .font(.system(size: 13, weight: on ? .bold : .semibold))
                        .foregroundStyle(on ? p.text : p.secondary)
                        .frame(height: 30)
                        .padding(.horizontal, 13)
                        .background(on ? p.border : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
