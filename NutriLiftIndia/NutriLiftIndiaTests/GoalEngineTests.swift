import XCTest
@testable import NutriLiftIndia

final class GoalEngineTests: XCTestCase {
    private func makeInput(
        weight: Double = 70,
        height: Double = 170,
        age: Int = 30,
        sex: BiologicalSex = .male,
        activity: ActivityLevel = .moderate,
        goal: FitnessGoal = .maintain,
        pace: Pace = .steady,
        diet: DietPreference = .nonVeg,
        bodyFat: Double? = nil,
        lean: Double? = nil
    ) -> GoalInput {
        GoalInput(
            weightKg: weight,
            heightCm: height,
            age: age,
            sex: sex,
            activity: activity,
            goal: goal,
            pace: pace,
            diet: diet,
            bodyFatPercent: bodyFat,
            leanMassKg: lean
        )
    }

    // MARK: BMR formulas

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

    func testMifflinOtherIsAverageOfMaleAndFemale() {
        let male = GoalEngine.mifflinStJeorBMR(weightKg: 70, heightCm: 170, age: 30, sex: .male)
        let female = GoalEngine.mifflinStJeorBMR(weightKg: 70, heightCm: 170, age: 30, sex: .female)
        let other = GoalEngine.mifflinStJeorBMR(weightKg: 70, heightCm: 170, age: 30, sex: .other)
        XCTAssertEqual(other, (male + female) / 2, accuracy: 0.1)
    }

    func testKatchMcArdle() {
        // 370 + 21.6 * 50 = 1450
        XCTAssertEqual(GoalEngine.katchMcArdleBMR(leanMassKg: 50), 1450, accuracy: 0.1)
    }

    // MARK: Worked example

    func testWorkedExampleFemaleVegLoseSteady() throws {
        // BMR 1319, TDEE 1319 * 1.5 = 1978.5, steady lose = 15% -> 1681.7 -> 1682.
        // Protein 62 kg * 1.5 g/kg * 1.10 (veg) = 102.3 -> 102. Fat 27% -> 50. Carbs fill the rest.
        let r = try GoalEngine.calculate(makeInput(
            weight: 62, height: 160, age: 28, sex: .female,
            activity: .moderate, goal: .lose, pace: .steady, diet: .veg
        ))
        XCTAssertEqual(r.bmr, 1319, accuracy: 0.5)
        XCTAssertEqual(r.tdee, 1978.5, accuracy: 0.5)
        XCTAssertEqual(r.targets.calories, 1682)
        XCTAssertEqual(r.targets.proteinGrams, 102)
        XCTAssertEqual(r.targets.fatGrams, 50)
        XCTAssertEqual(r.targets.carbGrams, 206)
        XCTAssertEqual(r.formula, .mifflinStJeor)
        XCTAssertEqual(r.accuracy, .basic)
        XCTAssertFalse(r.floorApplied)
    }

    // MARK: Pace

    func testLosePacesArePercentOfTDEE() throws {
        // Male 80 kg, 180 cm, 30 y, sedentary: BMR 1780, TDEE 2136.
        func calories(_ pace: Pace) throws -> Double {
            try GoalEngine.calculate(makeInput(
                weight: 80, height: 180, activity: .sedentary, goal: .lose, pace: pace
            )).targets.calories
        }
        XCTAssertEqual(try calories(.gentle), 1922)      // 90%
        XCTAssertEqual(try calories(.steady), 1816)      // 85%
        XCTAssertEqual(try calories(.ambitious), 1709)   // 80%
    }

    func testGainSteadyIsTenPercentAbove() throws {
        let r = try GoalEngine.calculate(makeInput(
            weight: 80, height: 180, activity: .sedentary, goal: .gain, pace: .steady
        ))
        XCTAssertEqual(r.targets.calories, 2350)         // 2136 * 1.10
    }

