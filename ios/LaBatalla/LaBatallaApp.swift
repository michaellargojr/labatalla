import SwiftUI

@main
struct LaBatallaApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onAppear { if !store.loaded { store.load() } }
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .calendar
    @State private var visited: Set<AppTab> = [.calendar]
    @State private var showToday = false
    @State private var keyboardUp = false
    /// The phone's own bottom safe area: the home indicator's, or 0 with a Home button.
    @State private var deviceBottom: CGFloat = 0

    private var isDark: Bool {
        switch store.settings.appearance {
        case .dark: return true
        case .light: return false
        case .system: return systemScheme == .dark
        }
    }

    var body: some View {
        let p = Palette.make(scheme: store.settings.scheme, dark: isDark)
        // Each tab is built the first time it's opened and then kept, so it stays where you left it.
        ZStack {
            page(.calendar) { CalendarView() }
            page(.goals) { GoalsView() }
            page(.stats) { StatsView() }
            page(.settings) { SettingsView() }
        }
        .background(p.bg.ignoresSafeArea())
        // Every page, pushed ones included, keeps room under the bar for its last row.
        .background(TabBarRoomSetter(deviceBottom: $deviceBottom))
        .overlay(alignment: .bottom) {
            // Out of the way while typing, like the system bar.
            if !keyboardUp {
                BattleTabBar(tab: $tab, onToday: { showToday = true })
                    .padding(.bottom, TabBarRoom.lift(device: deviceBottom))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .sheet(isPresented: $showToday) {
            DaySheet(day: today())
                .presentationDetents([.fraction(0.78), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(p.card)
        }
        .onChange(of: tab, initial: true) { _, t in visited.insert(t) }
        .onChange(of: scenePhase) { _, phase in if phase == .background { store.saveNow() } }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .tint(p.accent)
        .environment(\.palette, p)
        .onChange(of: store.settings.icon) { _, i in AppIcon.match(i) }
        // The daily reminder follows the settings: time, on or off, and the mantra it carries.
        .onChange(of: store.loaded, initial: true) { _, loaded in if loaded { Reminder.sync(store.settings) } }
        .onChange(of: store.settings) { _, s in Reminder.sync(s) }
        .preferredColorScheme(store.settings.appearance == .system ? nil : (isDark ? .dark : .light))
    }

    @ViewBuilder
    private func page<Content: View>(_ t: AppTab, @ViewBuilder _ content: () -> Content) -> some View {
        if visited.contains(t) || tab == t {
            content()
                .opacity(tab == t ? 1 : 0)
                .allowsHitTesting(tab == t)
                .accessibilityHidden(tab != t)
        }
    }
}
