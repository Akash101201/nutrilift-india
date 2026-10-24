import XCTest
@testable import NutriLiftIndia

final class DiaryAndVolumeTests: XCTestCase {
    func testDiaryTotalsSameDay() {
        let today = Date()
        let e1 = FoodDiaryEntry(
            date: today,
            mealType: .lunch,
            displayName: "Roti",
            quantity: 2,
            servingUnit: .piece,
            snapshot: MacroSnapshot(calories: 240, proteinGrams: 7, carbGrams: 36, fatGrams: 7)
        )
        let e2 = FoodDiaryEntry(
            date: today,
            mealType: .dinner,
            displayName: "Dal",
            quantity: 1,
            servingUnit: .katori,
            snapshot: MacroSnapshot(calories: 180, proteinGrams: 10, carbGrams: 22, fatGrams: 6)
        )
        let total = DiaryTotals.totals(for: [e1, e2], on: today)
        XCTAssertEqual(total.calories, 420, accuracy: 0.1)
        XCTAssertEqual(total.proteinGrams, 17, accuracy: 0.1)
    }

    func testRemaining() {
        let targets = MacroTargets(calories: 2000, proteinGrams: 120, fatGrams: 60, carbGrams: 200)
        let consumed = MacroSnapshot(calories: 500, proteinGrams: 40, carbGrams: 50, fatGrams: 10)
        let rem = DiaryTotals.remaining(targets: targets, consumed: consumed)
        XCTAssertEqual(rem.calories, 1500, accuracy: 0.1)
        XCTAssertEqual(rem.proteinGrams, 80, accuracy: 0.1)
    }

    func testWeeklyMuscleVolume() throws {
        let session = WorkoutSession(name: "Test")
        session.finishedAt = Date()
        let set = WorkoutSet(
            exerciseSeedId: "ex_squat",
            exerciseName: "Squat",
            muscleGroup: .legs,
            setNumber: 1,
            weightKg: 60,
            reps: 8
        )
        session.sets.append(set)
        let vol = VolumeAggregator.weeklySets(sessions: [session])
        let volume = try XCTUnwrap(vol.first)
        XCTAssertEqual(volume.muscleGroup, .legs)
        XCTAssertEqual(volume.sets, 1)
        XCTAssertEqual(volume.volumeKg, 480, accuracy: 0.1)
    }

    func testPRDetection() {
        let old = WorkoutSession(name: "Old")
        old.finishedAt = Date().addingTimeInterval(-86400)
        let oldSet = WorkoutSet(
            exerciseSeedId: "ex_bench",
            exerciseName: "Bench",
            muscleGroup: .chest,
            setNumber: 1,
            weightKg: 60,
            reps: 5
        )
        old.sets.append(oldSet)

        let newSet = WorkoutSet(
            exerciseSeedId: "ex_bench",
            exerciseName: "Bench",
            muscleGroup: .chest,
            setNumber: 1,
            weightKg: 70,
            reps: 5
        )
        XCTAssertTrue(PRDetector.isPR(set: newSet, priorSessions: [old]))
        XCTAssertFalse(PRDetector.isPR(set: oldSet, priorSessions: [old]))
    }

    @MainActor
    func testPhotoConfirmMappingRequiresAwait() {
        let vm = PhotoFoodViewModel()
        XCTAssertFalse(vm.canSaveConfirmed())
        vm.apply(PhotoNutritionEstimate(
            name: "Dal",
            quantity: 1,
            servingUnit: .katori,
            quantityLabel: "1 katori",
            calories: 180,
            proteinGrams: 10,
            carbGrams: 22,
            fatGrams: 6,
            confidence: "medium",
            notes: "",
            matchedFoodSeedId: nil
        ))
        vm.awaitingConfirm = true
        XCTAssertTrue(vm.canSaveConfirmed())
        XCTAssertEqual(vm.editName, "Dal")
        XCTAssertEqual(vm.editCalories, 180, accuracy: 0.1)
    }
}
