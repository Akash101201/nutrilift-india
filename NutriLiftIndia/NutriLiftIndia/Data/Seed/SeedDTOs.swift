import Foundation

struct SeedFoodDTO: Codable, Sendable {
    var id: String
    var name: String
    var transliterations: [String]
    var servingUnit: String
    var servingAmount: Double
    var gramsPerServing: Double
    var calories: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double
    var source: String
    var confidence: String
}

struct SeedExerciseDTO: Codable, Sendable {
    var id: String
    var name: String
    var muscleGroup: String
    var equipment: String
}

struct SeedTemplateExerciseDTO: Codable, Sendable {
    var exerciseId: String
    var sets: Int
    var reps: Int
}

struct SeedTemplateDTO: Codable, Sendable {
    var id: String
    var name: String
    var notes: String
    var exercises: [SeedTemplateExerciseDTO]
}
