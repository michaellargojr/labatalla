import Foundation
import Testing
@testable import LaBatalla

// Sleep: the words for clocks and lengths, spans across midnight, and what a set of nights adds up to.

@Suite struct SleepWordsTests {
    @Test func clocks() {
        #expect(clockLabel(0) == "12:00 AM")
        #expect(clockLabel(12 * 60) == "12:00 PM")
        #expect(clockLabel(22 * 60 + 30) == "10:30 PM")
        #expect(clockLabel(7 * 60 + 5) == "7:05 AM")
        #expect(clockLabel(1440 + 15) == "12:15 AM")   // past midnight wraps
        #expect(clockLabel(-30) == "11:30 PM")
    }

    @Test func lengths() {
        #expect(durationLabel(435) == "7h 15m")
        #expect(durationLabel(480) == "8h")
        #expect(durationLabel(45) == "45m")
        #expect(durationLabel(0) == "0m")
        #expect(durationLabel(-30) == "-30m")
        #expect(oneDecimal(6.5) == "6.5")
    }

    @Test func spansAndOffsets() {
        #expect(sleepSpan(bed: 22 * 60 + 30, wake: 7 * 60) == 510)   // across midnight
        #expect(sleepSpan(bed: 60, wake: 8 * 60) == 420)
        #expect(clockOffset(23 * 60, from: 22 * 60 + 30) == 30)
        #expect(clockOffset(15, from: 22 * 60 + 30) == 105)          // 12:15 AM is 1h 45m past 10:30 PM
        #expect(clockOffset(22 * 60, from: 22 * 60 + 30) == -30)
        #expect(clampMinute(-15) == 1425)
        #expect(clampMinute(1500) == 60)
    }

    @Test func rounding() {
        #expect(roundMinutes(52) == 45)
        #expect(roundMinutes(53) == 60)
        #expect(roundMinutes(7, to: 5) == 5)
        #expect(roundMinutes(8, to: 5) == 10)
    }
}

@Suite struct SleepStatsTests {
    private func night(_ day: String, bed: Int, wake: Int, slept: Int, quality: Int, at: Double = 0) -> SleepLog {
        SleepLog(day: day, bedMinute: bed, wakeMinute: wake, sleptMinutes: slept, quality: quality, at: at,
                 needMinutes: 510, targetBedMinute: 22 * 60 + 30, targetWakeMinute: 7 * 60)
    }

    @Test func statsAddUp() throws {
        let logs = [night("2026-11-09", bed: 22 * 60 + 30, wake: 7 * 60, slept: 480, quality: 8),
                    night("2026-11-10", bed: 23 * 60 + 30, wake: 6 * 60 + 30, slept: 390, quality: 5)]
        let s = try #require(sleepStats(logs))
        #expect(s.nights == 2)
        #expect(s.avgSlept == 435)
        #expect(s.avgNeed == 510)
        #expect(s.avgQuality == 6.5)
        #expect(s.totalDebt == 150)
        #expect(s.avgDebt == 75)
        #expect(s.avgBedOffset == 30)
        #expect(s.avgWakeOffset == -15)
        #expect(s.avgBed == 23 * 60)
        #expect(s.avgWake == 6 * 60 + 45)
        #expect(s.shortNights == 1)
        #expect(sleepStats([]) == nil)
    }

    @Test func oneNightPerDayTheLatestWins() {
        let logs = [night("2026-11-09", bed: 0, wake: 420, slept: 400, quality: 6, at: 1),
                    night("2026-11-09", bed: 0, wake: 420, slept: 450, quality: 7, at: 2),
                    night("2026-11-01", bed: 0, wake: 420, slept: 300, quality: 3, at: 1)]
        let week = sleepLogs(logs, from: "2026-11-05", to: "2026-11-11")
        #expect(week.count == 1)
        #expect(week.first?.sleptMinutes == 450)
        #expect(sleepLog(logs, on: "2026-11-09")?.quality == 7)
        #expect(sleepLog(logs, on: "2026-11-10") == nil)
        #expect(logs[0].debt == 110)
    }

    @Test func dialsRunPastMidnight() {
        let strip = DialValues.clock(around: 22 * 60 + 30)
        #expect(strip.count == 96)
        #expect(strip.first == 630)
        #expect(strip.contains(22 * 60 + 30))
        let late = DialValues.onClock(15, around: 22 * 60 + 30)   // 12:15 AM on a bedtime strip
        #expect(late == 1455)
        #expect(strip.contains(late))
        #expect(clampMinute(late) == 15)
        #expect(DialValues.onClock(7 * 60, around: 7 * 60) == 420)
        #expect(RulerDial.nearest(52, in: [0, 15, 45, 60]) == 45)
        #expect(DialValues.session.first == 5)
        #expect(DialValues.duration(upTo: 12, from: 240).first == 240)
    }
}
