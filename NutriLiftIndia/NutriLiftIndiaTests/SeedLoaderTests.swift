import XCTest
import SwiftData
@testable import NutriLiftIndia

@MainActor
final class SeedLoaderTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: AppSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testFreshSeedLoadsCatalogAndResolvesRoutines() throws {
        try SeedLoader.seedIfNeeded(context: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertGreaterThan(exercises.count, 800)
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.seedId, $0) })
        XCTAssertNotNil(byId["ex_squat"])
        XCTAssertNotNil(byId["ex_bench_press"])

        let overhead = try XCTUnwrap(byId["ex_overhead_triceps"])
        XCTAssertFalse(overhead.instructions?.joined(separator: " ").lowercased().contains("partner") ?? false)
        XCTAssertNotNil(byId["fedb_overhead_triceps"])

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let starter = templates.filter { !$0.isCustom }
        XCTAssertEqual(starter.count, 6)
        for template in starter {
            for planned in template.exercises {
                XCTAssertNotNil(byId[planned.exerciseSeedId], planned.exerciseSeedId)
            }
        }

        let meals = try context.fetch(FetchDescriptor<MealTemplate>())
        XCTAssertEqual(meals.filter { $0.builtInKey != nil }.count, 4)
    }

    func testReseedKeepsFavoritesRecentsAndCustomExercises() throws {
        let used = Date(timeIntervalSince1970: 1_700_000_000)
        let roti = FoodItem(
            seedId: "roti_whole_wheat",
            name: "Roti",
            calories: 1,
            proteinG: 1,
            carbG: 1,
            fatG: 1
        )
        roti.isFavorite = true
        roti.lastUsedAt = used
        context.insert(roti)
        context.insert(FoodItem(
            seedId: "my_bowl",
            name: "My bowl",
            calories: 2,
            proteinG: 2,
            carbG: 2,
            fatG: 2,
            isCustom: true
        ))
        context.insert(Exercise(seedId: "custom_curl", name: "My curl", muscleGroup: .biceps, equipment: .dumbbell, isCustom: true))
        context.insert(Exercise(seedId: "ex_squat", name: "Old squat", muscleGroup: .legs, equipment: .barbell))
        let settings = AppSettings()
        settings.hasSeeded = true
        settings.seedVersion = 1
        context.insert(settings)
        try context.save()

        try SeedLoader.seedIfNeeded(context: context)

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let restored = try XCTUnwrap(foods.first { $0.seedId == "roti_whole_wheat" })
        XCTAssertTrue(restored.isFavorite)
        XCTAssertEqual(restored.lastUsedAt, used)
        XCTAssertEqual(foods.filter { $0.seedId == "roti_whole_wheat" }.count, 1)
        XCTAssertEqual(foods.filter { $0.seedId == "my_bowl" }.count, 1)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.filter { $0.seedId == "custom_curl" }.count, 1)
        XCTAssertEqual(exercises.filter { $0.seedId == "ex_squat" }.count, 1)
        XCTAssertEqual(try XCTUnwrap(exercises.first { $0.seedId == "ex_squat" }).name, "Back squat")
        XCTAssertEqual(settings.seedVersion, SeedLoader.currentSeedVersion)
    }

    func testReseedDoesNotDuplicateBuiltInMealsAndKeepsASameNamedUserMeal() throws {
        let userMeal = MealTemplate(
            name: "Idli + sambar",
            mealType: .breakfast,
            items: [MealTemplateItem(
                foodSeedId: "user_snack",
                displayName: "Snack",
                quantity: 1,
                servingUnit: .piece,
                snapshot: .zero
            )]
        )
        context.insert(userMeal)
        try SeedLoader.seedIfNeeded(context: context)

        let builtIn = try XCTUnwrap(
            context.fetch(FetchDescriptor<MealTemplate>()).first { $0.builtInKey == "meal_idli_sambar" }
        )
        context.delete(builtIn)
        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<AppSettings>()).first)
        settings.seedVersion = 1
        try context.save()

        try SeedLoader.seedIfNeeded(context: context)

        let meals = try context.fetch(FetchDescriptor<MealTemplate>())
        let idli = meals.filter { $0.name == "Idli + sambar" }
        XCTAssertEqual(idli.count, 2)
        XCTAssertEqual(idli.filter { $0.builtInKey == "meal_idli_sambar" }.count, 1)
        XCTAssertEqual(idli.filter { $0.items.contains { $0.foodSeedId == "user_snack" } }.count, 1)
        XCTAssertEqual(meals.filter { $0.builtInKey != nil }.count, 4)
        XCTAssertEqual(settings.seedVersion, SeedLoader.currentSeedVersion)
    }

    func testLegacyBuiltInMealIsClaimedInsteadOfCopied() throws {
        let legacy = MealTemplate(
            name: "Idli + sambar",
            mealType: .breakfast,
            items: [
                MealTemplateItem(foodSeedId: "idli", displayName: "Idli", quantity: 3, servingUnit: .piece, snapshot: .zero),
                MealTemplateItem(foodSeedId: "sambar", displayName: "Sambar", quantity: 1, servingUnit: .katori, snapshot: .zero),
            ]
        )
        context.insert(legacy)
        let settings = AppSettings()
        settings.hasSeeded = true
        settings.seedVersion = 1
        context.insert(settings)
        try context.save()

        try SeedLoader.seedIfNeeded(context: context)

        let meals = try context.fetch(FetchDescriptor<MealTemplate>()).filter { $0.name == "Idli + sambar" }
        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals.first?.builtInKey, "meal_idli_sambar")
    }

    func testExerciseJSONWithoutInstructionsDecodes() throws {
        let data = Data(#"{"id":"ex_plank","name":"Plank","muscleGroup":"core","equipment":"bodyweight"}"#.utf8)
        let decoded = try JSONDecoder().decode(SeedExerciseDTO.self, from: data)
        XCTAssertEqual(decoded.instructions, [])
    }
}
