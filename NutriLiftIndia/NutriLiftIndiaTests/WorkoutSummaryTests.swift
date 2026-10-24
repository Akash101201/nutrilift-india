import XCTest
@testable import NutriLiftIndia

final class WorkoutSummaryTests: XCTestCase {
    private func sets(_ pairs: [(Double, Int)]) -> [LoggedSet] {
        pairs.map { LoggedSet(weightKg: $0.0, reps: $0.1) }
    }

    private func log(
        _ name: String,
        _ pairs: [(Double, Int)],
        equipment: EquipmentType? = .barbell,
        previousBest: Double? = nil,
        previous: [(Double, Int)]? = nil
    ) -> ExerciseLog {
        ExerciseLog(
            exerciseSeedId: name.lowercased(),
            name: name,
            muscle: .chest,
            equipment: equipment,
            sets: sets(pairs),
            previousBestE1RM: previousBest,
            previousSets: previous.map(sets)
        )
    }

    /// Bench is slightly up on volume but not a record; Squat is new.
    private var calmRecap: WorkoutRecap {
        WorkoutRecap(
            name: "Push Day",
            durationMinutes: 45,
            exercises: [
                log("Bench Press", [(60, 8), (60, 8), (60, 7)], previousBest: 80, previous: [(60, 8), (60, 8), (60, 6)]),
                log("Squat", [(100, 5), (100, 5), (100, 5)]),
            ],
            workoutsThisWeek: 2
        )
    }

    /// Bench beats the old best.
    private var prRecap: WorkoutRecap {
        WorkoutRecap(
            name: "Push Day",
            durationMinutes: 45,
            exercises: [log("Bench Press", [(60, 8), (60, 8), (60, 7)], previousBest: 70, previous: [(57.5, 8)])],
            workoutsThisWeek: 1
        )
    }

    // MARK: Records

    func testPRRule() {
        // 60 x 8 -> e1RM 76
        XCTAssertFalse(log("A", [(60, 8)], previousBest: nil).isPR, "First time is a baseline, not a record")
        XCTAssertTrue(log("A", [(60, 8)], previousBest: 70).isPR)
        XCTAssertFalse(log("A", [(60, 8)], previousBest: 76).isPR, "Equal is not a record")
        XCTAssertFalse(log("A", [(60, 8)], previousBest: 90).isPR)
        XCTAssertTrue(log("A", [(60, 8)], previousBest: nil).isFirstTime)
    }

    func testRecapTotals() {
        let recap = calmRecap
        XCTAssertEqual(recap.totalSets, 6)
        let expectedVolume: Double = 2880   // 480 + 480 + 420 bench, 1500 squat
        XCTAssertEqual(recap.totalVolume, expectedVolume, accuracy: 0.001)
        XCTAssertTrue(recap.prExercises.isEmpty)
        XCTAssertEqual(prRecap.prExercises.map(\.name), ["Bench Press"])
    }

    // MARK: Progression advice

    func testAddWeightWhenEverySetHitsTenReps() {
        let tip = ProgressionAdvisor.suggestion(for: log("Bench Press", [(60, 10), (60, 10), (60, 11)]))
        XCTAssertNotNil(tip)
        XCTAssertTrue(tip?.contains("62.5") == true, "Barbell adds 2.5 kg. Got \(tip ?? "nil")")
    }

    func testDumbbellsAddTwoKilos() {
        let tip = ProgressionAdvisor.suggestion(for: log("Curl", [(20, 12), (20, 12)], equipment: .dumbbell))
        XCTAssertTrue(tip?.contains("22") == true, "Got \(tip ?? "nil")")
    }

    func testAddRepsBeforeWeightInTheMiddleRange() {
        // Best set is 60 x 8; the weakest set at 60 kg is 7 reps, so aim for 8.
        let tip = ProgressionAdvisor.suggestion(for: log("Bench Press", [(60, 8), (60, 7)]))
        XCTAssertTrue(tip?.contains("Stay at 60 kg") == true, "Got \(tip ?? "nil")")
        XCTAssertTrue(tip?.contains("8 reps") == true, "Got \(tip ?? "nil")")
    }

    func testHeavyLowRepWorkIsKeptAndPolished() {
        let tip = ProgressionAdvisor.suggestion(for: log("Squat", [(100, 4), (100, 4)]))
        XCTAssertTrue(tip?.contains("Keep 100 kg") == true, "Got \(tip ?? "nil")")
    }

    func testBodyweightAddsReps() {
        let tip = ProgressionAdvisor.suggestion(for: log("Push-up", [(0, 15), (0, 12)], equipment: .bodyweight))
        XCTAssertTrue(tip?.contains("reps") == true, "Got \(tip ?? "nil")")
    }

    func testWeightTextDropsUselessDecimals() {
        XCTAssertEqual(WorkoutSummary.kgText(60), "60")
        XCTAssertEqual(WorkoutSummary.kgText(62.5), "62.5")
    }

    // MARK: Facts and text

    func testFactsDescribeTheWorkout() {
        let joined = WorkoutSummary.facts(calmRecap).joined(separator: "\n")
        XCTAssertTrue(joined.contains("Push Day"))
        XCTAssertTrue(joined.contains("45 minutes"))
        XCTAssertTrue(joined.contains("6 sets"))
        XCTAssertTrue(joined.contains("2880 kg"))
        XCTAssertTrue(joined.contains("60 kg higher than last time"), "Bench volume is up by 60 kg")
        XCTAssertTrue(joined.contains("First time logged"), "Squat is new")
        XCTAssertTrue(joined.contains("No new personal records"))
    }

    func testFactsMentionRecords() {
        let joined = WorkoutSummary.facts(prRecap).joined(separator: "\n")
        XCTAssertTrue(joined.contains("New personal records on: Bench Press"))
    }

    func testFallbackAppreciatesAndAdvises() {
        let text = WorkoutSummary.fallbackText(prRecap)
        XCTAssertTrue(text.contains("Bench Press"))
        XCTAssertTrue(text.contains("personal record"))
        XCTAssertTrue(text.contains("To keep improving"))
        let calm = WorkoutSummary.fallbackText(calmRecap)
        XCTAssertTrue(calm.contains("Showing up"))
    }

    func testFallbackNeverUsesNumbersOutsideTheFacts() {
        for recap in [calmRecap, prRecap] {
            let facts = WorkoutSummary.facts(recap)
            XCTAssertTrue(Grounding.isGrounded(WorkoutSummary.fallbackText(recap), facts: facts))
        }
    }

    func testInventedNumbersAreRejected() {
        let facts = WorkoutSummary.facts(calmRecap)
        XCTAssertFalse(Grounding.isGrounded("You lifted 5000 kg today!", facts: facts))
        XCTAssertTrue(Grounding.isGrounded("You did 6 sets and moved 2880 kg in 45 minutes.", facts: facts))
    }

    func testPromptCarriesFactsAndRules() {
        let prompt = WorkoutSummary.prompt(calmRecap)
        XCTAssertTrue(prompt.contains("2880"))
        XCTAssertTrue(WorkoutSummary.instructions.contains("ONLY the facts"))
    }
}
