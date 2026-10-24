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
    var instructions: [String]

    private enum CodingKeys: String, CodingKey {
        case id, name, muscleGroup, equipment, instructions
    }

    init(id: String, name: String, muscleGroup: String, equipment: String, instructions: [String] = []) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.instructions = instructions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        muscleGroup = try container.decode(String.self, forKey: .muscleGroup)
        equipment = try container.decode(String.self, forKey: .equipment)
        instructions = try container.decodeIfPresent([String].self, forKey: .instructions) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(muscleGroup, forKey: .muscleGroup)
        try container.encode(equipment, forKey: .equipment)
        try container.encode(instructions, forKey: .instructions)
    }
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