    func testMaintainEqualsTDEE() throws {
        let r = try GoalEngine.calculate(makeInput(weight: 80, height: 180, activity: .sedentary))
        XCTAssertEqual(r.targets.calories, 2136)
    }

    // MARK: Safety

    func testFemaleFloorIsApplied() throws {
        // BMR 1214, TDEE 1456.8, ambitious 80% = 1165 -> raised to 1200.
        let r = try GoalEngine.calculate(makeInput(
            weight: 50, height: 160, age: 25, sex: .female,
            activity: .sedentary, goal: .lose, pace: .ambitious
        ))
        XCTAssertEqual(r.targets.calories, 1200)
        XCTAssertTrue(r.floorApplied)
        XCTAssertFalse(r.notes.isEmpty)
    }

    func testMaleFloorIsHigher() throws {
        // BMR 1461.25, TDEE 1753.5, ambitious 80% = 1403 -> raised to 1500.
        let r = try GoalEngine.calculate(makeInput(
            weight: 55, height: 165, age: 25, sex: .male,
            activity: .sedentary, goal: .lose, pace: .ambitious
        ))
        XCTAssertEqual(r.targets.calories, 1500)
        XCTAssertTrue(r.floorApplied)
    }

    func testFloorNeverPushesTargetAboveMaintenance() throws {
        // TDEE ~1112 is already below the female floor, so a "lose" goal must not exceed it.
        let r = try GoalEngine.calculate(makeInput(
            weight: 45, height: 150, age: 60, sex: .female,
            activity: .sedentary, goal: .lose, pace: .ambitious
        ))
        XCTAssertEqual(r.targets.calories, r.tdee.rounded())
        XCTAssertLessThanOrEqual(r.targets.calories, r.tdee.rounded())
    }

    func testUnder18GetsMaintenanceInsteadOfDeficit() throws {
        let r = try GoalEngine.calculate(makeInput(
            weight: 60, height: 165, age: 17, sex: .female,
            activity: .moderate, goal: .lose, pace: .ambitious
        ))
        XCTAssertEqual(r.targets.calories, r.tdee.rounded())
        XCTAssertFalse(r.notes.isEmpty)
    }

    // MARK: Protein

    func testHeavyUserProteinUsesAdjustedWeight() throws {
        // 100 kg at 160 cm (BMI ~39): adjusted weight ~64.3 kg * 1.5 g/kg = ~96 g,
        // not the 200 g the old total-weight formula gave.
        let r = try GoalEngine.calculate(makeInput(
            weight: 100, height: 160, age: 30, sex: .female,
            activity: .moderate, goal: .lose, diet: .nonVeg
        ))
        XCTAssertEqual(r.targets.proteinGrams, 96, accuracy: 1)
    }

    func testVegetarianGetsMoreProteinThanNonVeg() throws {
        let veg = try GoalEngine.calculate(makeInput(diet: .veg))
        let nonVeg = try GoalEngine.calculate(makeInput(diet: .nonVeg))
        XCTAssertGreaterThan(veg.targets.proteinGrams, nonVeg.targets.proteinGrams)
    }

    func testProteinNeverExceedsThirtyFivePercentOfCalories() throws {
        let r = try GoalEngine.calculate(makeInput(
            weight: 90, height: 175, sex: .male, activity: .veryActive, goal: .lose, pace: .ambitious, diet: .veg,
            lean: 80
        ))
        XCTAssertLessThanOrEqual(r.targets.proteinGrams * 4, r.targets.calories * 0.35 + 4)
    }

    // MARK: Optional body composition

    func testLeanMassSwitchesToKatchMcArdleAndSharp() throws {
        let r = try GoalEngine.calculate(makeInput(lean: 50))
        XCTAssertEqual(r.formula, .katchMcArdle)
        XCTAssertEqual(r.bmr, 1450, accuracy: 0.1)
        XCTAssertEqual(r.accuracy, .sharp)
    }

