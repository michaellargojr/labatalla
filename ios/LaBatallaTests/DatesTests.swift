import Foundation
import Testing
@testable import LaBatalla

// Day strings, weeks that start on Monday or Sunday, month grids, paging bounds and the words.
// Known days: 2026-11-01 is a Sunday, 2026-11-05 a Thursday, 2026-10-01 a Thursday.

@Suite struct WeekTests {
    @Test func isoWeekdays() {
        #expect(isoWeekday("2026-11-05") == 4)
        #expect(isoWeekday("2026-11-01") == 7)
        #expect(isoWeekday("2026-11-02") == 1)
        #expect(Weekday.of("2026-11-05") == .thursday)
        #expect(Weekday.of("2026-11-01") == .sunday)
    }

    @Test func weeksStartOnMonday() {
        #expect(weekStart("2026-11-01", .monday) == "2026-10-26")
        #expect(weekStart("2026-10-26", .monday) == "2026-10-26")
        #expect(weekStart("2026-10-23", .monday) == "2026-10-19")
    }

    @Test func weeksStartOnSunday() {
        #expect(weekStart("2026-11-01", .sunday) == "2026-11-01")
        #expect(weekStart("2026-11-05", .sunday) == "2026-11-01")
        #expect(weekStart("2026-11-07", .sunday) == "2026-11-01")
        #expect(weekStart("2026-11-08", .sunday) == "2026-11-08")
    }

    @Test func weekDaysRunInOrder() {
        #expect(weekDays("2026-10-23", .monday) == ["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25"])
        #expect(weekDays("2026-12-30", .monday).last == "2027-01-03")
        #expect(weekDays("2026-11-05", .sunday).first == "2026-11-01")
        #expect(weekDays("2026-11-05", .sunday).last == "2026-11-07")
    }

    @Test func weekTitles() {
        #expect(weekTitle("2026-10-21", .monday) == "Oct 19 - 25")
        #expect(weekTitle("2026-11-01", .monday) == "Oct 26 - Nov 1")
        #expect(weekTitle("2026-12-30", .monday) == "Dec 28 - Jan 3")
        #expect(weekTitle("2026-11-05", .sunday) == "Nov 1 - 7")
    }

    @Test func weekLabels() {
        #expect(weekLabel("2026-11-03", .monday, today: "2026-11-05") == "This week")
        #expect(weekLabel("2026-10-28", .monday, today: "2026-11-05") == "Last week")
        #expect(weekLabel("2026-10-14", .monday, today: "2026-11-05") == "Oct 12 - 18")
    }

    @Test func weekStartsList() {
        #expect(weekStarts(from: "2026-10-20", to: "2026-11-05", .monday) == ["2026-10-19", "2026-10-26", "2026-11-02"])
        #expect(weekStarts(from: "2026-11-05", to: "2026-11-05", .sunday) == ["2026-11-01"])
    }

    @Test func orderedWeekdays() {
        #expect(Weekday.ordered(.monday).first == .monday)
        #expect(Weekday.ordered(.sunday).first == .sunday)
        #expect(Weekday.ordered(.sunday).last == .saturday)
        #expect(Weekday.ordered(.sunday).count == 7)
    }
}

@Suite struct MonthTests {
    @Test func octoberOnMondayWeeks() {
        let g = monthGrid("2026-10-15", .monday)
        #expect(g.count == 35)
        #expect(g.prefix(3).allSatisfy { $0 == nil })
        #expect(g[3] == "2026-10-01")
        #expect(g[33] == "2026-10-31")
        #expect(g[34] == nil)
    }

    @Test func octoberOnSundayWeeks() {
        let g = monthGrid("2026-10-15", .sunday)
        #expect(g.count == 35)
        #expect(g.prefix(4).allSatisfy { $0 == nil })
        #expect(g[4] == "2026-10-01")
        #expect(g[34] == "2026-10-31")
    }

    @Test func monthHelpers() {
        #expect(monthStart("2026-11-05") == "2026-11-01")
        #expect(daysInMonth("2026-02-10") == 28)
        #expect(daysInMonth("2028-02-10") == 29)
        #expect(monthDays("2026-11-05").count == 30)
        #expect(monthDays("2026-11-05").first == "2026-11-01")
        #expect(addMonths(1, to: "2026-01-31") == "2026-02-01")
        #expect(addMonths(-1, to: "2026-03-15") == "2026-02-01")
        #expect(addMonths(2, to: "2026-11-05") == "2027-01-01")
    }

    @Test func titles() {
        let t = monthTitle("2026-11-05")
        #expect(t.month == "November")
        #expect(t.year == "2026")
        #expect(dayNumber("2026-11-05") == "5")
        #expect(dayNumber("2026-11-25") == "25")
    }
}

@Suite struct PagingTests {
    @Test func boundsNeverPassToday() {
        let b = calendarBounds([], .month, .monday, today: "2026-11-05")
        #expect(b == "2026-11-01"..."2026-11-01")
        let c = calendarBounds(["2026-08-20"], .month, .monday, today: "2026-11-05")
        #expect(c.lowerBound == "2026-08-01")
        #expect(c.upperBound == "2026-11-01")
        let d = calendarBounds(["2027-01-10"], .month, .monday, today: "2026-11-05")
        #expect(d == "2026-11-01"..."2026-11-01")
    }

    @Test func steps() {
        #expect(calendarStep("2026-11-05", .month, .monday, by: -1) == "2026-10-01")
        #expect(calendarStep("2026-11-05", .week, .monday, by: 1) == "2026-11-09")
        #expect(calendarStep("2026-11-05", .week, .sunday, by: -1) == "2026-10-25")
    }

    @Test func dayArithmetic() {
        #expect(addDays(1, to: "2026-10-31") == "2026-11-01")
        #expect(addDays(-5, to: "2026-11-05") == "2026-10-31")
        #expect(daysBetween("2026-11-01", "2026-11-05") == 4)
        #expect(daysBetween("2026-11-05", "2026-11-01") == -4)
        #expect(dayString(dayDate("2026-02-28")) == "2026-02-28")
    }

    @Test func relativeWords() {
        #expect(relativeDay("2026-11-05", today: "2026-11-05") == "Today")
        #expect(relativeDay("2026-11-04", today: "2026-11-05") == "Yesterday")
        #expect(relativeDay("2026-11-06", today: "2026-11-05") == "Tomorrow")
        #expect(relativeDay("2026-11-01", today: "2026-11-05") == nil)
    }
}
