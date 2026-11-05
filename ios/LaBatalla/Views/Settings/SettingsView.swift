import SwiftUI
import UniformTypeIdentifiers

/// Settings: how the app looks, how the calendar reads, your data, and where the name comes from.
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

    struct PendingImport { let snapshot: Snapshot }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle("Settings")
                block("Look") { lookRows }
                block("Calendar") { calendarRows }
                block("Data") { dataRows }
                block("About") { about }
                Text(AppVersion.current).font(.system(size: 12)).foregroundStyle(p.muted)
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(.bottom, 24)
        }
        .screen()
        .scrollDismissesKeyboard(.interactively)
        .onAppear { mantra = store.settings.mantra }
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
                    message = "Imported \(s.goals.count) goals and \(s.marks.count) marks."
                }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            if let s = pending?.snapshot { Text("\(s.goals.count) goals, \(s.marks.count) marks.") }
        }
        .confirmationDialog("Erase every goal and every mark on this phone?", isPresented: $confirmReset, titleVisibility: .visible) {
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

    @ViewBuilder private var dataRows: some View {
        HStack {
            rowTitle("Export", "One JSON file with every goal and mark")
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
            rowTitle("Start over", "Erase every goal and mark on this phone")
            Spacer()
            PillButton(title: "Erase", style: .danger, icon: "trash") { confirmReset = true }
        }
        Text("Everything stays on this phone. Nothing is sent anywhere.")
            .font(.system(size: 13)).foregroundStyle(p.muted)
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
            Text("This is the calendar of that battle. Each goal has a color. Each day you do it, the day gets its band. An uncolored day is not a failure, it is just a day without color. The next square is right there.")
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
