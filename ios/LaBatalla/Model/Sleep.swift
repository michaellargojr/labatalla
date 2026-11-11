import Foundation

// Sleep, worked out from the nightly logs. Everyone needs a different amount; the baseline is
// the person's own, and every night is read against the baseline it was logged under.

/// "10:30 PM" for a minute of the day.
func clockLabel(_ minute: Int) -> String {
    let m = clampMinute(minute)
    let h24 = m / 60, mm = m % 60
    let h12 = h24 % 12 == 0 ? 12 : h24 % 12
    return "\(h12):\(mm < 10 ? "0" : "")\(mm) \(h24 < 12 ? "AM" : "PM")"
}

/// "7h 15m", "8h", "45m", "0m". A negative length keeps its sign.
func durationLabel(_ minutes: Int) -> String {
    let m = abs(minutes)
    let h = m / 60, r = m % 60
    let sign = minutes < 0 ? "-" : ""
    if h == 0 { return "\(sign)\(r)m" }
    if r == 0 { return "\(sign)\(h)h" }
    return "\(sign)\(h)h \(r)m"
}

/// Minutes from going to sleep to waking, across midnight when it has to be.
func sleepSpan(bed: Int, wake: Int) -> Int { clampMinute(wake - bed) }

/// How far `minute` is from `target` around the clock: positive is later. Within -720..<720.
func clockOffset(_ minute: Int, from target: Int) -> Int {
    let d = clampMinute(minute - target)
    return d >= 720 ? d - 1440 : d
}

/// To the nearest step: 15 minutes unless told otherwise.
func roundMinutes(_ m: Int, to step: Int = 15) -> Int {
    guard step > 0 else { return m }
    return Int((Double(m) / Double(step)).rounded()) * step
}

/// A night counts as short when it ends this far under the need, or further.
let SHORT_NIGHT_MINUTES = 45

struct SleepStats: Equatable {
    var nights: Int
    var avgSlept: Int
    var avgNeed: Int
    var avgQuality: Double
    /// Need minus slept, summed. Positive is sleep owed.
    var totalDebt: Int
    /// Minutes past the target bedtime, on average. Negative is earlier.
    var avgBedOffset: Int
    var avgWakeOffset: Int
    /// The target bedtime of the latest night, for words.
    var targetBed: Int
    var targetWake: Int
    var shortNights: Int

    var avgDebt: Int { nights == 0 ? 0 : totalDebt / nights }
    var avgBed: Int { clampMinute(targetBed + avgBedOffset) }
    var avgWake: Int { clampMinute(targetWake + avgWakeOffset) }
}

/// The nights from `from` through `to`, oldest first, one per day (the latest entry wins).
func sleepLogs(_ logs: [SleepLog], from: String, to: String) -> [SleepLog] {
    var byDay: [String: SleepLog] = [:]
    for l in logs where l.day >= from && l.day <= to {
        if let old = byDay[l.day], old.at > l.at { continue }
        byDay[l.day] = l
    }
    return byDay.values.sorted { $0.day < $1.day }
}

func sleepStats(_ logs: [SleepLog]) -> SleepStats? {
    guard let last = logs.max(by: { $0.day < $1.day }) else { return nil }
    let n = logs.count
    return SleepStats(
        nights: n,
        avgSlept: logs.reduce(0) { $0 + $1.sleptMinutes } / n,
        avgNeed: logs.reduce(0) { $0 + $1.needMinutes } / n,
        avgQuality: Double(logs.reduce(0) { $0 + $1.quality }) / Double(n),
        totalDebt: logs.reduce(0) { $0 + $1.debt },
        avgBedOffset: logs.reduce(0) { $0 + clockOffset($1.bedMinute, from: $1.targetBedMinute) } / n,
        avgWakeOffset: logs.reduce(0) { $0 + clockOffset($1.wakeMinute, from: $1.targetWakeMinute) } / n,
        targetBed: last.targetBedMinute,
        targetWake: last.targetWakeMinute,
        shortNights: logs.filter { $0.debt >= SHORT_NIGHT_MINUTES }.count)
}

/// The night that ended on `day`, if it was logged.
func sleepLog(_ logs: [SleepLog], on day: String) -> SleepLog? {
    logs.filter { $0.day == day }.max { $0.at < $1.at }
}

/// "7.4" for an average quality.
func oneDecimal(_ v: Double) -> String { String(format: "%.1f", v) }
