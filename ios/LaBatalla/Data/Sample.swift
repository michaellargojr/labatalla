#if DEBUG
import Foundation

/// Five goals and eight weeks of marks, so a fresh install or a simulator shows a calendar with
/// color straight away. Debug builds only: Settings > Data > Fill with sample days. The marks
/// come from a fixed seed, so every run draws the same calendar (handy for screenshots).
extension AppStore {
    func loadSample(today t: String = today()) {
        var seed: UInt64 = 0x5EED
        func chance(_ p: Double) -> Bool {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31) < p
        }
        let start = addDays(-7 * 8, to: weekStart(t, settings.weekStart))
        let items: [(Goal, Double)] = [
            (Goal(name: "Move my body", color: .royal, horizon: .sixYears, symbol: "figure.run", schedule: .daily,
                  why: "The body I have in six years is built this week.", createdAt: start), 0.7),
            (Goal(name: "Read 10 pages", color: .gold, horizon: .sixYears, symbol: "book.fill", schedule: .daily,
                  why: "Ten pages a day is a dozen books a year.", createdAt: start), 0.55),
            (Goal(name: "Call family", color: .coral, horizon: .sixYears, symbol: "phone.fill", schedule: .timesPerWeek(2),
                  why: "They will not be here forever.", createdAt: start), 0.3),
            (Goal(name: "Inbox to zero", color: .mint, horizon: .sixMonths, symbol: "envelope.fill", schedule: .weekdays(Weekday.workdays),
                  why: "Nothing waiting on me overnight.", createdAt: start), 0.75),
            (Goal(name: "Drink water", color: .sky, horizon: .sixMonths, symbol: "drop.fill", schedule: .daily,
                  why: "A full bottle before noon.", createdAt: start), 0.8),
        ]
        for (g, _) in items { put(g) }
        var d = start
        while d < t {
            for (g, p) in items where g.schedule.includes(d) && chance(p) {
                marks.append(Mark(goalId: g.id, day: d, at: dayDate(d).timeIntervalSince1970 * 1000 + 72_000_000))
            }
            d = addDays(1, to: d)
        }
        saveNow()
    }
}
#endif
