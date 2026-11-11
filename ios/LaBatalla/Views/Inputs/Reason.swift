import SwiftUI

/// Lays its children out left to right and wraps to the next line when the row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews) {
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                                           proposal: ProposedViewSize(item.size))
            }
        }
    }

    private struct Item { var index: Int; var x: CGFloat; var size: CGSize }
    private struct Row { var items: [Item] = []; var y: CGFloat = 0; var height: CGFloat = 0; var width: CGFloat = 0 }

    private func arrange(width: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        var x: CGFloat = 0
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                rows.append(row)
                row = Row(y: row.y + row.height + spacing)
                x = 0
            }
            row.items.append(Item(index: i, x: x, size: size))
            row.height = max(row.height, size.height)
            row.width = x + size.width
            x += size.width + spacing
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

/// "Reason", then a row of chips to tap, then a place to type one. Never "excuse", never a
/// judgment: whatever is picked is simply kept. A reason typed once comes back as a chip.
struct ReasonPicker: View {
    @Environment(\.palette) private var p
    let choices: [String]
    let picked: [String]
    var note: String
    var tint: Color? = nil
    let toggle: (String) -> Void
    let setNote: (String) -> Void

    @State private var typing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Reason").font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                if picked.isEmpty && note.isEmpty {
                    Text("one tap").font(.system(size: 13)).foregroundStyle(p.accent)
                }
            }
            FlowLayout(spacing: 7) {
                // Reasons already on the answer that are no longer among the chips still show.
                ForEach(all, id: \.self) { r in
                    chip(r, on: picked.contains(r)) { toggle(r) }
                }
                chip(note.isEmpty ? "Other" : (note.count > 24 ? String(note.prefix(22)) + "..." : note), on: !note.isEmpty, icon: "pencil") {
                    text = note
                    typing = true
                }
            }
            if typing {
                FieldBox {
                    TextField("In your words", text: $text)
                        .font(.system(size: 16))
                        .foregroundStyle(p.text)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { commit() }
                        .onAppear { focused = true }
                }
            }
        }
        .onChange(of: focused) { _, f in if !f && typing { commit() } }
    }

    private var all: [String] {
        var out = choices
        for r in picked where !out.contains(r) { out.append(r) }
        return out
    }

    private func commit() {
        setNote(text.trimmingCharacters(in: .whitespacesAndNewlines))
        typing = false
    }

    private func chip(_ text: String, on: Bool, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
                Text(text).font(.system(size: 14, weight: on ? .bold : .semibold)).lineLimit(1)
            }
            .foregroundStyle(on ? (tint == nil ? p.onAccent : p.onBand) : p.text)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(on ? (tint ?? p.accent) : p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
