import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var age: Int
    var sexRaw: String
    var heightCm: Double
    var weightKg: Double
    var activityRaw: String
    var goalRaw: String
    var dietPrefRaw: String
    var usesMetric: Bool
    var onboardingComplete: Bool
    var calorieTarget: Double
    var proteinTargetG: Double
    var fatTargetG: Double
    var carbTargetG: Double
    var stepTarget: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        age: Int = 25,
        sex: BiologicalSex = .other,
        heightCm: Double = 165,
        weightKg: Double = 65,
        activity: ActivityLevel = .moderate,
        goal: FitnessGoal = .maintain,
        dietPref: DietPreference = .veg,
        usesMetric: Bool = true
    ) {
        self.id = UUID()
        self.age = age
        self.sexRaw = sex.rawValue
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityRaw = activity.rawValue
        self.goalRaw = goal.rawValue
        self.dietPrefRaw = dietPref.rawValue
        self.usesMetric = usesMetric
        self.onboardingComplete = false
        self.calorieTarget = 2000
        self.proteinTargetG = 100
        self.fatTargetG = 65
        self.carbTargetG = 220
        self.stepTarget = 8000
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .other }
        set { sexRaw = newValue.rawValue }
    }

    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }

    var goal: FitnessGoal {
        get { FitnessGoal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }

    var dietPref: DietPreference {
        get { DietPreference(rawValue: dietPrefRaw) ?? .veg }
        set { dietPrefRaw = newValue.rawValue }
    }

    var targets: MacroTargets {
        get {
            MacroTargets(
                calories: calorieTarget,
                proteinGrams: proteinTargetG,
                fatGrams: fatTargetG,
                carbGrams: carbTargetG
            )
        }
        set {
            calorieTarget = newValue.calories
            proteinTargetG = newValue.proteinGrams
            fatTargetG = newValue.fatGrams
            carbTargetG = newValue.carbGrams
            updatedAt = Date()
        }
    }
}

@Model
final class FoodItem {
    @Attribute(.unique) var seedId: String
    var name: String
    var transliterationsCSV: String
    var servingUnitRaw: String
    var servingAmount: Double
    var gramsPerServing: Double
    var calories: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double
    var sourceTag: String
    var confidence: String
    var isCustom: Bool
    var isFavorite: Bool
    var lastUsedAt: Date?

    init(
        seedId: String = UUID().uuidString,
        name: String,
        transliterations: [String] = [],
        servingUnit: ServingUnit = .gram,
        servingAmount: Double = 100,
        gramsPerServing: Double = 100,
        calories: Double,
        proteinG: Double,
        carbG: Double,
        fatG: Double,
        sourceTag: String = "estimated",
        confidence: String = "medium",
        isCustom: Bool = false
    ) {
        self.seedId = seedId
        self.name = name
        self.transliterationsCSV = transliterations.joined(separator: "|")
        self.servingUnitRaw = servingUnit.rawValue
        self.servingAmount = servingAmount
        self.gramsPerServing = gramsPerServing
        self.calories = calories
        self.proteinG = proteinG
        self.carbG = carbG
        self.fatG = fatG
        self.sourceTag = sourceTag
        self.confidence = confidence
        self.isCustom = isCustom
        self.isFavorite = false
        self.lastUsedAt = nil
    }

    var servingUnit: ServingUnit {
        get { ServingUnit(rawValue: servingUnitRaw) ?? .gram }
        set { servingUnitRaw = newValue.rawValue }
    }

    var transliterations: [String] {
        transliterationsCSV.split(separator: "|").map(String.init).filter { !$0.isEmpty }
    }

    var searchBlob: String {
        ([name] + transliterations).joined(separator: " ").lowercased()
    }

    var perServingSnapshot: MacroSnapshot {
        MacroSnapshot(
            calories: calories,
            proteinGrams: proteinG,
            carbGrams: carbG,
            fatGrams: fatG
        )
    }
}

@Model
final class FoodDiaryEntry {
    var id: UUID
    var date: Date
    var mealTypeRaw: String
    var foodSeedId: String?
    var displayName: String
    var quantity: Double
    var servingUnitRaw: String
    var calories: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double
    var sourceRaw: String
    var createdAt: Date

    init(
        date: Date = Date(),
        mealType: MealType,
        foodSeedId: String? = nil,
        displayName: String,
        quantity: Double,
        servingUnit: ServingUnit,
        snapshot: MacroSnapshot,
        source: DiaryEntrySource = .manual
    ) {
        self.id = UUID()
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.foodSeedId = foodSeedId
        self.displayName = displayName
        self.quantity = quantity
        self.servingUnitRaw = servingUnit.rawValue
        self.calories = snapshot.calories
        self.proteinG = snapshot.proteinGrams
        self.carbG = snapshot.carbGrams
        self.fatG = snapshot.fatGrams
        self.sourceRaw = source.rawValue
        self.createdAt = Date()
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snacks }
        set { mealTypeRaw = newValue.rawValue }
    }

    var servingUnit: ServingUnit {
        get { ServingUnit(rawValue: servingUnitRaw) ?? .gram }
        set { servingUnitRaw = newValue.rawValue }
    }

    var source: DiaryEntrySource {
        get { DiaryEntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var snapshot: MacroSnapshot {
        MacroSnapshot(
            calories: calories,
            proteinGrams: proteinG,
            carbGrams: carbG,
            fatGrams: fatG
        )
    }
}

@Model
final class MealTemplate {
    var id: UUID
    var name: String
    var mealTypeRaw: String
    var itemsJSON: String
    var createdAt: Date

    init(name: String, mealType: MealType, items: [MealTemplateItem]) {
        self.id = UUID()
        self.name = name
        self.mealTypeRaw = mealType.rawValue
        self.itemsJSON = (try? String(data: JSONEncoder().encode(items), encoding: .utf8)) ?? "[]"
        self.createdAt = Date()
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .lunch }
        set { mealTypeRaw = newValue.rawValue }
    }

    var items: [MealTemplateItem] {
        guard let data = itemsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([MealTemplateItem].self, from: data) else {
            return []
        }
        return decoded
    }
}

