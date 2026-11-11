import Foundation

// Days are "yyyy-MM-dd" strings everywhere in the app: they sort as text, encode as they are,
// and never shift when the phone changes time zone. Dates are only made when drawing.

private let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private let gregorian = Calendar(identifier: .gregorian)

func today() -> String { dayFormatter.string(from: Date()) }
func dayString(_ d: Date) -> String { dayFormatter.string(from: d) }
func dayDate(_ s: String) -> Date { dayFormatter.date(from: s) ?? Date() }

/// Twelve lowercase letters and digits: ids for goals and marks.
func uid() -> String {
    let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    return String((0..<12).map { _ in chars.randomElement()! })
}

func addDays(_ n: Int, to day: String) -> String {
    dayString(gregorian.date(byAdding: .day, value: n, to: dayDate(day)) ?? dayDate(day))
}

/// Days from `a` to `b`: positive when `b` is later.
func daysBetween(_ a: String, _ b: String) -> Int {
    let da = gregorian.startOfDay(for: dayDate(a)), db = gregorian.startOfDay(for: dayDate(b))
    return gregorian.dateComponents([.day], from: da, to: db).day ?? 0
}

/// Monday 1 ... Sunday 7.
func isoWeekday(_ day: String) -> Int { (gregorian.component(.weekday, from: dayDate(day)) + 5) % 7 + 1 }

/// Days since the week began: 0 on the first day of the week, 6 on the last.
func weekOffset(_ day: String, _ start: WeekStart) -> Int {
    let iso = isoWeekday(day)
    return start == .monday ? iso - 1 : iso % 7
}

/// The first day of the week holding `day`.
func weekStart(_ day: String, _ start: WeekStart) -> String { addDays(-weekOffset(day, start), to: day) }

/// The seven days of the week holding `day`, in order.
func weekDays(_ day: String, _ start: WeekStart) -> [String] {
    let s = weekStart(day, start)
    return (0..<7).map { addDays($0, to: s) }
}

/// The 1st of the month holding `day`.
func monthStart(_ day: String) -> String { String(day.prefix(8)) + "01" }

func daysInMonth(_ day: String) -> Int {
    gregorian.range(of: .day, in: .month, for: dayDate(monthStart(day)))?.count ?? 30
}

/// Every day of the month holding `day`.
func monthDays(_ day: String) -> [String] {
    let first = monthStart(day)
    return (0..<daysInMonth(first)).map { addDays($0, to: first) }
}

/// The month holding `day` in rows of seven; nil pads the first and last rows.
func monthGrid(_ day: String, _ start: WeekStart) -> [String?] {
    let first = monthStart(day)
    var cells: [String?] = Array(repeating: nil, count: weekOffset(first, start))
    for d in monthDays(first) { cells.append(d) }
    while cells.count % 7 != 0 { cells.append(nil) }
    return cells
}

/// The 1st of the month `n` months away from the one holding `day`.
func addMonths(_ n: Int, to day: String) -> String {
    let first = dayDate(monthStart(day))
    return dayString(gregorian.date(byAdding: .month, value: n, to: first) ?? first)
}

enum CalendarMode: String, CaseIterable, Identifiable {
    case month, week
    var id: String { rawValue }
    var label: String { self == .month ? "Month" : "Week" }
}

/// The start of the month or week holding `day`.
func periodStart(_ day: String, _ mode: CalendarMode, _ start: WeekStart) -> String {
    mode == .month ? monthStart(day) : weekStart(day, start)
}

/// The start of the month or week `steps` away from the one holding `day`.
func calendarStep(_ day: String, _ mode: CalendarMode, _ start: WeekStart, by steps: Int) -> String {
    switch mode {
    case .month: return addMonths(steps, to: day)
    case .week: return addDays(7 * steps, to: weekStart(day, start))
    }
}

/// How far back the calendar pages: from the first day anything was marked (or a goal was made)
/// to today. Never into the future: tomorrow is not a battle yet.
func calendarBounds(_ days: [String], _ mode: CalendarMode, _ start: WeekStart, today t: String = today()) -> ClosedRange<String> {
    let last = periodStart(t, mode, start)
    let first = days.min().map { min(periodStart($0, mode, start), last) } ?? last
    return first...last
}

/// The first days of every week from the one holding `first` to the one holding `last`, oldest first.
func weekStarts(from first: String, to last: String, _ start: WeekStart) -> [String] {
    var out: [String] = []
    var w = weekStart(min(first, last), start)
    let end = weekStart(last, start)
    while w <= end { out.append(w); w = addDays(7, to: w) }
    return out
}

