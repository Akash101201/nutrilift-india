import XCTest
@testable import NutriLiftIndia

final class PlanSchedulerTests: XCTestCase {
    private let starterDays: [PlanScheduler.PlanDayRef] = [
        .init(name: "Full Body A", templateSeedId: "tmpl_full_body_a"),
        .init(name: "Full Body B", templateSeedId: "tmpl_full_body_b"),
        .init(name: "Full Body Easy", templateSeedId: "tmpl_full_body_a_easy"),
    ]

    private let upperLower: [PlanScheduler.PlanDayRef] = [
        .init(name: "Upper", templateSeedId: "tmpl_upper"),
        .init(name: "Lower", templateSeedId: "tmpl_lower"),
        .init(name: "Upper", templateSeedId: "tmpl_upper"),
        .init(name: "Lower", templateSeedId: "tmpl_lower"),
    ]

    func testEmptyPlanReturnsNil() {
        XCTAssertNil(PlanScheduler.nextDay(days: [], lastFinishedTemplateSeedId: nil))
    }

    func testNoHistoryStartsAtDayZero() {
        let next = PlanScheduler.nextDay(days: starterDays, lastFinishedTemplateSeedId: nil)
        XCTAssertEqual(next?.dayIndex, 0)
        XCTAssertEqual(next?.templateSeedId, "tmpl_full_body_a")
        XCTAssertEqual(next?.name, "Full Body A")
    }

    func testAdvancesToNextDay() {
        let next = PlanScheduler.nextDay(days: starterDays, lastFinishedTemplateSeedId: "tmpl_full_body_a")
        XCTAssertEqual(next?.dayIndex, 1)
        XCTAssertEqual(next?.templateSeedId, "tmpl_full_body_b")
    }

    func testWrapsAroundAfterLastDay() {
        let next = PlanScheduler.nextDay(days: starterDays, lastFinishedTemplateSeedId: "tmpl_full_body_a_easy")
        XCTAssertEqual(next?.dayIndex, 0)
        XCTAssertEqual(next?.templateSeedId, "tmpl_full_body_a")
    }

    func testUnknownTemplateRestartsPlan() {
        let next = PlanScheduler.nextDay(days: starterDays, lastFinishedTemplateSeedId: "tmpl_custom")
        XCTAssertEqual(next?.dayIndex, 0)
    }

    func testUpperLowerUsesLastIndexForRepeatedTemplates() {
        // After finishing the second Upper (index 2), next should be the second Lower (index 3).
        let next = PlanScheduler.nextDay(days: upperLower, lastFinishedTemplateSeedId: "tmpl_upper")
        XCTAssertEqual(next?.dayIndex, 3)
        XCTAssertEqual(next?.templateSeedId, "tmpl_lower")
    }

    func testDefaultPlanSeedIds() {
        XCTAssertEqual(ExperienceLevel.beginner.defaultPlanSeedId, "plan_gym_starter")
        XCTAssertEqual(ExperienceLevel.intermediate.defaultPlanSeedId, "plan_upper_lower")
        XCTAssertEqual(ExperienceLevel.advanced.defaultPlanSeedId, "plan_ppl")
    }

    func testProfileDefaultsToIntermediateAndMatchingPlan() {
        let profile = UserProfile()
        XCTAssertEqual(profile.experience, .intermediate)
        XCTAssertEqual(profile.activePlanSeedId, ExperienceLevel.intermediate.defaultPlanSeedId)
        profile.experience = .beginner
        XCTAssertEqual(profile.activePlanSeedId, ExperienceLevel.beginner.defaultPlanSeedId)
    }
}