struct MealTemplateItem: Codable, Equatable, Identifiable {
    var id: UUID
    var foodSeedId: String
    var displayName: String
    var quantity: Double
    var servingUnitRaw: String
    var calories: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double

    init(
        id: UUID = UUID(),
        foodSeedId: String,
        displayName: String,
        quantity: Double,
        servingUnit: ServingUnit,
        snapshot: MacroSnapshot
    ) {
        self.id = id
        self.foodSeedId = foodSeedId
        self.displayName = displayName
        self.quantity = quantity
        self.servingUnitRaw = servingUnit.rawValue
        self.calories = snapshot.calories
        self.proteinG = snapshot.proteinGrams
        self.carbG = snapshot.carbGrams
        self.fatG = snapshot.fatGrams
    }
}

@Model
final class Exercise {
    @Attribute(.unique) var seedId: String
    var name: String
    var muscleGroupRaw: String
    var equipmentRaw: String

    init(
        seedId: String = UUID().uuidString,
        name: String,
        muscleGroup: MuscleGroup,
        equipment: EquipmentType
    ) {
        self.seedId = seedId
        self.name = name
        self.muscleGroupRaw = muscleGroup.rawValue
        self.equipmentRaw = equipment.rawValue
    }

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .fullBody }
        set { muscleGroupRaw = newValue.rawValue }
    }

    var equipment: EquipmentType {
        get { EquipmentType(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }
}

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var seedId: String
    var name: String
    var notes: String
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]

    init(seedId: String = UUID().uuidString, name: String, notes: String = "", exercises: [TemplateExercise] = []) {
        self.seedId = seedId
        self.name = name
        self.notes = notes
        self.exercises = exercises
    }
}

@Model
final class TemplateExercise {
    var id: UUID
    var exerciseSeedId: String
    var exerciseName: String
    var muscleGroupRaw: String
    var defaultSets: Int
    var defaultReps: Int
    var sortOrder: Int
    var template: WorkoutTemplate?

    init(
        exerciseSeedId: String,
        exerciseName: String,
        muscleGroup: MuscleGroup,
        defaultSets: Int = 3,
        defaultReps: Int = 10,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.exerciseSeedId = exerciseSeedId
        self.exerciseName = exerciseName
        self.muscleGroupRaw = muscleGroup.rawValue
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.sortOrder = sortOrder
    }

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .fullBody }
        set { muscleGroupRaw = newValue.rawValue }
    }
}

@Model
final class WorkoutSession {
    var id: UUID
    var name: String
    var startedAt: Date
    var finishedAt: Date?
    var notes: String
    var templateSeedId: String?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var sets: [WorkoutSet]

    init(
        name: String,
        startedAt: Date = Date(),
        templateSeedId: String? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.startedAt = startedAt
        self.finishedAt = nil
        self.notes = notes
        self.templateSeedId = templateSeedId
        self.sets = []
    }

    var isFinished: Bool { finishedAt != nil }
}

@Model
final class WorkoutSet {
    var id: UUID
    var exerciseSeedId: String
    var exerciseName: String
    var muscleGroupRaw: String
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var notes: String
    var completedAt: Date
    var session: WorkoutSession?

    init(
        exerciseSeedId: String,
        exerciseName: String,
        muscleGroup: MuscleGroup,
        setNumber: Int,
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.exerciseSeedId = exerciseSeedId
        self.exerciseName = exerciseName
        self.muscleGroupRaw = muscleGroup.rawValue
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.notes = notes
        self.completedAt = Date()
    }

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .fullBody }
        set { muscleGroupRaw = newValue.rawValue }
    }

    var volume: Double { weightKg * Double(reps) }
}

@Model
final class BodyWeightSample {
    var id: UUID
    var date: Date
    var weightKg: Double
    var fromHealthKit: Bool

    init(date: Date = Date(), weightKg: Double, fromHealthKit: Bool = false) {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
        self.fromHealthKit = fromHealthKit
    }
}

@Model
final class AppSettings {
    var id: UUID
    var notificationsEnabled: Bool
    var mealReminderHour: Int
    var seedVersion: Int
    var hasSeeded: Bool

    init() {
        self.id = UUID()
        self.notificationsEnabled = false
        self.mealReminderHour = 12
        self.seedVersion = 0
        self.hasSeeded = false
    }
}
