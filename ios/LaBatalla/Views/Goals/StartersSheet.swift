import SwiftUI

/// Ideas: ready-made goals to tick and add. Each gets the next free color.
struct StartersSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Tick any. You can change the color, the days and the words after.")
                        .font(.system(size: 15)).foregroundStyle(p.secondary)
                    ForEach(Horizon.allCases.reversed()) { h in
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("\(h.label)  \(h.title)")
                            ForEach(Starters.all.filter { $0.horizon == h }) { s in row(s) }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .screen()
            .navigationTitle("Ideas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(p.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(chosen.count > 1 ? "Add \(chosen.count)" : "Add") { add() }
                        .fontWeight(.bold)
                        .disabled(chosen.isEmpty)
                }
            }
        }
    }

    private func row(_ s: Starter) -> some View {
        let on = chosen.contains(s.id)
        let already = store.activeGoals.contains { $0.name == s.name }
        return Button {
            if on { chosen.remove(s.id) } else { chosen.insert(s.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: s.symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(on ? p.onAccent : p.text)
                    .frame(width: 40, height: 40)
                    .background(on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(s.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                        if already { Text("added").font(.system(size: 11, weight: .bold)).foregroundStyle(p.muted) }
                    }
                    Text(s.schedule.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(p.secondary)
                    if !s.why.isEmpty {
                        Text(s.why).font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                RectCheck(on: on, size: 26)
            }
            .padding(10)
            .background(p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func add() {
        var used = store.activeGoals.map(\.color)
        for s in Starters.all where chosen.contains(s.id) {
            let c = GoalColor.next(after: used)
            used.append(c)
            store.put(s.goal(color: c))
        }
        dismiss()
    }
}
