import XCTest
@testable import NutriLiftIndia

final class GoalEngineTests: XCTestCase {
    func testMifflinMale() {
        let bmr = GoalEngine.mifflinStJeorBMR(weightKg: 80, heightCm: 180, age: 30, sex: .male)
        // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        XCTAssertEqual(bmr, 1780, accuracy: 0.1)
    }

    func testMifflinFemale() {
        let bmr = GoalEngine.mifflinStJeorBMR(weightKg: 60, heightCm: 160, age: 25, sex: .female)
        // 600 + 1000 - 125 - 161 = 1314
        XCTAssertEqual(bmr, 1314, accuracy: 0.1)
    }

    func testLoseGoalProteinAndFloor() {
        let result = GoalEngine.calculate(
            weightKg: 55,
            heightCm: 155,
            age: 22,
            sex: .female,
            activity: .sedentary,
            goal: .lose
        )
        XCTAssertEqual(result.targets.proteinGrams, (55 * 2.0).rounded(), accuracy: 0.1)
        XCTAssertGreaterThanOrEqual(result.targets.calories, GoalEngine.extremeLowCalorieFloor)
        XCTAssertFalse(result.targets.carbGrams < 0)
    }

    func testMacrosSumNearCalories() {
        let result = GoalEngine.calculate(
            weightKg: 70,
            heightCm: 170,
            age: 30,
            sex: .male,
            activity: .moderate,
            goal: .maintain
        )
        let sum = result.targets.proteinGrams * 4 + result.targets.carbGrams * 4 + result.targets.fatGrams * 9
        XCTAssertEqual(sum, result.targets.calories, accuracy: 20)
    }
}
