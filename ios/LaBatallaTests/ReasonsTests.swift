import Foundation
import Testing
@testable import LaBatalla

// Reasons: which set a check-in draws from, how they are counted, and which chips are offered.

@Suite struct ReasonsTests {
    @Test func setsFollowTheKindAndTheAnswer() {
        #expect(ReasonSet.of(.time, done: true) == .timeYes)
        #expect(ReasonSet.of(.time, done: false) == .timeNo)
        #expect(ReasonSet.of(.adherence, done: false) == .ruleNo)
        #expect(ReasonSet.of(.work, done: true) == .workYes)
        #expect(ReasonSet.timeNo.defaults.contains(NEXT_STEP_REASON))
        for set in ReasonSet.allCases { #expect(!set.defaults.isEmpty) }
    }

    @Test func countsMostUsedFirst() {
        let counts = reasonCounts([["Tired", "No time"], ["Tired"], ["Family", "Family"], ["", "  "]])
        #expect(counts.map(\.reason) == ["Tired", "Family", "No time"])
        #expect(counts.map(\.count) == [2, 1, 1])
        #expect(reasonCounts([]).isEmpty)
    }

    @Test func ownReasonsComeFirst() {
        let used = [["Gym closed"], ["Gym closed"], ["Tired"], ["A sentence that is far too long to be a chip"]]
        let chips = reasonChoices(.timeNo, used: used)
        #expect(chips.prefix(3) == ["Gym closed", "Tired", "No time"])
        #expect(!chips.contains("A sentence that is far too long to be a chip"))
        #expect(chips.filter { $0 == "Tired" }.count == 1)
        #expect(chips.count <= 14)
        #expect(reasonChoices(.sleep, used: [], limit: 3).count == 3)
    }
}
