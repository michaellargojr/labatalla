import SwiftUI

/// The first run: what the app is, then the three sleep numbers everything else is read against
/// (how much sleep you need, when you mean to go to bed, when you mean to get up), then whether
/// to be reminded. Each can be changed later in Settings.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var step = 0
    @State private var need = 8 * 60
    @State private var bed = 22 * 60 + 30
    @State private var wake = 7 * 60
    @State private var remind = true

    private let last = 3

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0...last, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i <= step ? p.accent : p.elevated)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch step {
                    case 0: welcome
                    case 1: sleepNeed
                    case 2: schedule
                    default: reminders
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            HStack(spacing: 10) {
                if step > 0 {
                    PillButton(title: "Back", style: .secondary, height: 52) { withAnimation(.snappy) { step -= 1 } }
                }
                PillButton(title: step == last ? "Start" : "Next", style: .primary, full: true, height: 52) {
                    if step == last { finish() } else { withAnimation(.snappy) { step += 1 } }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .screen()
        .onAppear {
            need = store.settings.sleepNeedMinutes
            bed = DialValues.onClock(store.settings.targetBedMinute, around: store.settings.targetBedMinute)
            wake = DialValues.onClock(store.settings.targetWakeMinute, around: store.settings.targetWakeMinute)
        }
    }

    private func title(_ text: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.system(size: 30, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
            Text(detail).font(.system(size: 16)).foregroundStyle(p.secondary)
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            BattleMark(color: p.onAccent)
                .padding(14)
                .frame(width: 76, height: 76)
                .background(p.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            title("La batalla", "The battle. A map of yours: what you are fighting for, what each day gave it, and what keeps getting in the way.")
            point("moon.fill", "A sleep check-in each morning", "A few dials and a tap. Seconds.")
            point("flag.fill", "A yes or no for each goal", "Anything counts, even a few minutes. Each answer comes with a reason.")
            point("chart.bar.fill", "The patterns, without asking", "Lack of sleep, lack of time, the reason that keeps coming back: the app points at it.")
            Text("Nothing here grades you. It only shows what happened.")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text)
        }
    }

    private func point(_ icon: String, _ head: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(p.accent)
                .frame(width: 36, height: 36)
                .background(p.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(head).font(.system(size: 16, weight: .bold)).foregroundStyle(p.text)
                Text(body).font(.system(size: 14)).foregroundStyle(p.muted)
            }
        }
    }

    private var sleepNeed: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("How much sleep do you need?", "Everyone has their own number: the hours after which you wake up without an alarm and feel right. This is your baseline. Every night is read against it.")
            DialRow(title: "Your baseline", value: $need, values: DialValues.duration(upTo: 12, from: 4 * 60),
                    major: DialValues.isHour) { durationLabel($0) }
            Text("If you are not sure, start with 8h and adjust it in Settings once the nights add up.")
                .font(.system(size: 14)).foregroundStyle(p.muted)
        }
    }

    private var schedule: some View {
        let inBed = sleepSpan(bed: clampMinute(bed), wake: clampMinute(wake))
        return VStack(alignment: .leading, spacing: 22) {
            title("Your sleep schedule", "The bedtime and the wake time you are aiming for. The morning check-in starts its dials here.")
            DialRow(title: "Target bedtime", value: $bed, values: DialValues.clock(around: 22 * 60 + 30),
                    major: DialValues.isHour) { clockLabel($0) }
            DialRow(title: "Target wake time", value: $wake, values: DialValues.clock(around: 7 * 60),
                    major: DialValues.isHour) { clockLabel($0) }
            Card {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(durationLabel(inBed)) between them").font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                    Text("Your baseline is \(durationLabel(need)).").font(.system(size: 14)).foregroundStyle(p.muted)
                }
            }
        }
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("Two small nudges", "One a little after you wake, for the sleep check-in. One in the evening, for the day. Each takes seconds, and neither ever scolds.")
            Card {
                Toggle(isOn: $remind) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check-in reminders").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                        Text("Morning at \(clockLabel(clampMinute(wake) + 15)), evening at \(clockLabel(eveningMinute))")
                            .font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                }
                .tint(p.accent)
            }
            Text("The phone will ask to allow notifications. Times can be changed in Settings.")
                .font(.system(size: 14)).foregroundStyle(p.muted)
        }
    }

    /// Ninety minutes before the target bedtime.
    private var eveningMinute: Int { clampMinute(clampMinute(bed) - 90) }

    private func finish() {
        store.update { s in
            s.sleepNeedMinutes = need
            s.targetBedMinute = clampMinute(bed)
            s.targetWakeMinute = clampMinute(wake)
            s.morningCheckIn = remind
            s.reminderOn = remind
            s.reminderMinute = eveningMinute
            s.onboarded = true
        }
    }
}
