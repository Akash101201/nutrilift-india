import XCTest
import SwiftData
@testable import NutriLiftIndia

@MainActor
final class WorkoutServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: AppSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    private func sets(of session: WorkoutSession, _ seedId: String) -> [WorkoutSet] {
        session.sets.filter { $0.exerciseSeedId == seedId }.sorted { $0.setNumber < $1.setNumber }
    }

    private func add(_ session: WorkoutSession, _ seedId: String = "bench", name: String = "Bench Press") {
        WorkoutService.addExercise(seedId: seedId, name: name, muscle: .chest, to: session, context: context)
    }

    // MARK: Lifecycle

    func testStartEmptyIsInProgressUntilFinished() {
        let session = WorkoutService.startEmpty(context: context)
        XCTAssertEqual(WorkoutService.activeSession(in: context)?.id, session.id)

        add(session)
        sets(of: session, "bench")[0].isCompleted = true
        XCTAssertTrue(WorkoutService.finish(session: session, notes: "felt good", context: context))
        XCTAssertNil(WorkoutService.activeSession(in: context))
        XCTAssertEqual(session.notes, "felt good")
        XCTAssertNotNil(session.finishedAt)
    }

    func testStaleUnfinishedWorkoutIsNotActiveAndEmptyOnesArePurged() {
        let old = WorkoutSession(name: "Old", startedAt: Date().addingTimeInterval(-3 * 24 * 3600))
        context.insert(old)
        try? context.save()
        XCTAssertNil(WorkoutService.activeSession(in: context))
        WorkoutService.purgeAbandonedSessions(in: context)
        XCTAssertTrue(((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).isEmpty)
    }

    func testWorkoutWithTickedSetsSurvivesOvernight() {
        let session = WorkoutSession(name: "Late night", startedAt: Date().addingTimeInterval(-30 * 3600))
        context.insert(session)
        WorkoutService.addExercise(seedId: "bench", name: "Bench Press", muscle: .chest, to: session, context: context)
        sets(of: session, "bench")[0].isCompleted = true
        XCTAssertEqual(WorkoutService.activeSession(in: context)?.id, session.id, "30 hours old but has a ticked set")

        WorkoutService.purgeAbandonedSessions(in: context)
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).count, 1)
    }

    func testOldWorkoutsKeepTheirExerciseOrderEvenWithoutExerciseOrder() {
        // Older data has exerciseOrder 0 for every set, so order falls back to when the sets were logged.
        let base = Date().addingTimeInterval(-3600)
        func make(_ id: String, number: Int, at offset: TimeInterval) -> WorkoutSet {
            let set = WorkoutSet(exerciseSeedId: id, exerciseName: id, muscleGroup: .chest, setNumber: number, weightKg: 50, reps: 5)
            set.completedAt = base.addingTimeInterval(offset)
            return set
        }
        let all = [
            make("squat", number: 1, at: 0),
            make("bench", number: 1, at: 100),
            make("squat", number: 2, at: 50),
            make("bench", number: 2, at: 150),
        ]
        XCTAssertEqual(WorkoutHistory.orderedExerciseIDs(in: all), ["squat", "bench"])
    }

    func testFinishNeedsAtLeastOneCompletedSet() {
        let session = WorkoutService.startEmpty(context: context)
        add(session)
        XCTAssertFalse(WorkoutService.finish(session: session, notes: "", context: context))
        XCTAssertNil(session.finishedAt)
    }

    func testFinishDiscardsUntickedSetsAndRenumbers() {
        let session = WorkoutService.startEmpty(context: context)
        add(session)
        WorkoutService.addSet(exerciseSeedId: "bench", to: session, context: context)
        WorkoutService.addSet(exerciseSeedId: "bench", to: session, context: context)
        let rows = sets(of: session, "bench")
        XCTAssertEqual(rows.count, 3)
        rows[0].isCompleted = true
        rows[2].isCompleted = true

        XCTAssertTrue(WorkoutService.finish(session: session, notes: "", context: context))
        let kept = sets(of: session, "bench")
        XCTAssertEqual(kept.count, 2)
        XCTAssertEqual(kept.map(\.setNumber), [1, 2])
        XCTAssertTrue(kept.allSatisfy(\.isCompleted))
    }

    func testDiscardRemovesTheWorkout() {
        let session = WorkoutService.startEmpty(context: context)
        add(session)
        WorkoutService.discard(session: session, context: context)
        XCTAssertTrue(((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).isEmpty)
    }

    // MARK: Editing

    func testAddSetCopiesTheLastSetAndRemoveRenumbers() {
        let session = WorkoutService.startEmpty(context: context)
        add(session)
        let first = sets(of: session, "bench")[0]
        first.weightKg = 60
        first.reps = 8
        WorkoutService.addSet(exerciseSeedId: "bench", to: session, context: context)
        WorkoutService.addSet(exerciseSeedId: "bench", to: session, context: context)

        let rows = sets(of: session, "bench")
        XCTAssertEqual(rows.map(\.setNumber), [1, 2, 3])
        XCTAssertEqual(rows[2].weightKg, 60)
        XCTAssertEqual(rows[2].reps, 8)
        XCTAssertFalse(rows[2].isCompleted)

        WorkoutService.removeSet(rows[1], from: session, context: context)
        XCTAssertEqual(sets(of: session, "bench").map(\.setNumber), [1, 2])
    }

    func testExercisesKeepTheOrderTheyWereAdded() {
        let session = WorkoutService.startEmpty(context: context)
        add(session, "bench", name: "Bench Press")
        add(session, "squat", name: "Squat")
        add(session, "row", name: "Row")
        XCTAssertEqual(sets(of: session, "bench")[0].exerciseOrder, 0)
        XCTAssertEqual(sets(of: session, "squat")[0].exerciseOrder, 1)
        XCTAssertEqual(sets(of: session, "row")[0].exerciseOrder, 2)

        WorkoutService.removeExercise(seedId: "squat", from: session, context: context)
        XCTAssertTrue(sets(of: session, "squat").isEmpty)
        XCTAssertEqual(Set(session.sets.map(\.exerciseSeedId)), ["bench", "row"])
    }

    // MARK: Routines and history

    func testStartFromRoutinePrefillsFromLastTime() {
        // A finished workout with bench at 60 x 8.
        let old = WorkoutService.startEmpty(context: context)
        add(old)
        let oldSet = sets(of: old, "bench")[0]
        oldSet.weightKg = 60
        oldSet.reps = 8
        oldSet.isCompleted = true
        XCTAssertTrue(WorkoutService.finish(session: old, notes: "", context: context))

        let routine = WorkoutTemplate(name: "Push", isCustom: true)
        let planned = TemplateExercise(exerciseSeedId: "bench", exerciseName: "Bench Press", muscleGroup: .chest, defaultSets: 3, defaultReps: 10, sortOrder: 0)
        routine.exercises.append(planned)
        context.insert(routine)

        let session = WorkoutService.start(template: routine, context: context)
        let rows = sets(of: session, "bench")
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows.allSatisfy { !$0.isCompleted })
        XCTAssertEqual(rows[0].weightKg, 60)
        XCTAssertEqual(rows[0].reps, 8)
        XCTAssertEqual(rows[2].weightKg, 60, "Later sets reuse the last known set")
    }

    func testSaveAsRoutineKeepsOrderAndSetCounts() {
        let session = WorkoutService.startEmpty(context: context)
        add(session, "bench", name: "Bench Press")
        add(session, "row", name: "Row")
        WorkoutService.addSet(exerciseSeedId: "bench", to: session, context: context)
        for set in session.sets { set.isCompleted = true }

        let routine = WorkoutService.saveAsRoutine(session: session, name: "Upper", context: context)
        XCTAssertTrue(routine.isCustom)
        let ordered = routine.exercises.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(ordered.map(\.exerciseName), ["Bench Press", "Row"])
        XCTAssertEqual(ordered.map(\.defaultSets), [2, 1])
    }

    func testDuplicateMakesACustomCopy() {
        let routine = WorkoutTemplate(name: "Starter", isCustom: false)
        let planned = TemplateExercise(exerciseSeedId: "bench", exerciseName: "Bench Press", muscleGroup: .chest, defaultSets: 4, defaultReps: 6, sortOrder: 0)
        routine.exercises.append(planned)
        context.insert(routine)

        let copy = WorkoutService.duplicate(routine, context: context)
        XCTAssertTrue(copy.isCustom)
        XCTAssertNotEqual(copy.seedId, routine.seedId)
        XCTAssertEqual(copy.exercises.count, 1)
        XCTAssertEqual(copy.exercises.first?.defaultSets, 4)
    }

    func testRepeatingAWorkoutCopiesItsShape() {
        let old = WorkoutService.startEmpty(context: context)
        add(old)
        WorkoutService.addSet(exerciseSeedId: "bench", to: old, context: context)
        for set in old.sets { set.isCompleted = true; set.weightKg = 50; set.reps = 10 }
        XCTAssertTrue(WorkoutService.finish(session: old, notes: "", context: context))

        let again = WorkoutService.startRepeating(old, context: context)
        XCTAssertNotEqual(again.id, old.id)
        XCTAssertNil(again.finishedAt)
        XCTAssertEqual(sets(of: again, "bench").count, 2)
        XCTAssertTrue(again.sets.allSatisfy { !$0.isCompleted && $0.weightKg == 50 })
    }
}
