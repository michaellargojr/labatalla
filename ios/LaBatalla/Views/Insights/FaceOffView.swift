import SwiftUI

/// Head to head: two goals at a time, and one question. If only one of these could happen,
/// which? It is the question a 1 to 10 cannot answer, since everything can be a 9. Pairs marked
/// as pulling against each other come first. One tap each; any pair can be skipped.
struct FaceOffView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State private var skipped: Set<String> = []
    @State private var confirmClear = false

    var body: some View {
        let t = today()
        let pool = duelable(store.activeGoals, today: t)
        let count = duelCount(pool, duels: store.duels)
        let pair = nextPair(pool)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if pool.count < 2 {
                        EmptyNote("Head to head needs at least two goals.")
                    } else {
                        tally(count)
                        if let pair {
                            question(pair.0, pair.1)
                        } else {
                            EmptyNote(count.done == count.of ? "Every pair has an answer." : "The rest were skipped. Close this and come back to see them again.")
                        }
                        if count.done > 0 { results(today: t) }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .screen()
            .navigationTitle("Head to head")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(p.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
            }
            .confirmationDialog("Clear every head-to-head answer?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear answers", role: .destructive) {
                    store.clearDuels()
                    skipped = []
                }
                Button("Keep them", role: .cancel) {}
            }
        }
    }

    private func key(_ a: Goal, _ b: Goal) -> String { a.id < b.id ? "\(a.id)|\(b.id)" : "\(b.id)|\(a.id)" }

    /// The next pair with no answer that has not been skipped: declared conflicts first.
    private func nextPair(_ pool: [Goal]) -> (Goal, Goal)? {
        var open: [(Goal, Goal)] = []
        for (i, a) in pool.enumerated() {
            for b in pool.dropFirst(i + 1) {
                if !canDuel(a, b) || skipped.contains(key(a, b)) { continue }
                if store.duels.contains(where: { $0.isBetween(a.id, b.id) }) { continue }
                open.append((a, b))
            }
        }
        if let clash = open.first(where: { $0.0.conflicts.contains($0.1.id) || $0.1.conflicts.contains($0.0.id) }) { return clash }
        return open.first
    }

    private func tally(_ count: (done: Int, of: Int)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(count.done) of \(count.of) pairs decided").font(.system(size: 13, weight: .semibold)).foregroundStyle(p.secondary)
            MeterBar(share: count.of > 0 ? Double(count.done) / Double(count.of) : 0)
        }
    }

    private func question(_ a: Goal, _ b: Goal) -> some View {
        let clash = a.conflicts.contains(b.id) || b.conflicts.contains(a.id)
        return VStack(alignment: .leading, spacing: 12) {
            Text("If only one of these could happen, which?")
                .font(.system(size: 22, weight: .heavy)).tracking(-0.3).foregroundStyle(p.text)
                .fixedSize(horizontal: false, vertical: true)
            if clash {
                Text("You marked these two as pulling against each other.").font(.system(size: 14)).foregroundStyle(p.muted)
            }
            choice(a, over: b)
            Text("or").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted).frame(maxWidth: .infinity)
            choice(b, over: a)
            Chip(text: "Skip this pair", icon: "arrow.right") {
                withAnimation(.snappy(duration: 0.22)) { _ = skipped.insert(key(a, b)) }
            }
        }
        .sensoryFeedback(.selection, trigger: store.duels.count) { _, _ in store.settings.haptics }
    }

    private func choice(_ g: Goal, over other: Goal) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return Button {
            withAnimation(.snappy(duration: 0.22)) { store.decide(g.id, other.id, winner: g.id) }
        } label: {
            HStack(spacing: 14) {
                GoalIcon(goal: g, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(g.name).font(.system(size: 19, weight: .heavy)).foregroundStyle(p.text)
                        .multilineTextAlignment(.leading)
                    if !g.why.isEmpty {
                        Text(g.why).font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.card, in: shape)
            .overlay(shape.strokeBorder(p.color(g.color).opacity(0.7), lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(g.name)
    }

    private func results(today t: String) -> some View {
        let rows = standings(goals: store.activeGoals, duels: store.duels, marks: store.marks, today: t)
            .sorted { a, b in (a.choseRank ?? Int.max, a.name) < (b.choseRank ?? Int.max, b.name) }
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("So far")
            Card { StandingsTable(rows: rows) }
            Text("Said is the 1 to 10 you gave. Chose is the rank from these answers. Did is the share of its plan each got in the last four weeks. Where the three disagree is worth a look.")
                .font(.system(size: 13)).foregroundStyle(p.muted)
                .fixedSize(horizontal: false, vertical: true)
            PillButton(title: "Start over", icon: "arrow.counterclockwise") { confirmClear = true }
        }
    }
}
