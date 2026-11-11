import Foundation

// The questions a goal's setup leaves open. The setup asks what a good closer would ask: how will
// you know it is done, when, what does it take, do you know how, what does it cost. Whatever the
// answers do not add up to is listed here, plainly, as a question still open. Never as a fault.

struct OpenQuestion: Identifiable, Equatable {
    var id: String
    var goalId: String
    var title: String
    var detail: String
}

/// A path rated this or lower is not clear yet.
let UNCLEAR_PATH = 4

func openQuestions(_ g: Goal, goals: [Goal], duels: [Duel] = [], today t: String = today()) -> [OpenQuestion] {
    guard !g.isArchived, !g.isAchieved else { return [] }
    var out: [OpenQuestion] = []
    func ask(_ key: String, _ title: String, _ detail: String) {
        out.append(OpenQuestion(id: "\(g.id).\(key)", goalId: g.id, title: title, detail: detail))
    }

    let finishable = g.kind == .time || g.kind == .outcome
    if finishable && g.finishLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        ask("finish", "No finish line yet", "How will you know it is done? Until that is written down, it cannot be finished.")
    }
    if g.importance == 0 {
        ask("importance", "Importance not rated", "How important is it for you to achieve this goal, 1 to 10?")
    } else if g.importance <= 4 {
        ask("low", "Rated \(g.importance) of 10", "That is low enough to ask whether it belongs on the list right now.")
    }

    let dates = [g.soonest, g.reasonable, g.conservative].compactMap { $0 }
    if finishable || !dates.isEmpty {
        if dates.count < 3 {
            ask("dates", dates.isEmpty ? "No dates yet" : "Not all three dates are set",
                "The soonest it could be done, a reasonable day, and a very conservative one.")
        } else if let a = g.soonest, let b = g.reasonable, let c = g.conservative {
            if a > b || b > c {
                ask("order", "The three dates are out of order", "Soonest comes first, then reasonable, then conservative.")
            } else if a == c {
                ask("same", "One date, three times", "Soonest, reasonable and conservative are the same day. That is a deadline, not an estimate.")
            }
        }
    }
    if let r = g.reasonable, r < t {
        ask("passed", "The reasonable date has passed", "It was \(briefDay(r, today: t)). Move it, or mark the goal achieved.")
    }

    if g.kind == .time {
        let plan = g.plan
        if g.sessionMinutes == 0 {
            ask("session", "No session length yet", "How long is one session? The weekly hours come from it.")
        }
        if g.totalHours > 0, let r = g.reasonable, r > t, g.sessionMinutes > 0 {
            let reach = plan.hoursBy(r, from: t)
            if reach < g.totalHours * 0.9 {
                ask("reach", "The plan does not reach the hours",
                    "\(g.schedule.label) at \(durationLabel(g.sessionMinutes)) comes to \(hoursLabel(reach)) by \(briefDay(r, today: t)). You estimated \(hoursLabel(g.totalHours)).")
            }
            if let need = plan.sessionMinutesNeeded(from: t, by: r), need > 4 * 60 {
                ask("long", "Sessions of \(durationLabel(roundMinutes(need)))",
                    "That is what \(hoursLabel(g.totalHours)) by \(briefDay(r, today: t)) takes at \(g.schedule.label.lowercased()).")
            }
        }
    }

    if g.kind == .work {
        let w = g.workSetup
        if w.targetIncome <= 0 {
            ask("income", "No income number yet", "What do you want this to pay a month, six months from now?")
        }
        if !w.paysPerResult && w.basePerMonth <= 0 && w.hourlyRate <= 0 {
            ask("pay", "How it pays is not set", "Fixed pay, an hourly rate, or money per result. Without one, money per hour cannot be worked out.")
        }
    }

    if g.kind != .adherence {
        if g.clarity == 0 {
            ask("path", "Path not rated", "How clear is the path from here to done, 1 to 10?")
        } else if g.clarity <= UNCLEAR_PATH {
            ask("unclear", "The path is not clear yet",
                "You rated it \(g.clarity) of 10. The first step may be a goal of its own: find out how. The Oracle can help with that.")
        }
    }

    for other in goals where g.conflicts.contains(other.id) && !other.isArchived {
        if let d = duels.last(where: { $0.isBetween(g.id, other.id) }) {
            let winner = d.winner == g.id ? g.name : other.name
            ask("conflict.\(other.id)", "Pulls against \(other.name)", "When they collide, you chose \(winner).")
        } else {
            ask("conflict.\(other.id)", "Pulls against \(other.name)", "You marked these two as competing. Which one wins when they collide?")
        }
    }
    return out
}

/// Where the 168 hours of a week go if every plan is kept, in minutes.
struct TimeBudget: Equatable {
    var sleep: Int
    var work: Int
    var goals: Int

    static let week = 7 * 24 * 60
    var planned: Int { sleep + work + goals }
    /// What is left for everything else: eating, people, getting around, rest.
    var left: Int { TimeBudget.week - planned }
    var leftPerDay: Int { left / 7 }
}

func timeBudget(goals: [Goal], sleepNeed: Int, today t: String = today()) -> TimeBudget {
    let active = goals.filter { $0.isActive(on: t) }
    let work = active.filter { $0.kind == .work }
        .reduce(0) { $0 + Int((Double($1.schedule.daysPerWeek) * $1.workSetup.requiredHours * 60).rounded()) }
    let hours = active.filter { $0.kind == .time }.reduce(0) { $0 + $1.weeklyMinutes }
    return TimeBudget(sleep: sleepNeed * 7, work: work, goals: hours)
}

/// The horizon a reasonable date falls in: within six months is the short term.
func horizon(for reasonable: String, today t: String = today()) -> Horizon {
    reasonable <= addMonthsKeepingDay(6, to: t) ? .sixMonths : .sixYears
}
