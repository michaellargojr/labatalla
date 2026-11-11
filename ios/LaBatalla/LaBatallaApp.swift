import SwiftUI

@main
struct LaBatallaApp: App {
    /// Read before the first frame, so the first thing drawn is already the person's own data.
    @State private var store: AppStore = {
        let s = AppStore()
        s.load()
        #if DEBUG
        s.applyLaunchArguments()
        #endif
        return s
    }()

    init() {
        // Before anything is on screen, so a tapped notification that starts the app is heard.
        NotificationRouter.shared.listen()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(NotificationRouter.shared.box)
                .onAppear { if !store.loaded { store.load() } }
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(RouteBox.self) private var routes
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .calendar
    @State private var visited: Set<AppTab> = [.calendar]
    @State private var showToday = false
    @State private var showSleep = false
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
            page(.insights) { InsightsView() }
            page(.settings) { SettingsView() }
        }
        .background(p.bg.ignoresSafeArea())
        // A page that scrolls goes under the clock; this keeps the clock on plain background.
        .overlay(alignment: .top) {
            GeometryReader { geo in
                p.bg.frame(height: geo.safeAreaInsets.top).offset(y: -geo.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
        }
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
        .sheet(isPresented: $showSleep) {
            SleepCheckInView(day: today())
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(p.card)
        }
        // The first run: the sleep baseline and the schedule, before anything else.
        .fullScreenCover(isPresented: Binding(get: { store.loaded && !store.settings.onboarded }, set: { _ in })) {
            OnboardingView()
        }
        // A tapped notification opens the check-in it was about.
        .onChange(of: routes.route, initial: true) { _, route in
            guard let route else { return }
            routes.route = nil
            guard store.settings.onboarded else { return }
            tab = .calendar
            if route == .sleep && store.sleepLog(on: today()) == nil { showSleep = true } else { showToday = true }
        }
        .onChange(of: tab, initial: true) { _, t in visited.insert(t) }
        #if DEBUG
        .onAppear {
            if let t = DebugLaunch.tab { tab = t }
            if DebugLaunch.screen == "today" { showToday = true }
            if DebugLaunch.screen == "sleep" { showSleep = true }
        }
        #endif
        .onChange(of: scenePhase) { _, phase in if phase == .background { store.saveNow() } }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .tint(p.accent)
        .environment(\.palette, p)
        .onChange(of: store.settings.icon) { _, i in AppIcon.match(i) }
        // The reminders follow the settings: which are on, their times, and the mantra one carries.
        .onChange(of: store.loaded, initial: true) { _, loaded in if loaded { syncReminders() } }
        .onChange(of: store.settings) { _, _ in syncReminders() }
        .onChange(of: store.workGoals.isEmpty) { _, _ in syncReminders() }
        .preferredColorScheme(store.settings.appearance == .system ? nil : (isDark ? .dark : .light))
    }

    private func syncReminders() {
        // Nothing is asked of the phone until the first-run questions are answered.
        guard store.loaded, store.settings.onboarded else { return }
        Reminder.sync(store.settings, hasWork: !store.workGoals.isEmpty)
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
