import XCTest
@testable import NutriLiftIndia

final class TargetExplanationTests: XCTestCase {
    private let worked = GoalInput(
        weightKg: 62, heightCm: 160, age: 28, sex: .female,
        activity: .moderate, goal: .lose, pace: .steady, diet: .veg
    )

    private func scenarios() -> [GoalInput] {
        [
            worked,
            GoalInput(weightKg: 100, heightCm: 160, age: 30, sex: .female, activity: .moderate, goal: .lose, pace: .steady, diet: .nonVeg),
            GoalInput(weightKg: 70, heightCm: 170, age: 30, sex: .male, activity: .moderate, goal: .gain, pace: .ambitious, diet: .eggetarian, bodyFatPercent: 20),
            GoalInput(weightKg: 50, heightCm: 160, age: 25, sex: .female, activity: .sedentary, goal: .lose, pace: .ambitious, diet: .jain),
            GoalInput(weightKg: 70, heightCm: 170, age: 30, sex: .male, activity: .light, goal: .maintain, pace: .steady, diet: .nonVeg, leanMassKg: 55),
            GoalInput(weightKg: 60, heightCm: 165, age: 17, sex: .female, activity: .moderate, goal: .lose, pace: .ambitious, diet: .veg),
        ]
    }

    func testFactsContainTheCalculatedTargets() throws {
        let result = try GoalEngine.calculate(worked)
        let joined = TargetExplanation.facts(input: worked, result: result).joined(separator: "\n")
        XCTAssertTrue(joined.contains("1682"))   // calories
        XCTAssertTrue(joined.contains("102"))    // protein g
        XCTAssertTrue(joined.contains("206"))    // carbs g
        XCTAssertTrue(joined.contains("50"))     // fat g
        XCTAssertTrue(joined.contains("vegetarian"))
        XCTAssertTrue(joined.contains("15 percent"))
    }

    func testPromptCarriesFactsAndRules() throws {
        let result = try GoalEngine.calculate(worked)
        let prompt = TargetExplanation.prompt(input: worked, result: result)
        XCTAssertTrue(prompt.contains("1682"))
        XCTAssertTrue(TargetExplanation.instructions.contains("ONLY the facts"))
    }

    func testFallbackTextIsPersonalAndMentionsKeyNumbers() throws {
        let result = try GoalEngine.calculate(worked)
        let text = TargetExplanation.fallbackText(input: worked, result: result)
        XCTAssertTrue(text.contains("1682"))
        XCTAssertTrue(text.contains("15 percent"))
        XCTAssertTrue(text.contains("0.3 kg"))
        XCTAssertTrue(text.contains("10 percent higher"), "Vegetarian protein bump should be explained")
    }

    func testFallbackTextIsAlwaysGroundedInTheFacts() throws {
        for input in scenarios() {
            let result = try GoalEngine.calculate(input)
            let facts = TargetExplanation.facts(input: input, result: result)
            let text = TargetExplanation.fallbackText(input: input, result: result)
            XCTAssertTrue(TargetExplanation.isGrounded(text, facts: facts), "Fallback used a number outside the facts for \(input)")
        }
    }

    func testInventedNumberIsRejected() throws {
        let result = try GoalEngine.calculate(worked)
        let facts = TargetExplanation.facts(input: worked, result: result)
        XCTAssertFalse(TargetExplanation.isGrounded("You should eat 1950 kcal a day.", facts: facts))
        XCTAssertFalse(TargetExplanation.isGrounded("That is 2,300 calories at rest.", facts: facts))
    }

    func testQuotedNumbersAreAccepted() throws {
        let result = try GoalEngine.calculate(worked)
        let facts = TargetExplanation.facts(input: worked, result: result)
        XCTAssertTrue(TargetExplanation.isGrounded("Your target is 1,682 kcal and 102 g of protein, about 1.6 g per kg.", facts: facts))
    }

    func testNumberParsing() {
        XCTAssertEqual(TargetExplanation.numbers(in: "Eat 1,682 kcal, 1.65 g/kg and 102 g."), [1682, 1.65, 102])
        XCTAssertEqual(TargetExplanation.numbers(in: "No digits here"), [])
    }

    func testValidatedRejectsShortOrUngroundedAnswers() throws {
        let result = try GoalEngine.calculate(worked)
        let facts = TargetExplanation.facts(input: worked, result: result)
        XCTAssertNil(TargetExplanation.validated("Too short.", facts: facts))
        let ungrounded = "Your daily target is 1950 kcal because it suits your body and your goal very well indeed."
        XCTAssertNil(TargetExplanation.validated(ungrounded, facts: facts))
        let good = "Your daily target is 1682 kcal because it suits your body and your goal very well indeed."
        XCTAssertEqual(TargetExplanation.validated("  \(good)  ", facts: facts), good)
    }
}
