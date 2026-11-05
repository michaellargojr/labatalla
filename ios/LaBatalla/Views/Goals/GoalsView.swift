import SwiftUI

/// Goals: the long-term ones first, then the short-term ones, then the retired ones. Tap a goal
/// to change it; Edit to drag them into order; New or Ideas to add.
struct GoalsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var creating = false
    @State private var ideas = false
    @State private var editMode: EditMode = .inactive
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScreenTitle("Goals") {
                    HStack(spacing: 8) {
                        if !store.activeGoals.isEmpty {
                            Chip(text: editMode == .active ? "Done" : "Edit", on: editMode == .active) {
                                withAnimation { editMode = editMode == .active ? .inactive : .active }
                            }
                        }
                        PillButton(title: "New", style: .primary, icon: "plus") { creating = true }
                    }
                }
                if store.goals.isEmpty {
                    emptyState
                } else {
                    goalList
                }
            }
            .screen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Goal.self) { g in GoalEditorView(mode: .edit(g.id)) }
            .sheet(isPresented: $creating) {
                NavigationStack { GoalEditorView(mode: .create) }
                    .presentationDetents([.large])
                    .presentationBackground(p.bg)
            }
            .sheet(isPresented: $ideas) {
                StartersSheet()
                    .presentationDetents([.large])
                    .presentationBackground(p.bg)
            }
        }
    }

    private var goalList: some View {
        List {
            ForEach(Horizon.allCases.reversed()) { h in
                let goals = store.goals(h)
                if !goals.isEmpty {
                    Section {
                        ForEach(goals) { g in
                            NavigationLink(value: g) { GoalRow(goal: g) }
                                .listRowBackground(p.card)
                                .listRowSeparatorTint(p.line)
                        }
                        .onMove { from, to in move(h, from: from, to: to) }
                    } header: {
                        sectionHeader(h)
                    }
                }
            }
            if !store.archivedGoals.isEmpty {
                Section {
                    ForEach(store.archivedGoals) { g in
                        NavigationLink(value: g) { GoalRow(goal: g) }
                            .listRowBackground(p.card)
                            .listRowSeparatorTint(p.line)
                    }
                } header: {
                    SectionLabel("Retired").textCase(nil)
                } footer: {
                    Text("Retired goals keep every day they colored.").foregroundStyle(p.muted)
                }
            }
            Section {
                Button { ideas = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").font(.system(size: 15, weight: .bold))
                        Text("Ideas for goals").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(p.accent)
                }
                .listRowBackground(p.card)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }

    private func sectionHeader(_ h: Horizon) -> some View {
        HStack(spacing: 6) {
            Image(systemName: h.symbol).font(.system(size: 11, weight: .bold))
            Text("\(h.label)  \(h.title)")
                .font(.system(size: 13, weight: .bold)).tracking(0.8)
        }
        .foregroundStyle(h == .sixYears ? p.accent : p.muted)
        .textCase(.uppercase)
    }

    private func move(_ h: Horizon, from: IndexSet, to: Int) {
        var list = store.goals(h)
        list.move(fromOffsets: from, toOffset: to)
        let other = Horizon.allCases.filter { $0 != h }.flatMap { store.goals($0) }
        let ordered = h == .sixYears ? list + other : other + list
        store.reorder(ordered.map(\.id))
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill").foregroundStyle(p.accent)
                            Text("The Six").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                        }
                        Text("Ask of anything you want to do: will it matter in six months, or in six years? Six months is the short term. Six years is the long term, and showing up for the long term, again and again, is the whole battle.")
                            .font(.system(size: 15)).foregroundStyle(p.secondary)
                        Text("Each goal gets a color. Every day you do it, that day gets a band of that color. The calendar fills in. That is all there is to it.")
                            .font(.system(size: 15)).foregroundStyle(p.secondary)
                    }
                }
                PillButton(title: "Set my first goal", style: .primary, icon: "plus", full: true, height: 52) { creating = true }
                PillButton(title: "Start from ideas", style: .secondary, icon: "sparkles", full: true, height: 52) { ideas = true }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
    }
}

/// One goal in the list: its color and symbol, name, when, and its run.
struct GoalRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let goal: Goal

    var body: some View {
        let s = store.streakOf(goal)
        HStack(spacing: 12) {
            GoalIcon(goal: goal, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text).lineLimit(2)
                Text(goal.schedule.label).font(.system(size: 13)).foregroundStyle(p.muted)
            }
            Spacer(minLength: 8)
            if s.current > 0 && !goal.isArchived {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(s.current)").font(.system(size: 18, weight: .heavy)).monospacedDigit().foregroundStyle(p.text)
                    Text(s.unit + (s.current == 1 ? "" : "s")).font(.system(size: 11, weight: .bold)).foregroundStyle(p.muted)
                }
            }
        }
        .padding(.vertical, 6)
        .opacity(goal.isArchived ? 0.55 : 1)
    }
}
