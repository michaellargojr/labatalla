import SwiftUI

/// The month's number for a job: what it should pay this month and the hours a day to give it.
/// Asked at the start of each month, or for the rest of the month when it is set mid-way. The
/// page does the one sum that matters as the answers go in: what an hour has to be worth.
struct MonthPlanSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    /// Any day of the month being planned.
    var day: String = today()

    @State private var incomeText = ""
    @State private var minutes = 8 * 60
    @State private var prepared = false

    private var sign: String { store.settings.currency }
    private var existing: MonthPlan? { store.plan(for: goal.id, month: day) }
    /// A plan keeps the day it was first set, so "the rest of November" stays what it meant.
    private var setOn: String { existing?.setOn ?? min(max(day, monthStart(day)), monthEnd(day)) }

    var body: some View {
        let first = max(monthStart(day), setOn)
        let workdays = plannedDays(goal.schedule, from: first, to: monthEnd(day))
        let income = typedNumber(incomeText)
        let hours = Double(minutes) / 60
        let need = neededPerHour(income: income, hoursPerDay: hours, workdays: Double(workdays))
        ScrollView {
            if prepared {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What should it pay?").font(.system(size: 18, weight: .bold)).foregroundStyle(p.text)
                        FieldBox {
                            HStack(spacing: 6) {
                                Text(sign).font(.system(size: 20, weight: .semibold)).foregroundStyle(p.muted)
                                TextField("After tax", text: $incomeText)
                                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(p.text)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How many hours a day?").font(.system(size: 18, weight: .bold)).foregroundStyle(p.text)
                        DialRow(title: "Hours a day", value: $minutes, values: DialValues.workDay, major: DialValues.isHour,
                                tint: p.color(goal.color)) { durationLabel($0) }
                    }
                    sums(workdays: workdays, income: income, hours: hours, need: need)
                    PillButton(title: existing == nil ? "Set it" : "Save changes", style: .primary, full: true, height: 52) {
                        save(income: income, hours: hours)
                    }
                    .disabled(income <= 0)
                    .opacity(income <= 0 ? 0.45 : 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear(perform: prepare)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                GoalIcon(goal: goal, size: 36)
                Text(goal.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary).lineLimit(1)
            }
            Text(planTitle(month: day, setOn: setOn))
                .font(.system(size: 28, weight: .heavy)).tracking(-0.4).foregroundStyle(p.text)
            Text("A number for the month and the hours you want to give it. Six months is the far target; this is the next step toward it.")
                .font(.system(size: 15)).foregroundStyle(p.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func line(_ left: String, _ right: String, strong: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left).font(.system(size: 14)).foregroundStyle(p.secondary)
            Spacer(minLength: 8)
            Text(right).font(.system(size: 15, weight: strong ? .heavy : .bold)).monospacedDigit().foregroundStyle(p.text)
        }
    }

    /// What the two answers come to, next to the six-month target and what the job has been paying.
    private func sums(workdays: Int, income: Double, hours: Double, need: Double?) -> some View {
        let w = goal.workSetup
        let recent = workTotals(goal, marks: store.marks, from: addDays(-29, to: day), to: day)
        let sixMonth = neededPerHour(income: w.targetIncome, hoursPerDay: w.targetHours, workdays: workdaysPerMonth(goal.schedule))
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                line("Work days in the plan", "\(workdays)")
                line("Hours in all", hoursLabel(hours * Double(workdays)))
                if let need {
                    Divider1()
                    line("An hour has to be worth", money(need, sign), strong: true)
                }
                if let rate = recent.perHour, recent.daysWorked >= 3 {
                    line("The last 30 days paid", "\(money(rate, sign)) an hour")
                }
                if let sixMonth {
                    line("Your six-month target needs", "\(money(sixMonth, sign)) an hour")
                }
            }
        }
    }

    private func prepare() {
        guard !prepared else { return }
        let w = goal.workSetup
        if let plan = existing {
            incomeText = plainNumber(plan.income)
            minutes = roundMinutes(Int((plan.hoursPerDay * 60).rounded()))
        } else if let last = store.plans.filter({ $0.goalId == goal.id }).max(by: { $0.month < $1.month }) {
            // Last month's answers are the place to start.
            incomeText = plainNumber(last.income)
            minutes = roundMinutes(Int((last.hoursPerDay * 60).rounded()))
        } else {
            minutes = roundMinutes(Int((w.requiredHours * 60).rounded()))
        }
        minutes = min(max(minutes, 15), 16 * 60)
        prepared = true
    }

    private func save(income: Double, hours: Double) {
        guard income > 0 else { return }
        store.putPlan(MonthPlan(id: existing?.id ?? uid(), goalId: goal.id, month: monthKey(day),
                                income: income, hoursPerDay: hours, setOn: setOn))
        dismiss()
    }
}
