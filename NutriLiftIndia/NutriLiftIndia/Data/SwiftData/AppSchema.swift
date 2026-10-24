import SwiftData

/// The single list of persisted models. The app and the App Intents extension must open the
/// same store with the same schema, otherwise SwiftData may treat the difference as a migration.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        UserProfile.self,
        FoodItem.self,
        FoodDiaryEntry.self,
        MealTemplate.self,
        Exercise.self,
        WorkoutTemplate.self,
        TemplateExercise.self,
        WorkoutSession.self,
        WorkoutSet.self,
        BodyWeightSample.self,
        WaterLogEntry.self,
        AppSettings.self,
        CoachChatSession.self,
        CoachChatMessage.self,
    ]

    static var schema: Schema { Schema(models) }
}
