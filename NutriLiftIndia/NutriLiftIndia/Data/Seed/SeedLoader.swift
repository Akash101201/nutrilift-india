import Foundation
import SwiftData

enum SeedLoader {
    static let currentSeedVersion = 2

    @MainActor
    static func seedIfNeeded(context: ModelContext) throws {
        let descriptor = FetchDescriptor<AppSettings>()
        let settings = try context.fetch(descriptor).first ?? {
            let s = AppSettings()
            context.insert(s)
            return s
        }()

        guard !settings.hasSeeded || settings.seedVersion < currentSeedVersion else { return }

        if settings.hasSeeded {
            let rememberedFoods = try foodUserState(context: context)
            try clearSeededContent(context: context)
            // Persist deletes before inserting rows that reuse the same unique ids.
            try context.save()
            try loadFoods(context: context)
            try restoreFoodUserState(rememberedFoods, context: context)
        } else {
            try loadFoods(context: context)
        }

        try loadExercises(context: context)
        try loadTemplates(context: context)

        // Default meal templates for fast Indian logging
        try insertDefaultMealTemplates(context: context)

        settings.hasSeeded = true
        settings.seedVersion = currentSeedVersion
        try context.save()
    }

    @MainActor
    private static func clearSeededContent(context: ModelContext) throws {
        let foods = try context.fetch(FetchDescriptor<FoodItem>()).filter { !$0.isCustom }
        foods.forEach(context.delete)
        // Custom exercises and routines belong to the user and must survive a seed refresh.
        let exercises = try context.fetch(FetchDescriptor<Exercise>()).filter { !$0.isCustom }
        exercises.forEach(context.delete)
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>()).filter { !$0.isCustom }
        templates.forEach(context.delete)
    }

    private struct FoodUserState {
        var isFavorite: Bool
        var lastUsedAt: Date?
    }

    @MainActor
    private static func foodUserState(context: ModelContext) throws -> [String: FoodUserState] {
        let foods = try context.fetch(FetchDescriptor<FoodItem>()).filter { !$0.isCustom }
        var remembered: [String: FoodUserState] = [:]
        for food in foods where food.isFavorite || food.lastUsedAt != nil {
            remembered[food.seedId] = FoodUserState(isFavorite: food.isFavorite, lastUsedAt: food.lastUsedAt)
        }
        return remembered
    }

    @MainActor
    private static func restoreFoodUserState(_ remembered: [String: FoodUserState], context: ModelContext) throws {
        guard !remembered.isEmpty else { return }
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        for food in foods {
            guard let state = remembered[food.seedId] else { continue }
            food.isFavorite = state.isFavorite
            food.lastUsedAt = state.lastUsedAt
        }
    }

    @MainActor
    private static func loadFoods(context: ModelContext) throws {
        let foods: [SeedFoodDTO] = try decodeJSON(named: "foods")
        for dto in foods {
            let unit = ServingUnit(rawValue: dto.servingUnit) ?? .gram
            let item = FoodItem(
                seedId: dto.id,
                name: dto.name,
                transliterations: dto.transliterations,
                servingUnit: unit,
                servingAmount: dto.servingAmount,
                gramsPerServing: dto.gramsPerServing,
                calories: dto.calories,
                proteinG: dto.proteinG,
                carbG: dto.carbG,
                fatG: dto.fatG,
                sourceTag: dto.source,
                confidence: dto.confidence,
                isCustom: false
            )
            context.insert(item)
        }
    }

    @MainActor
    private static func loadExercises(context: ModelContext) throws {
        let exercises: [SeedExerciseDTO] = try decodeJSON(named: "exercises")
        for dto in exercises {
            let muscle = MuscleGroup(rawValue: dto.muscleGroup) ?? .fullBody
            let equipment = EquipmentType(rawValue: dto.equipment) ?? .other
            context.insert(Exercise(
                seedId: dto.id,
                name: dto.name,
                muscleGroup: muscle,
                equipment: equipment,
                instructions: dto.instructions
            ))
        }
    }

    @MainActor
    private static func loadTemplates(context: ModelContext) throws {
        let templates: [SeedTemplateDTO] = try decodeJSON(named: "workout_templates")
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let allExercises = try context.fetch(exerciseDescriptor)
        let byId = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.seedId, $0) })

        for dto in templates {
            let template = WorkoutTemplate(seedId: dto.id, name: dto.name, notes: dto.notes)
            for (index, ex) in dto.exercises.enumerated() {
                let resolved = byId[ex.exerciseId]
                let te = TemplateExercise(
                    exerciseSeedId: ex.exerciseId,
                    exerciseName: resolved?.name ?? ex.exerciseId,
                    muscleGroup: resolved?.muscleGroup ?? .fullBody,
                    defaultSets: ex.sets,
                    defaultReps: ex.reps,
                    sortOrder: index
                )
                template.exercises.append(te)
            }
            context.insert(template)
        }
    }

    @MainActor
    private static func insertDefaultMealTemplates(context: ModelContext) throws {
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let existing = try context.fetch(FetchDescriptor<MealTemplate>())
        func food(_ id: String) -> FoodItem? { foods.first { $0.seedId == id } }

        let combos: [(String, String, MealType, [(String, Double)])] = [
            ("meal_roti_dal_sabzi", "2 roti + dal + sabzi", .lunch, [("roti_whole_wheat", 2), ("dal_tadka", 1), ("mixed_veg_sabzi", 1)]),
            ("meal_idli_sambar", "Idli + sambar", .breakfast, [("idli", 3), ("sambar", 1)]),
            ("meal_curd_rice", "Curd rice", .dinner, [("curd_rice", 1)]),
            ("meal_egg_bhurji_roti", "Egg bhurji + roti", .dinner, [("egg_bhurji", 1), ("roti_whole_wheat", 2)]),
        ]

        for (key, name, meal, parts) in combos {
            if existing.contains(where: { $0.builtInKey == key }) { continue }
            let expectedIds = parts.map(\.0)
            if let legacy = existing
                .filter({ $0.builtInKey == nil && $0.name == name && $0.items.map(\.foodSeedId) == expectedIds })
                .min(by: { $0.createdAt < $1.createdAt }) {
                legacy.builtInKey = key
                continue
            }
            var items: [MealTemplateItem] = []
            for (id, qty) in parts {
                guard let f = food(id) else { continue }
                let snap = f.perServingSnapshot.scaled(by: qty)
                items.append(MealTemplateItem(
                    foodSeedId: f.seedId,
                    displayName: f.name,
                    quantity: qty,
                    servingUnit: f.servingUnit,
                    snapshot: snap
                ))
            }
            guard !items.isEmpty else { continue }
            context.insert(MealTemplate(name: name, mealType: meal, items: items, builtInKey: key))
        }
    }

    private static func decodeJSON<T: Decodable>(named name: String) throws -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: nil)
                ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Seed")
                ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Resources/Seed") else {
            throw SeedError.missingFile(name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum SeedError: LocalizedError {
    case missingFile(String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let name):
            return "Missing seed file \(name).json"
        }
    }
}