    func testBodyFatDerivesLeanMassAndIsGood() throws {
        // 70 kg at 20% body fat -> 56 kg lean -> 370 + 21.6 * 56 = 1579.6
        let r = try GoalEngine.calculate(makeInput(bodyFat: 20))
        XCTAssertEqual(r.formula, .katchMcArdle)
        XCTAssertEqual(r.bmr, 1579.6, accuracy: 0.1)
        XCTAssertEqual(r.accuracy, .good)
    }

    func testLeanMassWinsOverBodyFat() throws {
        let r = try GoalEngine.calculate(makeInput(bodyFat: 20, lean: 50))
        XCTAssertEqual(r.bmr, 1450, accuracy: 0.1)
        XCTAssertEqual(r.accuracy, .sharp)
    }

    func testSkippingOptionalInputsStillWorks() throws {
        let r = try GoalEngine.calculate(makeInput())
        XCTAssertEqual(r.formula, .mifflinStJeor)
        XCTAssertEqual(r.accuracy, .basic)
    }

    // MARK: Macros always add up

    func testMacrosAlwaysSumNearCalories() throws {
        let inputs: [GoalInput] = [
            makeInput(),
            makeInput(weight: 100, height: 160, age: 30, sex: .female, goal: .lose),
            makeInput(weight: 120, height: 165, goal: .lose, pace: .ambitious, diet: .veg),
            makeInput(weight: 50, height: 160, age: 25, sex: .female, activity: .sedentary, goal: .lose, pace: .ambitious, diet: .veg),
            makeInput(weight: 90, height: 175, activity: .veryActive, goal: .gain, pace: .ambitious),
            makeInput(weight: 55, height: 150, age: 70, sex: .female, activity: .active, goal: .lose, diet: .veg),
        ]
        for input in inputs {
            let r = try GoalEngine.calculate(input)
            let t = r.targets
            let sum = t.proteinGrams * 4 + t.carbGrams * 4 + t.fatGrams * 9
            XCTAssertEqual(sum, t.calories, accuracy: 15, "Macros should add up for \(input)")
            XCTAssertGreaterThanOrEqual(t.carbGrams, 0)
            XCTAssertGreaterThanOrEqual(t.carbGrams * 4, t.calories * 0.28, "Carbs should keep a sensible minimum for \(input)")
        }
    }

    // MARK: Fiber and water

    func testFiberAndWaterAreSensible() throws {
        let r = try GoalEngine.calculate(makeInput())
        XCTAssertGreaterThanOrEqual(r.fiberGrams, 25)
        XCTAssertGreaterThanOrEqual(r.waterMl, 1500)
        XCTAssertLessThanOrEqual(r.waterMl, 5000)
        XCTAssertEqual(r.waterMl.truncatingRemainder(dividingBy: 250), 0)
    }

    // MARK: Validation

    func testInvalidInputsThrow() {
        func expect(_ input: GoalInput, _ error: GoalEngineError, line: UInt = #line) {
            XCTAssertThrowsError(try GoalEngine.calculate(input), line: line) {
                XCTAssertEqual($0 as? GoalEngineError, error, line: line)
            }
        }
        expect(makeInput(weight: 0), .weight)
        expect(makeInput(weight: -5), .weight)
        expect(makeInput(height: 10), .height)
        expect(makeInput(age: 5), .age)
        expect(makeInput(bodyFat: 80), .bodyFat)
        expect(makeInput(weight: 70, lean: 90), .leanMass)
        expect(makeInput(weight: 70, lean: 10), .leanMass)
    }

    func testExplainerHasRowsForEveryTarget() throws {
        let r = try GoalEngine.calculate(makeInput())
        let titles = r.breakdown.map(\.title)
        for title in ["Resting burn", "Daily burn", "Your goal", "Daily target", "Protein", "Fat", "Carbs", "Fiber", "Water"] {
            XCTAssertTrue(titles.contains(title), "Missing explainer row: \(title)")
        }
    }
}
