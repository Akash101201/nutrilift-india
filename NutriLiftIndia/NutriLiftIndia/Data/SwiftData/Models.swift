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
    // Added after v1. Defaults here let SwiftData migrate existing stores automatically.
    var paceRaw: String = "steady"
    var bodyFatPercent: Double?
    var leanMassKg: Double?
    var fiberTargetG: Double = 25
    var waterTargetMl: Double = 2500
    /// Gym experience. Defaults to intermediate so existing installs keep the current UX.
    var experienceRaw: String = ExperienceLevel.intermediate.rawValue
    /// Seed id of the active leveled training plan (`plan_gym_starter`, etc.).
    var activePlanSeedId: String = ExperienceLevel.intermediate.defaultPlanSeedId

    init(
        age: Int = 25,
        sex: BiologicalSex = .other,
        heightCm: Double = 165,
        weightKg: Double = 65,
        activity: ActivityLevel = .moderate,
        goal: FitnessGoal = .maintain,
        dietPref: DietPreference = .veg,
        experience: ExperienceLevel = .intermediate,
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
        self.experienceRaw = experience.rawValue
        self.activePlanSeedId = experience.defaultPlanSeedId
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

    var pace: Pace {
        get { Pace(rawValue: paceRaw) ?? .steady }
        set { paceRaw = newValue.rawValue }
    }

    var experience: ExperienceLevel {
        get { ExperienceLevel(rawValue: experienceRaw) ?? .intermediate }
        set {
            experienceRaw = newValue.rawValue
            // Keep the active plan aligned when the user changes level in Settings.
            activePlanSeedId = newValue.defaultPlanSeedId
        }
    }

    /// The engine input built from this profile.
    var goalInput: GoalInput {
        GoalInput(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            sex: sex,
            activity: activity,
            goal: goal,
            pace: pace,
            diet: dietPref,
            bodyFatPercent: bodyFatPercent,
            leanMassKg: leanMassKg
        )
    }

    /// Stores a calculation result as the profile's targets.
    func apply(_ result: GoalCalculationResult) {
        targets = result.targets
        fiberTargetG = result.fiberGrams
        waterTargetMl = result.waterMl
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
        get {
            MacroSnapshot(
                calories: calories,
                proteinGrams: proteinG,
                carbGrams: carbG,
                fatGrams: fatG
            )
        }
        set {
            calories = newValue.calories
            proteinG = newValue.proteinGrams
            carbG = newValue.carbGrams
            fatG = newValue.fatGrams
        }
    }
}

@Model
final class MealTemplate {
    var id: UUID
    var name: String
    var mealTypeRaw: String
    var itemsJSON: String
    var createdAt: Date
    /// Set on the built-in meal templates so a user template with the same name does not replace them.
    var builtInKey: String? = nil

    init(name: String, mealType: MealType, items: [MealTemplateItem], builtInKey: String? = nil) {
        self.id = UUID()
        self.name = name
        self.mealTypeRaw = mealType.rawValue
        self.itemsJSON = (try? String(data: JSONEncoder().encode(items), encoding: .utf8)) ?? "[]"
        self.createdAt = Date()
        self.builtInKey = builtInKey
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
    /// Step-by-step cues from the bundled catalog. Optional so stores created before this field still open.
    var instructions: [String]? = nil
    /// Exercises the user created. Never removed by seed refreshes.
    var isCustom: Bool = false
    /// Catalog difficulty (`beginner` / `intermediate` / `advanced`). Nil for custom or untagged rows.
    var difficultyRaw: String? = nil

    init(
        seedId: String = UUID().uuidString,
        name: String,
        muscleGroup: MuscleGroup,
        equipment: EquipmentType,
        instructions: [String] = [],
        isCustom: Bool = false,
        difficulty: ExerciseDifficulty? = nil
    ) {
        self.seedId = seedId
        self.name = name
        self.muscleGroupRaw = muscleGroup.rawValue
        self.equipmentRaw = equipment.rawValue
        self.instructions = instructions
        self.isCustom = isCustom
        self.difficultyRaw = difficulty?.rawValue
    }

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .fullBody }
        set { muscleGroupRaw = newValue.rawValue }
    }

    var equipment: EquipmentType {
        get { EquipmentType(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }

    var difficulty: ExerciseDifficulty? {
        get {
            guard let difficultyRaw else { return nil }
            return ExerciseDifficulty(rawValue: difficultyRaw)
        }
        set { difficultyRaw = newValue?.rawValue }
    }
}

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var seedId: String
    var name: String
    var notes: String
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]
    /// Routines the user created or duplicated. Never removed by seed refreshes.
    var isCustom: Bool = false
    /// Suggested experience level for starter routines. Nil for custom routines.
    var recommendedLevelRaw: String? = nil

    init(
        seedId: String = UUID().uuidString,
        name: String,
        notes: String = "",
        exercises: [TemplateExercise] = [],
        isCustom: Bool = false,
        recommendedLevel: ExperienceLevel? = nil
    ) {
        self.seedId = seedId
        self.name = name
        self.notes = notes
        self.exercises = exercises
        self.isCustom = isCustom
        self.recommendedLevelRaw = recommendedLevel?.rawValue
    }

    var recommendedLevel: ExperienceLevel? {
        get {
            guard let recommendedLevelRaw else { return nil }
            return ExperienceLevel(rawValue: recommendedLevelRaw)
        }
        set { recommendedLevelRaw = newValue?.rawValue }
    }
}