// MARK: Words

/// "5" for 2026-11-05.
func dayNumber(_ day: String) -> String { String(Int(day.suffix(2)) ?? 0) }

/// "Th", "Fr": the heads of the calendar's columns.
func weekdayLetters(_ day: String) -> String {
    String(dayDate(day).formatted(.dateTime.weekday(.abbreviated)).prefix(2))
}

/// "November" and "2026" for the month holding `day`.
func monthTitle(_ day: String) -> (month: String, year: String) {
    let d = dayDate(day)
    return (d.formatted(.dateTime.month(.wide)), d.formatted(.dateTime.year()))
}

/// "Nov 2026".
func monthShort(_ day: String) -> String { dayDate(day).formatted(.dateTime.month(.abbreviated).year()) }

private let monthDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "MMM d"
    return f
}()

/// "Oct 19 - 25", "Oct 26 - Nov 1", or "Dec 28 - Jan 3" for the week holding `day`.
func weekTitle(_ day: String, _ start: WeekStart) -> String {
    let days = weekDays(day, start)
    let a = dayDate(days[0]), b = dayDate(days[6])
    let sameMonth = days[0].prefix(7) == days[6].prefix(7)
    let end = sameMonth ? dayNumber(days[6]) : monthDayFormatter.string(from: b)
    return "\(monthDayFormatter.string(from: a)) - \(end)"
}

/// "This week", "Last week", or the dates: "Oct 12 - 18".
func weekLabel(_ day: String, _ start: WeekStart, today t: String = today()) -> String {
    let now = weekStart(t, start)
    let s = weekStart(day, start)
    if s == now { return "This week" }
    if s == addDays(-7, to: now) { return "Last week" }
    return weekTitle(s, start)
}

/// "Thursday, November 5".
func longDayTitle(_ day: String) -> String {
    dayDate(day).formatted(.dateTime.weekday(.wide).month(.wide).day())
}

/// "Thu, Nov 5".
func shortDayTitle(_ day: String) -> String {
    dayDate(day).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
}

/// "Today", "Yesterday", "Tomorrow", or nil for any other day.
func relativeDay(_ day: String, today t: String = today()) -> String? {
    switch daysBetween(day, t) {
    case 0: return "Today"
    case 1: return "Yesterday"
    case -1: return "Tomorrow"
    default: return nil
    }
}

// MARK: Months and spans

/// "2026-11" for any day in November 2026.
func monthKey(_ day: String) -> String { String(day.prefix(7)) }

/// The last day of the month holding `day`.
func monthEnd(_ day: String) -> String { addDays(daysInMonth(day) - 1, to: monthStart(day)) }

/// "November" for any day in it.
func monthName(_ day: String) -> String { monthTitle(day).month }

/// The same day of the month `n` months on, or that month's last day when it is shorter.
func addMonthsKeepingDay(_ n: Int, to day: String) -> String {
    dayString(gregorian.date(byAdding: .month, value: n, to: dayDate(day)) ?? dayDate(day))
}

/// Every day from `a` through `b`, in order. Empty when `b` is before `a`.
func daysFrom(_ a: String, through b: String) -> [String] {
    guard a <= b else { return [] }
    return (0...daysBetween(a, b)).map { addDays($0, to: a) }
}

private let mediumDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "MMM d, yyyy"
    return f
}()

/// "Jun 21, 2027".
func mediumDay(_ day: String) -> String { mediumDayFormatter.string(from: dayDate(day)) }

/// "Jun 21" this year, "Jun 21, 2027" in any other.
func briefDay(_ day: String, today t: String = today()) -> String {
    day.prefix(4) == t.prefix(4) ? monthDayFormatter.string(from: dayDate(day)) : mediumDay(day)
}

/// "in 3 days", "in 7 months", "12 days ago", "today": how far `day` is from today, in the
/// largest unit that reads well.
func distanceWords(_ day: String, today t: String = today()) -> String {
    let d = daysBetween(t, day)
    if d == 0 { return "today" }
    let n = abs(d)
    let words: String
    if n < 14 { words = n == 1 ? "1 day" : "\(n) days" }
    else if n < 60 { words = "\(n / 7) weeks" }
    else if n < 730 { words = "\(Int((Double(n) / 30.44).rounded())) months" }
    else { words = String(format: "%.1f years", Double(n) / 365.25) }
    return d > 0 ? "in \(words)" : "\(words) ago"
}
