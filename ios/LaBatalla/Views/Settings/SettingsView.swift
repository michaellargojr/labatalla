import SwiftUI
import UniformTypeIdentifiers

/// Settings: the sleep numbers, the three nudges, money, the Oracle's key, how the app looks,
/// how the calendar reads, your data, and where the name comes from.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var exporting = false
    @State private var exportDoc: JSONFile?
    @State private var importing = false
    @State private var pending: PendingImport?
    @State private var confirmReset = false
    @State private var message: String?
    @State private var mantra = ""
    @State private var keyText = ""
    @State private var hasKey = false

    struct PendingImport { let snapshot: Snapshot }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle("Settings")
                Group {
                    block("Sleep") { sleepRows }
                    block("Check-ins") { reminderRows }.id("checkins")
                    block("Money") { moneyRows }
                    block("The Oracle") { oracleRows }.id("oracle")
                }
                Group {
                    block("Look") { lookRows }
                    block("Calendar") { calendarRows }
                    block("Data") { dataRows }
                    block("About") { about }
                }
                Text(AppVersion.current).font(.system(size: 12)).foregroundStyle(p.muted)
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(.bottom, 24)
        }
        #if DEBUG
        .onAppear {
            if let a = DebugLaunch.anchor {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { proxy.scrollTo(a, anchor: .top) }
            }
        }
        #endif
        }
        .screen()
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            mantra = store.settings.mantra
            hasKey = OracleKey.isSet
        }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json, defaultFilename: Snapshot.fileName()) { result in
            if case .success = result { message = "Saved." }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let s = try? Snapshot.decode(data) {
                pending = PendingImport(snapshot: s)
            } else {
                message = "That file could not be read."
            }
        }
        .confirmationDialog("Replace everything on this phone with the file?",
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible) {
            Button("Replace", role: .destructive) {
                if let s = pending?.snapshot {
                    store.restore(s)
                    mantra = s.settings.mantra
                    message = "Imported \(s.goals.count) goals, \(s.marks.count) answers and \(s.sleep.count) nights."
                }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            if let s = pending?.snapshot { Text("\(s.goals.count) goals, \(s.marks.count) answers, \(s.sleep.count) nights.") }
        }
        .confirmationDialog("Erase every goal, answer and night on this phone?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) {
                store.reset()
                mantra = store.settings.mantra
            }
            Button("Keep", role: .cancel) {}
        }
        .alert("La batalla", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: Blocks

    private func block<Content: View>(_ title: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title).padding(.horizontal, 16)
            Card { VStack(alignment: .leading, spacing: 16) { content() } }.padding(.horizontal, 16)
        }
    }

    private func rowTitle(_ text: String, _ detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text)
            if let detail { Text(detail).font(.system(size: 13)).foregroundStyle(p.muted) }
        }
    }

    @ViewBuilder private var lookRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            rowTitle("Appearance")
            HStack(spacing: 8) {
                ForEach(Appearance.allCases) { a in
                    Chip(text: a.label, on: store.settings.appearance == a) { store.update { $0.appearance = a } }
                }
            }
        }
        VStack(alignment: .leading, spacing: 8) {
            rowTitle("Blue", "The app's color")
            HStack(spacing: 8) {
                ForEach(BlueScheme.allCases) { s in
                    Chip(text: s.label, on: store.settings.scheme == s) { store.update { $0.scheme = s } }
                }
            }
        }
        VStack(alignment: .leading, spacing: 8) {
            rowTitle("App icon")
            HStack(spacing: 10) {
                ForEach(AppIconChoice.allCases) { c in
                    let on = store.settings.icon == c
                    Button { store.update { $0.icon = c } } label: {
                        VStack(spacing: 5) {
                            IconPreview(choice: c)
                                .frame(width: 52, height: 52)
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? p.text : .clear, lineWidth: 2))
                            Text(c.label).font(.system(size: 11, weight: on ? .bold : .semibold)).foregroundStyle(on ? p.text : p.muted)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.label)
                    .accessibilityHint(c.detail)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder private var calendarRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            rowTitle("Week starts on")
            HStack(spacing: 8) {
                ForEach(WeekStart.allCases) { w in
                    Chip(text: w.label, on: store.settings.weekStart == w) { store.update { $0.weekStart = w } }
                }
            }
        }
        HStack {
            rowTitle("Badges on days", "The bolt, star and crown in a day's corner")
            Spacer()
            Toggle("", isOn: Binding(get: { store.settings.showBadges }, set: { v in store.update { $0.showBadges = v } }))
                .labelsHidden()
                .tint(p.accent)
        }
        HStack {
            rowTitle("Haptics", "A small tap when you mark a goal or earn a badge")
            Spacer()
            Toggle("", isOn: Binding(get: { store.settings.haptics }, set: { v in store.update { $0.haptics = v } }))
                .labelsHidden()
                .tint(p.accent)
        }
        VStack(alignment: .leading, spacing: 8) {
            rowTitle("Mantra", "The line under the calendar's title")
            FieldBox {
                TextField(DEFAULT_MANTRA, text: $mantra)
                    .font(.system(size: 16))
                    .foregroundStyle(p.text)
                    .submitLabel(.done)
                    .onSubmit { saveMantra() }
                    .onChange(of: mantra) { _, _ in saveMantra() }
            }
        }
    }

    private func saveMantra() {
        let m = mantra.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.settings.mantra != m { store.update { $0.mantra = m } }
    }

    // MARK: Sleep

    /// The three numbers every night is read against. Changing them never rewrites a night
    /// already logged: each keeps the baseline and targets it was logged under.
    @ViewBuilder private var sleepRows: some View {
        DialRow(title: "Baseline", value: needBinding, values: DialValues.duration(upTo: 12, from: 4 * 60),
                major: DialValues.isHour, detail: "the sleep you need") { durationLabel($0) }
        DialRow(title: "Target bedtime", value: bedBinding, values: DialValues.clock(around: Self.bedCenter),
                major: DialValues.isHour) { clockLabel($0) }
        DialRow(title: "Target wake time", value: wakeBinding, values: DialValues.clock(around: Self.wakeCenter),
                major: DialValues.isHour) { clockLabel($0) }
        Text("\(durationLabel(sleepSpan(bed: store.settings.targetBedMinute, wake: store.settings.targetWakeMinute))) between bedtime and waking. Nights already logged keep the numbers they were logged under.")
            .font(.system(size: 13)).foregroundStyle(p.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static let bedCenter = 22 * 60 + 30
    private static let wakeCenter = 7 * 60

    private var needBinding: Binding<Int> {
        Binding(get: { store.settings.sleepNeedMinutes }, set: { v in store.update { $0.sleepNeedMinutes = v } })
    }
    private var bedBinding: Binding<Int> {
        Binding(get: { DialValues.onClock(store.settings.targetBedMinute, around: Self.bedCenter) },
                set: { v in store.update { $0.targetBedMinute = clampMinute(v) } })
    }
    private var wakeBinding: Binding<Int> {
        Binding(get: { DialValues.onClock(store.settings.targetWakeMinute, around: Self.wakeCenter) },
                set: { v in store.update { $0.targetWakeMinute = clampMinute(v) } })
    }

    // MARK: Check-ins

    @ViewBuilder private var reminderRows: some View {
        HStack {
            rowTitle("Morning sleep check-in", store.settings.morningCheckIn
                     ? "Every day at \(Reminder.timeText(Reminder.morningMinute(wake: store.settings.targetWakeMinute))), a little after your wake time"
                     : "A nudge a little after your wake time")
            Spacer()
            Toggle("", isOn: Binding(get: { store.settings.morningCheckIn }, set: { v in store.update { $0.morningCheckIn = v } }))
                .labelsHidden()
                .tint(p.accent)
        }
        HStack {
            rowTitle("Evening check-in", store.settings.reminderOn
                     ? "Every day at \(Reminder.timeText(store.settings.reminderMinute))"
                     : "A nudge to answer the day: yes or no, and the reason")
            Spacer()
            Toggle("", isOn: Binding(get: { store.settings.reminderOn }, set: { v in store.update { $0.reminderOn = v } }))
                .labelsHidden()
                .tint(p.accent)
        }
        if store.settings.reminderOn {
            HStack {
                rowTitle("Evening time")
                Spacer()
                DatePicker("", selection: reminderDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
        HStack {
            rowTitle("Start of the month", "On the 1st, a nudge to set the month's number for a job")
            Spacer()
            Toggle("", isOn: Binding(get: { store.settings.monthStartReminder }, set: { v in store.update { $0.monthStartReminder = v } }))
                .labelsHidden()
                .tint(p.accent)
        }
        Text("If the phone asks, allow notifications. These three are the only ones the app ever sends, and none of them scolds.")
            .font(.system(size: 13)).foregroundStyle(p.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Money

    @ViewBuilder private var moneyRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            rowTitle("Money is written in", "For work goals and the month's number")
            HStack(spacing: 8) {
                ForEach(["$", "\u{20B1}", "\u{20AC}", "\u{00A3}", "\u{00A5}"], id: \.self) { sign in
                    Chip(text: sign, on: store.settings.currency == sign) { store.update { $0.currency = sign } }
                }
            }
        }
    }

    // MARK: The Oracle

    @ViewBuilder private var oracleRows: some View {
        rowTitle(hasKey ? "API key saved" : "API key",
                 hasKey ? "Kept in this phone's keychain. It is never in the export file."
                        : "The Oracle is Claude. To ask it from inside the app, paste an Anthropic API key. It is kept in this phone's keychain.")
        if hasKey {
            PillButton(title: "Remove key", icon: "key.slash") {
                OracleKey.save("")
                hasKey = OracleKey.isSet
            }
        } else {
            FieldBox {
                SecureField("Paste the API key", text: $keyText)
                    .font(.system(size: 16)).foregroundStyle(p.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            PillButton(title: "Save key", style: .primary) {
                if OracleKey.save(keyText) {
                    keyText = ""
                    hasKey = OracleKey.isSet
                } else {
                    message = "The keychain did not take the key."
                }
            }
            .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        Divider1()
        VStack(alignment: .leading, spacing: 8) {
            rowTitle("Model", OracleModel.choice(store.settings.oracleModel).detail)
            HStack(spacing: 8) {
                ForEach(OracleModel.all) { m in
                    Chip(text: m.label, on: store.settings.oracleModel == m.id) { store.update { $0.oracleModel = m.id } }
                }
            }
        }
        Text("Asking the Oracle sends your brief (sleep, goals, hours, money, reasons) to Anthropic to get the answer. Nothing is sent until you ask. Open it from Insights.")
            .font(.system(size: 13)).foregroundStyle(p.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The reminder's minute of the day as a Date, for the time picker.
    private var reminderDate: Binding<Date> {
        Binding(get: {
            var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            c.hour = store.settings.reminderMinute / 60
            c.minute = store.settings.reminderMinute % 60
            return Calendar.current.date(from: c) ?? Date()
        }, set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            store.update { $0.reminderMinute = (c.hour ?? 20) * 60 + (c.minute ?? 0) }
        })
    }

    @ViewBuilder private var dataRows: some View {
        HStack {
            rowTitle("Export", "One JSON file with every goal, answer and night")
            Spacer()
            PillButton(title: "Save", icon: "square.and.arrow.up") {
                exportDoc = JSONFile(data: (try? store.snapshot().encoded()) ?? Data())
                exporting = true
            }
        }
        Divider1()
        HStack {
            rowTitle("Import", "Replace everything with an exported file")
            Spacer()
            PillButton(title: "Open", icon: "square.and.arrow.down") { importing = true }
        }
        Divider1()
        HStack {
            rowTitle("Start over", "Erase everything on this phone")
            Spacer()
            PillButton(title: "Erase", style: .danger, icon: "trash") { confirmReset = true }
        }
        Text("Everything stays on this phone. The one exception is the Oracle, and only when you ask it something.")
            .font(.system(size: 13)).foregroundStyle(p.muted)
            .fixedSize(horizontal: false, vertical: true)
        #if DEBUG
        Divider1()
        HStack {
            rowTitle("Sample data", "Debug builds only: replaces everything with a sample life, eight weeks deep")
            Spacer()
            PillButton(title: "Fill", icon: "paintpalette.fill") {
                store.loadSample()
                mantra = store.settings.mantra
                message = "Filled with sample goals, eight weeks of check-ins and sleep."
            }
        }
        #endif
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                BattleMark(color: p.onAccent)
                    .padding(10)
                    .frame(width: 56, height: 56)
                    .background(p.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("La batalla").font(.system(size: 20, weight: .heavy)).foregroundStyle(p.text)
                    Text("The battle").font(.system(size: 14)).foregroundStyle(p.muted)
                }
            }
            Text("Whenever I ask my grandfather how he is doing, he answers the same way: la batalla. The battle. Every day there is something that moves life forward in the long run, and every day there are reasons not to: tired, busy, too hot, out too long. The goals never get done that way.")
                .font(.system(size: 15)).foregroundStyle(p.secondary)
            Text("This is the map of that battle. Each goal has a color. Each day you put anything into it, the day gets its band. An uncolored day is not a failure, it is just a day without color. The reasons are kept, sleep is kept, and what they add up to shows in Insights: the battlefield from above.")
                .font(.system(size: 15)).foregroundStyle(p.secondary)
        }
    }
}

/// A small drawing of each home-screen icon, for the picker.
struct IconPreview: View {
    @Environment(\.palette) private var p
    let choice: AppIconChoice

    var body: some View {
        let royal = Color(hex: 0x1E5BE6), tech = Color(hex: 0x0A84FF)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack {
            switch choice {
            case .royal: shape.fill(royal); BattleMark(color: .white).padding(10)
            case .tech: shape.fill(tech); BattleMark(color: .white).padding(10)
            case .paper: shape.fill(.white); BattleMark(color: royal).padding(10)
            case .star: shape.fill(royal); StarShape().fill(.white).padding(12)
            }
        }
        .overlay(shape.strokeBorder(p.border.opacity(0.6), lineWidth: 0.5))
    }
}
