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

struct GoalCalculationResult: Equatable, Sendable {
    var bmr: Double
    var tdee: Double
    var targets: MacroTargets
    var explanation: String
    var isVeryLowCalorie: Bool
    var blockedExtreme: Bool
}
