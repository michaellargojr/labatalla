import SwiftUI

/// Goals: everything being fought for, in your own order, then the ones retired or achieved.
/// Tap a goal for its page and its questions; Edit to drag them into order; New or Ideas to add.
/// Each row carries what setup captured: what sort of goal it is, how important you said it
/// was, and how many of its questions are still open.
struct GoalsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var creating = false
    @State private var ideas = false
    @State private var faceOff = false
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
            .sheet(isPresented: $faceOff) {
                FaceOffView()
                    .presentationDetents([.large])
                    .presentationBackground(p.bg)
            }
            #if DEBUG
            .onAppear {
                switch DebugLaunch.screen {
                case "newgoal": creating = true
                case "ideas": ideas = true
                case "goal": if let g = store.activeGoals.first(where: { $0.kind == .time && $0.totalHours > 0 }) { path.append(g) }
                case "job": if let g = store.workGoals.first { path.append(g) }
                default: break
                }
            }
            #endif
        }
    }

    private var goalList: some View {
        let active = store.activeGoals
        return List {
            if !active.isEmpty {
                Section {
                    ForEach(active) { g in
                        NavigationLink(value: g) { GoalRow(goal: g) }
                            .listRowBackground(p.card)
                            .listRowSeparatorTint(p.line)
                    }
                    .onMove { from, to in move(from: from, to: to) }
                } header: {
                    SectionLabel("Fighting for").textCase(nil)
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
                    SectionLabel("Achieved and retired").textCase(nil)
                } footer: {
                    Text("These keep every day they colored, and the estimates they started with.").foregroundStyle(p.muted)
                }
            }
            Section {
                if active.count >= 2 {
                    Button { faceOff = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.left.arrow.right").font(.system(size: 15, weight: .bold))
                            Text("Head to head").font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(p.accent)
                    }
                    .listRowBackground(p.card)
                    .listRowSeparatorTint(p.line)
                }
                Button { ideas = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").font(.system(size: 15, weight: .bold))
                        Text("Ideas for goals").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(p.accent)
                }
                .listRowBackground(p.card)
            } footer: {
                if active.count >= 2 {
                    Text("Head to head puts two goals side by side and asks which one wins if only one can happen.").foregroundStyle(p.muted)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }

    private func move(from: IndexSet, to: Int) {
        var list = store.activeGoals
        list.move(fromOffsets: from, toOffset: to)
        store.reorder(list.map(\.id))
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill").foregroundStyle(p.accent)
                            Text("What are you fighting for?").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                        }
                        Text("Setting a goal takes a few minutes, on purpose. It asks how important it is, when you think it will be done, how many hours it takes, and how clear the path is. Those first answers are kept, so later you can see how they held up.")
                            .font(.system(size: 15)).foregroundStyle(p.secondary)
                        Text("After that, each day is a yes or a no and a reason. Seconds. Every day with a yes gets the goal's color on the calendar, however short the session was.")
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

/// One goal in the list: its color and symbol, name, what sort it is and its plan, what it
/// serves, how many setup questions are open, and the importance it was given.
struct GoalRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let goal: Goal

    var body: some View {
        let open = openQuestions(goal, goals: store.goals, duels: store.duels).count
        HStack(spacing: 12) {
            GoalIcon(goal: goal, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text).lineLimit(2)
                Text(planLine).font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(2)
                if let extra = extraLine(open: open) {
                    Text(extra).font(.system(size: 12, weight: .semibold)).foregroundStyle(p.accent).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if goal.importance > 0 && !goal.isArchived { ImportanceTag(value: goal.importance) }
        }
        .padding(.vertical, 6)
        .opacity(goal.isArchived ? 0.55 : 1)
    }

    /// "Takes hours - 3 times a week - 1h 30m".
    private var planLine: String {
        if let done = goal.achievedAt { return "Achieved \(mediumDay(done))" }
        var parts = [goal.kind.label]
        switch goal.kind {
        case .time:
            parts.append(goal.schedule.label)
            if goal.sessionMinutes > 0 { parts.append(durationLabel(goal.sessionMinutes)) }
        case .adherence:
            parts.append(goal.schedule.label)
        case .work:
            parts.append(goal.schedule.label)
            parts.append(hoursOfDayLabel(goal.workSetup.requiredHours))
        case .outcome:
            if let r = goal.reasonable { parts.append("by \(briefDay(r))") }
        }
        return parts.joined(separator: " - ")
    }

    /// "Serves Best shape - 2 open questions".
    private func extraLine(open: Int) -> String? {
        var parts: [String] = []
        if let parent = goal.parentId, let name = store.goal(parent)?.name { parts.append("Serves \(name)") }
        if open > 0 { parts.append(open == 1 ? "1 open question" : "\(open) open questions") }
        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }
}
