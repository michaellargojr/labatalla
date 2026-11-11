import Foundation
import Testing
@testable import LaBatalla

// Work: hours in, money out, and the number that tells the truth about both: money per hour.

@Suite struct MoneyWordsTests {
    @Test func money() {
        #expect(LaBatalla.money(7000) == "$7,000")
        #expect(LaBatalla.money(79.5) == "$79.50")
        #expect(LaBatalla.money(0) == "$0")
        #expect(LaBatalla.money(1_234_567) == "$1,234,567")
        #expect(LaBatalla.money(150.4) == "$150")      // from 100 up, no cents
        #expect(LaBatalla.money(-20) == "-$20")
        #expect(LaBatalla.money(5, "P") == "P5")
    }

    @Test func typedNumbers() {
        #expect(typedNumber("$7,000.50") == 7000.5)
        #expect(typedNumber("abc") == 0)
        #expect(typedNumber("") == 0)
        #expect(plainNumber(7000) == "7000")
        #expect(plainNumber(79.5) == "79.50")
        #expect(plainNumber(0) == "")
        #expect(hoursOfDayLabel(6.25) == "6h 15m")
        #expect("meeting".capitalizedFirst == "Meeting")
    }

    @Test func monthWords() {
        let day = "2026-11-11"
        #expect(planTitle(month: day, setOn: "2026-11-01") == monthName(day))
        #expect(planTitle(month: day, setOn: day) == "The rest of \(monthName(day))")
        #expect(planWords(month: day, setOn: day) == "the rest of \(monthName(day))")
    }
}

@Suite struct WorkTotalsTests {
    private func job(_ change: (inout WorkSetup) -> Void) -> Goal {
        var w = WorkSetup()
        change(&w)
        return Goal(name: "Sales", schedule: .weekdays(Weekday.workdays), createdAt: "2026-10-01", kind: .work, work: w)
    }

    @Test func resultsHoursAndMoneyByHand() throws {
        let g = job { $0.unitName = "meeting"; $0.unitValue = 50; $0.hourlyRate = 10 }
        let marks = [Mark(goalId: g.id, day: "2026-11-09", minutes: 300, units: 2),
                     Mark(goalId: g.id, day: "2026-11-10", minutes: 240, units: 1, amount: 25),
                     Mark(goalId: g.id, day: "2026-11-11", done: false)]
        let t = workTotals(g, marks: marks, from: "2026-11-09", to: "2026-11-11")
        #expect(t.minutes == 540)
        #expect(t.units == 3)
        #expect(t.earned == 265)          // 3 x 50, plus 25, plus 9h x 10
        #expect(t.daysWorked == 2)
        #expect(t.avgMinutesPerDay == 270)
        let rate = try #require(t.perHour)
        #expect(abs(rate - 265.0 / 9.0) < 0.001)
    }

    @Test func fixedPayIsSharedOverTheWorkDays() {
        let g = job { $0.basePerMonth = 2100 }
        // Nov 2 to 6 is five of November's 21 weekdays.
        let t = workTotals(g, marks: [], from: "2026-11-02", to: "2026-11-06")
        #expect(abs(t.earned - 500) < 0.001)
        #expect(t.perHour == nil)
        #expect(t.avgMinutesPerDay == nil)
    }

    @Test func whatAnHourHasToBeWorth() {
        #expect(neededPerHour(income: 7000, hoursPerDay: 4, workdays: 20) == 87.5)
        #expect(neededPerHour(income: 0, hoursPerDay: 4, workdays: 20) == nil)
        #expect(neededPerHour(income: 7000, hoursPerDay: 0, workdays: 20) == nil)
        #expect(abs(workdaysPerMonth(.weekdays(Weekday.workdays)) - 21.6667) < 0.001)
    }

    @Test func aMonthAgainstItsNumber() throws {
        let g = job { $0.unitName = "meeting"; $0.unitValue = 100 }
        let plan = MonthPlan(goalId: g.id, month: "2026-11", income: 4200, hoursPerDay: 5, setOn: "2026-11-01")
        let marks = ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06"].map {
            Mark(goalId: g.id, day: $0, minutes: 300, units: 1)
        }
        // Monday the 9th, not yet answered: five work days gone, sixteen left.
        let p = monthPace(g, plan: plan, marks: marks, today: "2026-11-09")
        #expect(p.target == 4200)
        #expect(p.earned == 500)
        #expect(p.minutes == 1500)
        #expect(p.daysWorked == 5)
        #expect(p.workdays == 21)
        #expect(p.workdaysLeft == 16)
        #expect(p.perHour == 20)
        #expect(p.neededPerHour == 40)
        #expect(p.projected == 2100)
        #expect(p.left == 3700)
        let hours = try #require(p.hoursPerDayAtThisRate)
        #expect(abs(hours - 11.5625) < 0.001)   // 3,700 at 20 an hour over 16 days
    }

    @Test func aPlanSetMidMonthCoversTheRest() {
        let g = job { $0.unitValue = 100; $0.unitName = "sale" }
        let plan = MonthPlan(goalId: g.id, month: "2026-11", income: 1000, hoursPerDay: 4, setOn: "2026-11-16")
        let early = [Mark(goalId: g.id, day: "2026-11-03", minutes: 300, units: 5)]
        let p = monthPace(g, plan: plan, marks: early, today: "2026-11-16")
        #expect(p.earned == 0)            // what came before the plan is not counted toward it
        #expect(p.workdays == 11)         // Nov 16 to 30
        #expect(p.workdaysLeft == 11)
        #expect(p.projected == nil)
    }

    @Test func askingForTheMonthsNumber() {
        let g = job { _ in }
        #expect(needsMonthPlan(g, plans: [], today: "2026-11-11"))
        let plan = MonthPlan(goalId: g.id, month: "2026-11", income: 1, hoursPerDay: 1, setOn: "2026-11-01")
        #expect(!needsMonthPlan(g, plans: [plan], today: "2026-11-11"))
        #expect(needsMonthPlan(g, plans: [plan], today: "2026-12-01"))   // a new month asks again
        #expect(!needsMonthPlan(Goal(name: "Lift", kind: .time), plans: [], today: today()))
        let later = MonthPlan(goalId: g.id, month: "2026-11", income: 2, hoursPerDay: 1, setOn: "2026-11-10")
        #expect(monthPlan([plan, later], goalId: g.id, month: "2026-11-20")?.income == 2)
    }
}
