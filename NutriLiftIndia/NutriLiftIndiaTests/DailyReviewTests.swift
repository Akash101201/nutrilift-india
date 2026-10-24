import XCTest
@testable import NutriLiftIndia

final class DailyReviewTests: XCTestCase {
    private func sampleSnapshot(
        calories: Double = 1800,
        protein: Double = 90,
        waterMl: Double = 1500,
        foodCount: Int = 4,
        workouts: [DayWorkoutBrief] = []
    ) -> DaySnapshot {
        DaySnapshot(
            dayStart: Date(),
            dietPref: .veg,
            calorieTarget: 2000,
            proteinTargetG: 120,
            carbTargetG: 220,
            fatTargetG: 65,
            waterTargetMl: 2500,
            stepTarget: 8000,
            calories: calories,
            proteinG: protein,
            carbG: 200,
            fatG: 55,
            waterMl: waterMl,
            steps: 6000,
            foodEntryCount: foodCount,
            mealNames: ["Roti", "Dal tadka", "Curd"],
            finishedWorkouts: workouts
        )
    }

    func testHasLoggedFood() {
        XCTAssertTrue(DailyReview.hasLoggedFood(sampleSnapshot()))
        XCTAssertFalse(DailyReview.hasLoggedFood(sampleSnapshot(calories: 0, protein: 0, waterMl: 0, foodCount: 0)))
    }

    func testEndOfDayShowsInEvening() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24))!
        let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: day)!
        let morning = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day)!
        let snap = sampleSnapshot()

        XCTAssertTrue(DailyReview.shouldShowEndOfDay(snapshot: snap, hasSavedRecap: false, now: evening, calendar: calendar))
        XCTAssertFalse(DailyReview.shouldShowEndOfDay(snapshot: snap, hasSavedRecap: false, now: morning, calendar: calendar))
        XCTAssertTrue(DailyReview.shouldShowEndOfDay(snapshot: snap, hasSavedRecap: true, now: morning, calendar: calendar))
    }

    func testFactsIncludeTargetsAndAreGroundedInFallback() {
        let snap = sampleSnapshot(
            workouts: [DayWorkoutBrief(name: "Push", setCount: 12, durationMinutes: 40)]
        )
        let facts = DailyReview.facts(snap)
        XCTAssertTrue(facts.contains { $0.contains("1800") })
        XCTAssertTrue(facts.contains { $0.contains("120") })
        XCTAssertTrue(facts.contains { $0.contains("Push") })

        let recap = DailyReview.recapFallback(snap)
        XCTAssertTrue(Grounding.isGrounded(recap, facts: facts))

        let tips = DailyReview.tipsFallback(snap)
        XCTAssertTrue(Grounding.isGrounded(tips, facts: facts))
    }

    func testTipsFallbackMentionsProteinGap() {
        let snap = sampleSnapshot(protein: 70)
        let tips = DailyReview.tipsFallback(snap)
        XCTAssertTrue(tips.contains("70"))
        XCTAssertTrue(tips.contains("120"))
        XCTAssertTrue(tips.contains("50")) // shortfall called out in facts + tips
        XCTAssertTrue(Grounding.isGrounded(tips, facts: DailyReview.facts(snap)))
    }

    func testDayKeyStable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let a = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 8))!
        let b = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 22))!
        XCTAssertEqual(DailyReview.dayKey(a, calendar: calendar), DailyReview.dayKey(b, calendar: calendar))
        XCTAssertEqual(DailyReview.dayKey(a, calendar: calendar), "2026-10-24")
    }
}
