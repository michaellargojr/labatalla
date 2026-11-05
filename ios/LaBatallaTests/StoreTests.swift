import Foundation
import Testing
@testable import LaBatalla

// The store: marking, goals, order, and the file round trip. Each test gets its own file.

private func tempURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("labatalla-test-\(uid()).json")
}

private func freshStore(_ url: URL = tempURL()) -> AppStore {
    let s = AppStore(fileURL: url)
    s.load()
    return s
}

@Suite struct MarkingTests {
    @Test func toggleMarksAndUnmarks() {
        let s = freshStore()
        let g = Goal(name: "Gym")
        s.put(g)
        #expect(!s.isDone(g.id, on: "2026-11-05"))
        #expect(s.toggle(g.id, on: "2026-11-05"))
        #expect(s.isDone(g.id, on: "2026-11-05"))
        #expect(s.marks.count == 1)
        #expect(!s.toggle(g.id, on: "2026-11-05"))
        #expect(s.marks.isEmpty)
        s.setDone(g.id, on: "2026-11-04", true)
        s.setDone(g.id, on: "2026-11-04", true)
        #expect(s.marks.count == 1)
        s.setDone(g.id, on: "2026-11-04", false)
        #expect(s.marks.isEmpty)
    }

    @Test func notesLiveOnMarks() {
        let s = freshStore()
        let g = Goal(name: "Read")
        s.put(g)
        s.setNote(g.id, on: "2026-11-05", "nothing yet")   // no mark: nothing to note
        #expect(s.mark(g.id, on: "2026-11-05") == nil)
        s.toggle(g.id, on: "2026-11-05")
        s.setNote(g.id, on: "2026-11-05", "  chapter 4  ")
        #expect(s.mark(g.id, on: "2026-11-05")?.note == "chapter 4")
        s.setNote(g.id, on: "2026-11-05", "   ")
        #expect(s.mark(g.id, on: "2026-11-05")?.note == nil)
    }

    @Test func summariesComeFromTheStore() {
        let s = freshStore()
        s.update { $0.weekStart = .monday }
        let gym = Goal(name: "Gym", color: .royal, horizon: .sixYears, createdAt: "2026-10-01")
        let inbox = Goal(name: "Inbox", color: .mint, horizon: .sixMonths, schedule: .weekdays(Weekday.workdays), createdAt: "2026-10-01")
        s.put(gym)
        s.put(inbox)
        s.toggle(gym.id, on: "2026-11-05")
        let d = s.summary("2026-11-05")
        #expect(d.colors == [.royal])
        #expect(d.badges == [.longTerm])
        #expect(s.summaries(["2026-11-05", "2026-11-06"])["2026-11-06"]?.isColored == false)
        #expect(s.firstDay == "2026-10-01")
    }
}

@Suite struct GoalStoreTests {
    @Test func putOrdersAndReplaces() {
        let s = freshStore()
        let a = Goal(name: "A")
        let b = Goal(name: "B")
        s.put(a)
        s.put(b)
        #expect(s.activeGoals.map(\.name) == ["A", "B"])
        #expect(s.activeGoals.map(\.order) == [0, 1])
        var a2 = a
        a2.name = "A2"
        s.put(a2)
        #expect(s.goals.count == 2)
        #expect(s.goal(a.id)?.name == "A2")
        #expect(s.activeGoals.map(\.name) == ["A2", "B"])
    }

    @Test func reorderKeepsTheRest() {
        let s = freshStore()
        let a = Goal(name: "A"), b = Goal(name: "B"), c = Goal(name: "C")
        s.put(a); s.put(b); s.put(c)
        s.reorder([c.id, a.id])
        #expect(s.activeGoals.map(\.name) == ["C", "A", "B"])
    }

    @Test func retireAndBringBack() {
        let s = freshStore()
        let a = Goal(name: "A", createdAt: "2026-10-01")
        s.put(a)
        s.toggle(a.id, on: "2026-11-01")
        s.archive(a.id, on: "2026-11-03")
        #expect(s.activeGoals.isEmpty)
        #expect(s.archivedGoals.map(\.name) == ["A"])
        #expect(s.summary("2026-11-01").colors == [.royal])   // history stays
        #expect(s.summary("2026-11-04").due.isEmpty)
        s.unarchive(a.id)
        #expect(s.activeGoals.map(\.name) == ["A"])
    }

    @Test func deleteTakesTheMarks() {
        let s = freshStore()
        let a = Goal(name: "A"), b = Goal(name: "B")
        s.put(a); s.put(b)
        s.toggle(a.id, on: "2026-11-01")
        s.toggle(b.id, on: "2026-11-01")
        s.delete(a.id)
        #expect(s.goals.map(\.name) == ["B"])
        #expect(s.marks.map(\.goalId) == [b.id])
    }

    @Test func nextColorSkipsUsedOnes() {
        let s = freshStore()
        #expect(s.nextColor == .royal)
        s.put(Goal(name: "A", color: .royal))
        #expect(s.nextColor == .sky)
        s.put(Goal(name: "B", color: .sky))
        s.archive(s.goals[0].id)
        #expect(s.nextColor == .royal)   // a retired goal frees its color
        #expect(s.goals(.sixYears).count == 1)
    }
}

@Suite struct FileTests {
    @Test func savesAndLoadsTheSameThing() throws {
        let url = tempURL()
        let s = freshStore(url)
        let g = Goal(name: "Gym", color: .coral, horizon: .sixYears, symbol: "dumbbell.fill", schedule: .timesPerWeek(3), why: "strong", createdAt: "2026-10-01")
        s.put(g)
        s.toggle(g.id, on: "2026-11-05")
        s.update { $0.weekStart = .sunday; $0.mantra = "Dale." }
        s.saveNow()
        #expect(FileManager.default.fileExists(atPath: url.path))

        let again = freshStore(url)
        #expect(again.goals == s.goals)
        #expect(again.marks == s.marks)
        #expect(again.settings.weekStart == .sunday)
        #expect(again.settings.mantra == "Dale.")
        try? FileManager.default.removeItem(at: url)
    }

    @Test func nothingIsWrittenBeforeLoading() {
        let url = tempURL()
        let s = AppStore(fileURL: url)
        s.put(Goal(name: "Early"))
        s.saveNow()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        s.load()
        #expect(s.goals.count == 1)   // what was put stays in memory; saving starts from here
        s.saveNow()
        #expect(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }

    @Test func restoreAndReset() {
        let s = freshStore()
        let snap = Snapshot(goals: [Goal(name: "From file")], marks: [], settings: Settings())
        s.restore(snap)
        #expect(s.goals.map(\.name) == ["From file"])
        s.reset()
        #expect(s.goals.isEmpty)
        #expect(s.settings == Settings())
    }
}
