import AppIntents
import SwiftData
import Foundation

enum IntentModelAccess {
    @MainActor
    static func container() throws -> ModelContainer {
        try ModelContainer(for: AppSchema.schema)
    }
}

struct RemainingCaloriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Remaining calories"
    static var description = IntentDescription("How many calories you have left today in NutriLift India.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try IntentModelAccess.container()
        let context = ModelContext(container)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        let diary = try context.fetch(FetchDescriptor<FoodDiaryEntry>())
        guard let profile else {
            return .result(dialog: "Open NutriLift India and finish onboarding first.")
        }
        let consumed = DiaryTotals.totals(for: diary)
        let remaining = DiaryTotals.remaining(targets: profile.targets, consumed: consumed)
        return .result(dialog: "About \(Int(remaining.calories.rounded())) calories remaining today.")
    }
}

struct RemainingProteinIntent: AppIntent {
    static var title: LocalizedStringResource = "Remaining protein"
    static var description = IntentDescription("How many grams of protein you have left today.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try IntentModelAccess.container()
        let context = ModelContext(container)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        let diary = try context.fetch(FetchDescriptor<FoodDiaryEntry>())
        guard let profile else {
            return .result(dialog: "Open NutriLift India and finish onboarding first.")
        }
        let consumed = DiaryTotals.totals(for: diary)
        let remaining = DiaryTotals.remaining(targets: profile.targets, consumed: consumed)
        return .result(dialog: "About \(Int(remaining.proteinGrams.rounded())) grams of protein remaining today.")
    }
}

enum WorkoutTemplateName: String, AppEnum {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout template")
    static var caseDisplayRepresentations: [WorkoutTemplateName: DisplayRepresentation] = [
        .fullBodyA: "Full Body A",
        .fullBodyB: "Full Body B",
        .upperBody: "Upper Body",
        .lowerBody: "Lower Body",
        .push: "Push (PPL)",
        .pull: "Pull (PPL)",
    ]

    case fullBodyA = "Full Body A"
    case fullBodyB = "Full Body B"
    case upperBody = "Upper Body"
    case lowerBody = "Lower Body"
    case push = "Push (PPL)"
    case pull = "Pull (PPL)"
}

struct StartNamedWorkoutTemplateIntent: AppIntent {
    static var title: LocalizedStringResource = "Start workout template"
    static var description = IntentDescription("Find a NutriLift India workout template by name.")

    @Parameter(title: "Template name")
    var templateName: WorkoutTemplateName

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try IntentModelAccess.container()
        let context = ModelContext(container)
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let selectedName = templateName.rawValue
        let match = templates.first {
            $0.name.localizedCaseInsensitiveCompare(selectedName) == .orderedSame
        }
        if let match {
            return .result(dialog: "Open NutriLift India and start “\(match.name)” from the Workouts tab. (\(match.exercises.count) exercises)")
        }
        let names = templates.map(\.name).sorted().joined(separator: ", ")
        return .result(dialog: "No template matched “\(selectedName)”. Available: \(names.isEmpty ? "none yet" : names).")
    }
}

struct NutriLiftAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RemainingCaloriesIntent(),
            phrases: [
                "How many calories left in \(.applicationName)",
                "Remaining calories in \(.applicationName)",
            ],
            shortTitle: "Calories left",
            systemImageName: "flame"
        )
        AppShortcut(
            intent: RemainingProteinIntent(),
            phrases: [
                "How much protein left in \(.applicationName)",
                "Remaining protein in \(.applicationName)",
            ],
            shortTitle: "Protein left",
            systemImageName: "leaf"
        )
        AppShortcut(
            intent: StartNamedWorkoutTemplateIntent(),
            phrases: [
                "Start \(\.$templateName) workout in \(.applicationName)",
            ],
            shortTitle: "Start workout",
            systemImageName: "dumbbell"
        )
    }
}
