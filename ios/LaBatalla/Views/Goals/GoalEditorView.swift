import SwiftUI

/// A goal's page: name, which horizon, color, symbol, when, and why. A new goal is added with
/// Add; an existing one saves every change as it is made, so Back is always safe.
struct GoalEditorView: View {
    enum Mode: Hashable { case create, edit(String) }
    enum ScheduleKind: String, CaseIterable, Identifiable {
        case daily = "Every day", some = "Some days", times = "Times a week"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    @State private var draft = Goal(name: "")
    @State private var kind: ScheduleKind = .daily
    @State private var days: Set<Weekday> = Weekday.workdays
    @State private var times = 3
    @State private var confirmDelete = false
    @State private var prepared = false

    private var isNew: Bool {
        if case .create = mode { return true }
        return false
    }
    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var schedule: Schedule {
        switch kind {
        case .daily: return .daily
        case .some: return .weekdays(days)
        case .times: return .timesPerWeek(times)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                nameField
                horizonPicker
                colorGrid
                symbolGrid
                schedulePicker
                whyField
                if !isNew { dangerZone }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .screen()
        .navigationTitle(isNew ? "New goal" : "Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(p.bg, for: .navigationBar)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }.fontWeight(.bold).disabled(trimmedName.isEmpty)
                }
            }
        }
        .onAppear(perform: prepare)
        .onChange(of: schedule) { _, s in draft.schedule = s }
        .onChange(of: draft) { _, g in
            // An existing goal saves as you go. A blank name is never saved.
            guard !isNew, prepared, !g.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            store.put(g)
        }
        .confirmationDialog("Delete this goal and every day it colored?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete goal", role: .destructive) {
                store.delete(draft.id)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        }
    }

    // MARK: Blocks

    private var nameField: some View {
        FieldBox {
            TextField("What are you building?", text: $draft.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(p.text)
                .submitLabel(.done)
        }
    }

    private var horizonPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Matters in")
            HStack(spacing: 10) {
                ForEach(Horizon.allCases) { h in
                    let on = draft.horizon == h
                    Button { draft.horizon = h } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: h.symbol).font(.system(size: 18, weight: .bold))
                            Text(h.label).font(.system(size: 20, weight: .heavy))
                            Text(h.title).font(.system(size: 13, weight: .semibold)).opacity(0.85)
                        }
                        .foregroundStyle(on ? p.onAccent : p.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(on ? p.accent : p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Text("Six months is the short term. Six years is the long term, the one the battle is for.")
                .font(.system(size: 13)).foregroundStyle(p.muted)
        }
    }

    private var colorGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Color")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(GoalColor.allCases) { c in
                    let on = draft.color == c
                    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                    Button { draft.color = c } label: {
                        shape.fill(p.color(c))
                            .frame(height: 44)
                            .overlay {
                                if on { Image(systemName: "checkmark").font(.system(size: 16, weight: .heavy)).foregroundStyle(p.onBand) }
                            }
                            .overlay(shape.strokeBorder(on ? p.text : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.label)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var symbolGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Symbol")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(GoalSymbols.all, id: \.self) { s in
                    let on = draft.symbol == s
                    Button { draft.symbol = s } label: {
                        Image(systemName: s)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(on ? p.onBand : p.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(on ? p.color(draft.color) : p.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(s)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var schedulePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("When")
            HStack(spacing: 8) {
                ForEach(ScheduleKind.allCases) { k in Chip(text: k.rawValue, on: kind == k) { kind = k } }
            }
            if kind == .some {
                HStack(spacing: 6) {
                    ForEach(Weekday.ordered(store.settings.weekStart)) { d in
                        let on = days.contains(d)
                        Button {
                            if on { days.remove(d) } else { days.insert(d) }
                        } label: {
                            Text(d.letter).font(.system(size: 14, weight: .bold))
                                .foregroundStyle(on ? p.onAccent : p.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(on ? p.accent : p.card, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(d.short)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            if kind == .times {
                Stepper(value: $times, in: 1...6) {
                    Text(times == 1 ? "Once a week" : "\(times) times a week")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(p.card, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                Text("Asked of a day only once the week could not be made without it.")
                    .font(.system(size: 13)).foregroundStyle(p.muted)
            }
        }
    }

    private var whyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Why")
            FieldBox {
                TextField("Why it matters, in your words (optional)", text: $draft.why, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(p.text)
                    .lineLimit(2...5)
            }
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            if draft.isArchived {
                PillButton(title: "Bring it back", style: .secondary, icon: "arrow.uturn.backward", full: true) {
                    store.unarchive(draft.id)
                    draft.archivedAt = nil
                }
            } else {
                PillButton(title: "Retire this goal", style: .secondary, icon: "archivebox", full: true) {
                    let d = today()
                    store.archive(draft.id, on: d)
                    draft.archivedAt = d
                }
            }
            PillButton(title: "Delete", style: .danger, icon: "trash", full: true) { confirmDelete = true }
            Text("Retiring keeps every day it colored. Deleting removes them.")
                .font(.system(size: 13)).foregroundStyle(p.muted)
        }
        .padding(.top, 8)
    }

    // MARK: Actions

    private func prepare() {
        guard !prepared else { return }
        switch mode {
        case .create:
            draft.color = store.nextColor
        case .edit(let id):
            if let g = store.goal(id) {
                draft = g
                switch g.schedule {
                case .daily: kind = .daily
                case .weekdays(let d): kind = .some; days = d
                case .timesPerWeek(let n): kind = .times; times = n
                }
            }
        }
        prepared = true
    }

    private func add() {
        var g = draft
        g.name = trimmedName
        g.schedule = schedule
        g.why = draft.why.trimmingCharacters(in: .whitespacesAndNewlines)
        store.put(g)
        dismiss()
    }
}
