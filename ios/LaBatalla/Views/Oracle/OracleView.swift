import SwiftUI
import UIKit

/// The Oracle: an advisor that reads the whole map (sleep, goals, hours, work, reasons) and
/// answers questions about it. It is Claude, asked through the person's own API key. Without a
/// key the brief can still be copied and pasted into any Claude chat.
struct OracleView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var busy = false
    @State private var failure: String?
    @State private var hasKey = false
    @State private var keyText = ""
    @State private var copied = false
    @State private var confirmClear = false
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            intro
                            if !hasKey { keyCard }
                            ForEach(store.oracle) { turn in bubble(turn) }
                            if busy { thinking }
                            if let failure {
                                Text(failure).font(.system(size: 14)).foregroundStyle(p.secondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                            }
                            if !busy { suggestions }
                            Color.clear.frame(height: 1).id("end")
                        }
                        .padding(16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.oracle.count) { _, _ in withAnimation { proxy.scrollTo("end", anchor: .bottom) } }
                    .onChange(of: busy) { _, _ in withAnimation { proxy.scrollTo("end", anchor: .bottom) } }
                    .onAppear { proxy.scrollTo("end", anchor: .bottom) }
                }
                inputBar
            }
            .screen()
            .navigationTitle("The Oracle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(p.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button { copyBrief() } label: { Label("Copy my brief", systemImage: "doc.on.doc") }
                        if !store.oracle.isEmpty {
                            Button(role: .destructive) { confirmClear = true } label: { Label("Clear this talk", systemImage: "trash") }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
            }
            .confirmationDialog("Clear this talk with the Oracle?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear", role: .destructive) { store.clearOracle() }
                Button("Keep it", role: .cancel) {}
            }
            .onAppear { hasKey = OracleKey.isSet }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("It sees the whole battlefield at once: your sleep, every goal, the hours, the money, and the reasons. Ask it what you cannot see from inside the day.")
                .font(.system(size: 15)).foregroundStyle(p.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Asking sends your brief to Anthropic to get the answer. Nothing else ever leaves this phone.")
                .font(.system(size: 13)).foregroundStyle(p.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Shown until a key is saved: where to put it, and the way to use the Oracle without one.
    private var keyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("One thing first").font(.system(size: 17, weight: .heavy)).foregroundStyle(p.text)
                Text("The Oracle is Claude. To ask it from inside the app it needs an Anthropic API key, kept in this phone's keychain and never in your export file.")
                    .font(.system(size: 14)).foregroundStyle(p.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                FieldBox {
                    SecureField("Paste the API key", text: $keyText)
                        .font(.system(size: 16)).foregroundStyle(p.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                HStack(spacing: 8) {
                    PillButton(title: "Save key", style: .primary) { saveKey() }
                        .disabled(keyText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(keyText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                    PillButton(title: copied ? "Copied" : "Copy my brief", icon: copied ? "checkmark" : "doc.on.doc") { copyBrief() }
                }
                Text("No key? Copy my brief puts everything the Oracle would read on the clipboard. Paste it into any Claude chat and ask there.")
                    .font(.system(size: 13)).foregroundStyle(p.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bubble(_ turn: OracleTurn) -> some View {
        HStack {
            if turn.mine { Spacer(minLength: 40) }
            Text(turn.text)
                .font(.system(size: 16))
                .foregroundStyle(turn.mine ? p.onAccent : p.text)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(turn.mine ? p.accent : p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            if !turn.mine { Spacer(minLength: 16) }
        }
        .frame(maxWidth: .infinity, alignment: turn.mine ? .trailing : .leading)
    }

    private var thinking: some View {
        HStack(spacing: 10) {
            ProgressView().tint(p.accent)
            Text("Reading the map").font(.system(size: 15)).foregroundStyle(p.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
    }

    private var suggestions: some View {
        let asked = Set(store.oracle.filter(\.mine).map(\.text))
        let open = Oracle.starters(hasWork: !store.workGoals.isEmpty).filter { !asked.contains($0) }
        return Group {
            if !open.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(store.oracle.isEmpty ? "Ask" : "Or ask")
                    FlowLayout(spacing: 7) {
                        ForEach(open, id: \.self) { q in
                            Chip(text: q) { ask(q) }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            FieldBox {
                TextField("Ask the Oracle", text: $text, axis: .vertical)
                    .font(.system(size: 16)).foregroundStyle(p.text)
                    .lineLimit(1...5)
                    .focused($typing)
            }
            Button { ask(text) } label: {
                Image(systemName: "arrow.up").font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(p.onAccent)
                    .frame(width: 46, height: 46)
                    .background(p.accent, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityLabel("Ask")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(p.bg)
    }

    // MARK: Actions

    private func saveKey() {
        if OracleKey.save(keyText) {
            keyText = ""
            hasKey = OracleKey.isSet
            failure = nil
        } else {
            failure = "The keychain did not take the key. Try again."
        }
    }

    private func copyBrief() {
        UIPasteboard.general.string = battlefieldBrief(store.insightInput())
        copied = true
    }

    private func ask(_ raw: String) {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !busy else { return }
        guard let key = OracleKey.read() else {
            hasKey = false
            failure = OracleError.noKey.words
            return
        }
        let brief = battlefieldBrief(store.insightInput())
        let before = store.oracle
        let model = store.settings.oracleModel
        store.say(OracleTurn(mine: true, text: question))
        text = ""
        typing = false
        failure = nil
        busy = true
        Task { @MainActor in
            do {
                let answer = try await Oracle.ask(question: question, brief: brief, transcript: before, model: model, key: key)
                store.say(OracleTurn(mine: false, text: answer))
            } catch let error as OracleError {
                failure = error.words
            } catch {
                failure = OracleError.network(error.localizedDescription).words
            }
            busy = false
        }
    }
}
