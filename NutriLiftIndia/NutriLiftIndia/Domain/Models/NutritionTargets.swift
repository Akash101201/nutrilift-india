import Foundation

struct MacroTargets: Equatable, Codable, Sendable {
    var calories: Double
    var proteinGrams: Double
    var fatGrams: Double
    var carbGrams: Double

    static let empty = MacroTargets(calories: 0, proteinGrams: 0, fatGrams: 0, carbGrams: 0)
}

struct MacroSnapshot: Equatable, Codable, Sendable {
    var calories: Double
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double

    static let zero = MacroSnapshot(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)

    static func + (lhs: MacroSnapshot, rhs: MacroSnapshot) -> MacroSnapshot {
        MacroSnapshot(
            calories: lhs.calories + rhs.calories,
            proteinGrams: lhs.proteinGrams + rhs.proteinGrams,
            carbGrams: lhs.carbGrams + rhs.carbGrams,
            fatGrams: lhs.fatGrams + rhs.fatGrams
        )
    }

    func scaled(by factor: Double) -> MacroSnapshot {
        MacroSnapshot(
            calories: calories * factor,
            proteinGrams: proteinGrams * factor,
            carbGrams: carbGrams * factor,
            fatGrams: fatGrams * factor
        )
    }
}

enum BMRFormula: String, Equatable, Sendable {
    case mifflinStJeor
    case katchMcArdle

    var displayName: String {
        switch self {
        case .mifflinStJeor: "Mifflin-St Jeor"
        case .katchMcArdle: "Katch-McArdle"
        }
    }
}

/// How much body-composition detail went into the numbers.
enum AccuracyLevel: Int, Equatable, Comparable, Sendable {
    case basic = 1
    case good = 2
    case sharp = 3

    static func < (lhs: AccuracyLevel, rhs: AccuracyLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .basic: "Basic"
        case .good: "Good"
        case .sharp: "Sharp"
        }
    }

    var emoji: String {
        switch self {
        case .basic: "🎯"
        case .good: "🎯🎯"
        case .sharp: "🎯🎯🎯"
        }
    }
}

/// One line of the "Why these numbers?" explainer.
struct BreakdownRow: Equatable, Sendable, Identifiable {
    var emoji: String
    var title: String
    var value: String
    var detail: String

    var id: String { title }
}

struct GoalCalculationResult: Equatable, Sendable {
    var bmr: Double
    var tdee: Double
    var formula: BMRFormula
    var accuracy: AccuracyLevel
    var targets: MacroTargets
    var fiberGrams: Double
    var waterMl: Double
    /// The calorie target was raised to the safety floor (or to maintenance).
    var floorApplied: Bool
    var breakdown: [BreakdownRow]
    /// Friendly heads-ups to show next to the result (age rules, floor hit, etc.).
    var notes: [String]

    /// Plain-text version of the breakdown, for places that show a single string.
    var explanation: String {
        breakdown.map { "\($0.emoji) \($0.title): \($0.value). \($0.detail)" }.joined(separator: "\n")
    }
}

struct GoalInput: Equatable, Sendable {
    var weightKg: Double
    var heightCm: Double
    var age: Int
    var sex: BiologicalSex
    var activity: ActivityLevel
    var goal: FitnessGoal
    var pace: Pace = .steady
    var diet: DietPreference = .veg
    /// Optional. Percent of body weight, e.g. 24.5.
    var bodyFatPercent: Double? = nil
    /// Optional. Lean body mass in kg. Wins over `bodyFatPercent` when both are given.
    var leanMassKg: Double? = nil
}

enum GoalEngineError: Error, Equatable, LocalizedError {
    case weight, height, age, bodyFat, leanMass

    var errorDescription: String? {
        switch self {
        case .weight: "Please enter a weight between \(Int(GoalEngine.weightRange.lowerBound)) and \(Int(GoalEngine.weightRange.upperBound)) kg."
        case .height: "Please enter a height between \(Int(GoalEngine.heightRange.lowerBound)) and \(Int(GoalEngine.heightRange.upperBound)) cm."
        case .age: "Please enter an age between \(GoalEngine.ageRange.lowerBound) and \(GoalEngine.ageRange.upperBound)."
        case .bodyFat: "Body fat should be between \(Int(GoalEngine.bodyFatRange.lowerBound))% and \(Int(GoalEngine.bodyFatRange.upperBound))%."
        case .leanMass: "Lean mass should be positive and lower than your weight."
        }
    }
}
