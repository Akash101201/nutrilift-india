import Foundation
import SwiftData

enum ExportService {
    struct ExportPayload: Codable {
        var exportedAt: Date
        var profile: ProfileDTO?
        var diary: [DiaryDTO]
        var sessions: [SessionDTO]
        var weights: [WeightDTO]
        var customFoods: [FoodDTO]
        var water: [WaterDTO]?
        var customExercises: [ExerciseDTO]?
        var routines: [RoutineDTO]?
    }

    struct ExerciseDTO: Codable {
        var name: String
        var muscleGroup: String
        var equipment: String
    }

    struct RoutineDTO: Codable {
        var name: String
        var notes: String
        var exercises: [RoutineExerciseDTO]
    }

    struct RoutineExerciseDTO: Codable {
        var name: String
        var sets: Int
        var reps: Int
    }

    struct WaterDTO: Codable {
        var date: Date
        var amountMl: Double
    }

    struct ProfileDTO: Codable {
        var age: Int
        var sex: String
        var heightCm: Double
        var weightKg: Double
        var activity: String
        var goal: String
        var dietPref: String
        var calorieTarget: Double
        var proteinTargetG: Double
        var fatTargetG: Double
        var carbTargetG: Double
        var stepTarget: Int
        var pace: String?
        var bodyFatPercent: Double?
        var leanMassKg: Double?
        var fiberTargetG: Double?
        var waterTargetMl: Double?
    }

    struct DiaryDTO: Codable {
        var date: Date
        var mealType: String
        var name: String
        var quantity: Double
        var unit: String
        var calories: Double
        var proteinG: Double
        var carbG: Double
        var fatG: Double
        var source: String
    }

    struct SessionDTO: Codable {
        var name: String
        var startedAt: Date
        var finishedAt: Date?
        var notes: String
        var summary: String?
        var sets: [SetDTO]
    }

    struct SetDTO: Codable {
        var exerciseName: String
        var muscleGroup: String
        var setNumber: Int
        var weightKg: Double
        var reps: Int
        var rpe: Double?
    }

    struct WeightDTO: Codable {
        var date: Date
        var weightKg: Double
        var fromHealthKit: Bool
    }

    struct FoodDTO: Codable {
        var name: String
        var calories: Double
        var proteinG: Double
        var carbG: Double
        var fatG: Double
        var servingUnit: String
        var servingAmount: Double
    }

    @MainActor
    static func exportJSON(context: ModelContext) throws -> Data {
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        let diary = try context.fetch(FetchDescriptor<FoodDiaryEntry>())
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let weights = try context.fetch(FetchDescriptor<BodyWeightSample>())
        let customs = try context.fetch(FetchDescriptor<FoodItem>()).filter(\.isCustom)
        let waterLogs = try context.fetch(FetchDescriptor<WaterLogEntry>())
        let customExercises = try context.fetch(FetchDescriptor<Exercise>()).filter(\.isCustom)
        let routines = try context.fetch(FetchDescriptor<WorkoutTemplate>()).filter(\.isCustom)

        let payload = ExportPayload(
            exportedAt: Date(),
            profile: profile.map {
                ProfileDTO(
                    age: $0.age,
                    sex: $0.sexRaw,
                    heightCm: $0.heightCm,
                    weightKg: $0.weightKg,
                    activity: $0.activityRaw,
                    goal: $0.goalRaw,
                    dietPref: $0.dietPrefRaw,
                    calorieTarget: $0.calorieTarget,
                    proteinTargetG: $0.proteinTargetG,
                    fatTargetG: $0.fatTargetG,
                    carbTargetG: $0.carbTargetG,
                    stepTarget: $0.stepTarget,
                    pace: $0.paceRaw,
                    bodyFatPercent: $0.bodyFatPercent,
                    leanMassKg: $0.leanMassKg,
                    fiberTargetG: $0.fiberTargetG,
                    waterTargetMl: $0.waterTargetMl
                )
            },
            diary: diary.map {
                DiaryDTO(
                    date: $0.date,
                    mealType: $0.mealTypeRaw,
                    name: $0.displayName,
                    quantity: $0.quantity,
                    unit: $0.servingUnitRaw,
                    calories: $0.calories,
                    proteinG: $0.proteinG,
                    carbG: $0.carbG,
                    fatG: $0.fatG,
                    source: $0.sourceRaw
                )
            },
            sessions: sessions.map { session in
                SessionDTO(
                    name: session.name,
                    startedAt: session.startedAt,
                    finishedAt: session.finishedAt,
                    notes: session.notes,
                    summary: session.aiSummary,
                    sets: session.sets.filter(\.isCompleted).map {
                        SetDTO(
                            exerciseName: $0.exerciseName,
                            muscleGroup: $0.muscleGroupRaw,
                            setNumber: $0.setNumber,
                            weightKg: $0.weightKg,
                            reps: $0.reps,
                            rpe: $0.rpe
                        )
                    }
                )
            },
            weights: weights.map { WeightDTO(date: $0.date, weightKg: $0.weightKg, fromHealthKit: $0.fromHealthKit) },
            customFoods: customs.map {
                FoodDTO(
                    name: $0.name,
                    calories: $0.calories,
                    proteinG: $0.proteinG,
                    carbG: $0.carbG,
                    fatG: $0.fatG,
                    servingUnit: $0.servingUnitRaw,
                    servingAmount: $0.servingAmount
                )
            },
            water: waterLogs.map { WaterDTO(date: $0.date, amountMl: $0.amountMl) },
            customExercises: customExercises.map {
                ExerciseDTO(name: $0.name, muscleGroup: $0.muscleGroupRaw, equipment: $0.equipmentRaw)
            },
            routines: routines.map { routine in
                RoutineDTO(
                    name: routine.name,
                    notes: routine.notes,
                    exercises: routine.exercises
                        .sorted { $0.sortOrder < $1.sortOrder }
                        .map { RoutineExerciseDTO(name: $0.exerciseName, sets: $0.defaultSets, reps: $0.defaultReps) }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    @MainActor
    static func deleteAllUserData(context: ModelContext) throws {
        try deleteAll(FoodDiaryEntry.self, context: context)
        try deleteAll(MealTemplate.self, context: context)
        try deleteAll(WorkoutSession.self, context: context)
        try deleteAll(BodyWeightSample.self, context: context)
        try deleteAll(WaterLogEntry.self, context: context)
        try deleteAll(UserProfile.self, context: context)

        let customs = try context.fetch(FetchDescriptor<FoodItem>()).filter(\.isCustom)
        customs.forEach(context.delete)

        // Custom exercises and routines are user data too.
        try context.fetch(FetchDescriptor<Exercise>()).filter(\.isCustom).forEach(context.delete)
        try context.fetch(FetchDescriptor<WorkoutTemplate>()).filter(\.isCustom).forEach(context.delete)

        // Keep seeds; reset settings flag except seeding
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        for s in settings {
            s.notificationsEnabled = false
        }
        try context.save()
    }

    @MainActor
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        items.forEach(context.delete)
    }
}