@Model
final class TrainingPlan {
    @Attribute(.unique) var seedId: String
    var name: String
    var notes: String
    var experienceRaw: String
    var daysPerWeek: Int
    @Relationship(deleteRule: .cascade, inverse: \PlanDay.plan)
    var days: [PlanDay]

    init(
        seedId: String,
        name: String,
        notes: String = "",
        experience: ExperienceLevel,
        daysPerWeek: Int,
        days: [PlanDay] = []
    ) {
        self.seedId = seedId
        self.name = name
        self.notes = notes
        self.experienceRaw = experience.rawValue
        self.daysPerWeek = daysPerWeek
        self.days = days
    }

    var experience: ExperienceLevel {
        get { ExperienceLevel(rawValue: experienceRaw) ?? .intermediate }
        set { experienceRaw = newValue.rawValue }
    }

    var orderedDays: [PlanDay] {
        days.sorted { $0.sortOrder < $1.sortOrder }
    }
}

@Model
final class PlanDay {
    var id: UUID
    var name: String
    var templateSeedId: String
    var sortOrder: Int
    var plan: TrainingPlan?

    init(name: String, templateSeedId: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.templateSeedId = templateSeedId
        self.sortOrder = sortOrder
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
    /// The coach's after-workout summary, saved so history can show it again.
    var aiSummary: String?
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
    /// False for a planned row the user hasn't ticked off yet. Finishing a workout discards these,
    /// so every finished session only holds completed sets. Old data defaults to true.
    var isCompleted: Bool = true
    /// Position of this set's exercise within the workout.
    var exerciseOrder: Int = 0

    init(
        exerciseSeedId: String,
        exerciseName: String,
        muscleGroup: MuscleGroup,
        setNumber: Int,
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        notes: String = "",
        isCompleted: Bool = true,
        exerciseOrder: Int = 0
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
        self.isCompleted = isCompleted
        self.exerciseOrder = exerciseOrder
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

/// One tap on the water tracker.
@Model
final class WaterLogEntry {
    var id: UUID
    var date: Date
    var amountMl: Double

    init(date: Date = Date(), amountMl: Double = 250) {
        self.id = UUID()
        self.date = date
        self.amountMl = amountMl
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

/// One Coach conversation. Messages cascade-delete with the session.
@Model
final class CoachChatSession {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \CoachChatMessage.session)
    var messages: [CoachChatMessage]

    init(title: String = "New chat") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
    }

    var sortedMessages: [CoachChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
final class CoachChatMessage {
    var id: UUID
    /// `user` or `assistant`
    var roleRaw: String
    var text: String
    var createdAt: Date
    /// True when the assistant reply came from on-device Foundation Models.
    var usedOnDevice: Bool
    var session: CoachChatSession?

    init(
        role: CoachMessageRole,
        text: String,
        usedOnDevice: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.text = text
        self.createdAt = createdAt
        self.usedOnDevice = usedOnDevice
    }

    var role: CoachMessageRole {
        get { CoachMessageRole(rawValue: roleRaw) ?? .assistant }
        set { roleRaw = newValue.rawValue }
    }

    var isUser: Bool { role == .user }
}

enum CoachMessageRole: String, Codable, CaseIterable {
    case user
    case assistant
}
