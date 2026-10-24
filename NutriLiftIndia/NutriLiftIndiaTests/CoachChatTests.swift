import XCTest
import SwiftData
@testable import NutriLiftIndia

@MainActor
final class CoachChatTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: AppSchema.schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testTitleTruncatesLongMessages() {
        let short = CoachChat.title(from: "Protein left?")
        XCTAssertEqual(short, "Protein left?")

        let long = String(repeating: "a", count: 60)
        let titled = CoachChat.title(from: long)
        XCTAssertTrue(titled.hasSuffix("…"))
        XCTAssertLessThanOrEqual(titled.count, 44)
    }

    func testRuleBasedCaloriesUsesTargets() throws {
        let profile = UserProfile(age: 28, sex: .female, heightCm: 160, weightKg: 60, goal: .lose, dietPref: .veg)
        profile.calorieTarget = 1800
        profile.proteinTargetG = 110
        profile.carbTargetG = 180
        profile.fatTargetG = 60
        context.insert(profile)

        let entry = FoodDiaryEntry(
            mealType: .lunch,
            displayName: "Dal",
            quantity: 1,
            servingUnit: .katori,
            snapshot: MacroSnapshot(calories: 400, proteinGrams: 20, carbGrams: 50, fatGrams: 8)
        )
        context.insert(entry)

        let answer = CoachChat.ruleBasedAnswer(
            question: "How many calories remaining today?",
            profile: profile,
            diary: [entry],
            sessions: [],
            templates: []
        )
        XCTAssertTrue(answer.contains("1400"), answer)
        XCTAssertTrue(answer.contains("1800"), answer)
        XCTAssertTrue(answer.contains("400"), answer)
    }

    func testRuleBasedProteinMentionsDietIdeas() {
        let profile = UserProfile(dietPref: .veg)
        profile.proteinTargetG = 100
        let answer = CoachChat.ruleBasedAnswer(
            question: "protein remaining?",
            profile: profile,
            diary: [],
            sessions: [],
            templates: []
        )
        XCTAssertTrue(answer.lowercased().contains("protein"))
        XCTAssertTrue(answer.lowercased().contains("paneer") || answer.lowercased().contains("dal"))
    }

    func testFactsIncludeRemainingMacros() throws {
        let profile = UserProfile()
        profile.calorieTarget = 2000
        profile.proteinTargetG = 120
        profile.carbTargetG = 200
        profile.fatTargetG = 70
        context.insert(profile)

        let facts = CoachChat.facts(
            profile: profile,
            diary: [],
            sessions: [],
            templates: [WorkoutTemplate(name: "Full Body A")]
        )
        let joined = facts.joined(separator: "\n")
        XCTAssertTrue(joined.contains("2000"))
        XCTAssertTrue(joined.contains("120"))
        XCTAssertTrue(joined.contains("Full Body A"))
        XCTAssertTrue(joined.contains("Remaining today"))
    }

    func testContextIncludesConversationHistory() {
        let pack = CoachChat.context(
            profile: nil,
            diary: [],
            sessions: [],
            templates: [],
            history: [(true, "Hi"), (false, "Hello!")],
            question: "Calories left?"
        )
        XCTAssertTrue(pack.promptBody.contains("User: Hi"))
        XCTAssertTrue(pack.promptBody.contains("Coach: Hello!"))
        XCTAssertTrue(pack.promptBody.contains("Calories left?"))
        XCTAssertFalse(pack.facts.isEmpty)
    }

    func testCreateAndDeleteSession() throws {
        let session = CoachChatService.createSession(in: context)
        XCTAssertEqual(session.title, "New chat")

        CoachChatService.appendExchange(
            session: session,
            userText: "How is my weekly volume?",
            reply: .init(text: "No finished sets this week yet.", usedOnDevice: false),
            context: context
        )
        XCTAssertEqual(session.messages.count, 2)
        XCTAssertEqual(session.title, "How is my weekly volume?")

        CoachChatService.deleteSession(session, in: context)
        let remaining = try context.fetch(FetchDescriptor<CoachChatSession>())
        XCTAssertTrue(remaining.isEmpty)
    }
}
