import SwiftUI

/// The morning check-in, on one screen: when you went to sleep, when you woke, how much of that
/// was sleep, how good it was from 1 to 10, and the reason. The dials start on the targets, so
/// most mornings are a notch or two and a couple of taps. Nothing is said back about the numbers.
struct SleepCheckInView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    /// The day the night ended on.
    let day: String

    @State private var draft = SleepLog(day: "", bedMinute: 0, wakeMinute: 0, sleptMinutes: 0, quality: 0)
    /// The dials' own numbers: clock times that run past midnight instead of wrapping.
    @State private var bed = 0
    @State private var wake = 0
    @State private var slept = 0
    /// Once the hours dial is moved by hand it stops following the two clocks.
    @State private var sleptByHand = false
    /// The last length the clocks set, to tell their changes from the hand's.
    @State private var lastAuto = 0
    @State private var prepared = false
    @State private var existing = false
    @State private var saved = 0

    var body: some View {
        ScrollView {
            if prepared {
            VStack(alignment: .leading, spacing: 20) {
                header
                DialRow(title: "Went to sleep", value: $bed, values: DialValues.clock(around: draft.targetBedMinute),
                        major: DialValues.isHour) { clockLabel($0) }
                DialRow(title: "Woke up", value: $wake, values: DialValues.clock(around: draft.targetWakeMinute),
                        major: DialValues.isHour) { clockLabel($0) }
                DialRow(title: "Slept", value: $slept, values: DialValues.duration(upTo: 16),
                        major: DialValues.isHour) { durationLabel($0) }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quality").font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                    ScoreRow(value: $draft.quality, low: "Rough", high: "Great")
                }
                ReasonPicker(choices: reasonChoices(.sleep, used: store.reasonsUsed(.sleep)),
                             picked: draft.reasons, note: draft.note,
                             toggle: { r in
                                 if let i = draft.reasons.firstIndex(of: r) { draft.reasons.remove(at: i) } else { draft.reasons.append(r) }
                             },
                             setNote: { draft.note = $0 })
                PillButton(title: existing ? "Save changes" : "Save", style: .primary, full: true, height: 52) { save() }
                    .disabled(draft.quality == 0)
                    .opacity(draft.quality == 0 ? 0.45 : 1)
                if draft.quality == 0 {
                    Text("Pick a quality from 1 to 10 to save.")
                        .font(.system(size: 13)).foregroundStyle(p.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear(perform: prepare)
        .onChange(of: bed) { _, _ in follow() }
        .onChange(of: wake) { _, _ in follow() }
        .onChange(of: slept) { _, v in
            // A change that did not come from the clocks is the person's own estimate.
            if prepared && v != lastAuto { sleptByHand = true }
        }
        .sensoryFeedback(.success, trigger: saved) { _, _ in store.settings.haptics }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Sleep").font(.system(size: 28, weight: .heavy)).tracking(-0.4).foregroundStyle(p.text)
                Text(day == today() ? "Last night" : shortDayTitle(day))
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent)
                    .padding(.horizontal, 8).frame(height: 24)
                    .background(p.accentSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            Text("Your baseline is \(durationLabel(draft.needMinutes)). Estimates are fine.")
                .font(.system(size: 15)).foregroundStyle(p.muted)
        }
    }

    private func prepare() {
        guard !prepared else { return }
        existing = store.sleepLog(on: day) != nil
        draft = store.sleepDraft(for: day)
        bed = DialValues.onClock(draft.bedMinute, around: draft.targetBedMinute)
        wake = DialValues.onClock(draft.wakeMinute, around: draft.targetWakeMinute)
        slept = roundMinutes(draft.sleptMinutes)
        lastAuto = slept
        sleptByHand = existing
        prepared = true
    }

    /// Hours slept follows the two clocks until it is set by hand.
    private func follow() {
        guard prepared, !sleptByHand else { return }
        let span = sleepSpan(bed: clampMinute(bed), wake: clampMinute(wake))
        if span != slept {
            lastAuto = span
            slept = span
        }
    }

    private func save() {
        guard draft.quality > 0 else { return }
        draft.bedMinute = clampMinute(bed)
        draft.wakeMinute = clampMinute(wake)
        draft.sleptMinutes = slept
        draft.at = Date().timeIntervalSince1970 * 1000
        store.putSleep(draft)
        saved += 1
        dismiss()
    }
}
