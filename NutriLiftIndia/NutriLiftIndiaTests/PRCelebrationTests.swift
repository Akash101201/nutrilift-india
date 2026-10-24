import XCTest
@testable import NutriLiftIndia

final class PRCelebrationTests: XCTestCase {
    private func makeSet(_ kg: Double, reps: Int = 5, exercise: String = "ex_bench") -> WorkoutSet {
        WorkoutSet(
            exerciseSeedId: exercise,
            exerciseName: "Bench",
            muscleGroup: .chest,
            setNumber: 1,
            weightKg: kg,
            reps: reps
        )
    }

    private func finishedSession(withSet set: WorkoutSet) -> WorkoutSession {
        let session = WorkoutSession(name: "Old")
        session.finishedAt = Date().addingTimeInterval(-86400)
        session.sets.append(set)
        return session
    }

    func testBeatingPriorBestIsAPR() {
        let old = finishedSession(withSet: makeSet(60))
        XCTAssertTrue(PRDetector.isNewPR(set: makeSet(70), priorSessions: [old], earlierSetsThisSession: []))
    }

    func testFirstEverSetForAnExerciseIsNotAPR() {
        XCTAssertFalse(PRDetector.isNewPR(set: makeSet(70), priorSessions: [], earlierSetsThisSession: []))
        let otherExercise = finishedSession(withSet: makeSet(60, exercise: "ex_squat"))
        XCTAssertFalse(PRDetector.isNewPR(set: makeSet(70), priorSessions: [otherExercise], earlierSetsThisSession: []))
    }

    func testDoesNotRepeatThePRForLighterSetsInTheSameSession() {
        let old = finishedSession(withSet: makeSet(60))
        let first = makeSet(70)
        let second = makeSet(65)
        XCTAssertFalse(PRDetector.isNewPR(set: second, priorSessions: [old], earlierSetsThisSession: [first]))
    }

    func testBeatingAnEarlierSetThisSessionIsAPRAgain() {
        let old = finishedSession(withSet: makeSet(60))
        let first = makeSet(70)
        let heavier = makeSet(75)
        XCTAssertTrue(PRDetector.isNewPR(set: heavier, priorSessions: [old], earlierSetsThisSession: [first]))
    }

    func testEqualToPriorBestIsNotAPR() {
        let old = finishedSession(withSet: makeSet(60))
        XCTAssertFalse(PRDetector.isNewPR(set: makeSet(60), priorSessions: [old], earlierSetsThisSession: []))
    }
}
