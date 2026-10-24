import Foundation
import SwiftData

/// Saves a weigh-in. Shared by Today and Settings so both behave the same way.
/// It never changes targets silently: it only reports when a refresh is worth offering.
@MainActor
enum WeightLogService {
    /// A new weight this far from the one the targets were built on prompts a refresh.
    static let retargetThresholdKg = 2.0

    struct Outcome: Equatable {
        /// New weight minus the weight the profile had before.
        var changeKg: Double
        var suggestsRetarget: Bool
    }

    /// Returns nil (and saves nothing) if the weight is outside the supported range.
    @discardableResult
    static func log(
        _ kg: Double,
        fromHealthKit: Bool = false,
        profile: UserProfile?,
        context: ModelContext
    ) -> Outcome? {
        guard kg.isFinite, GoalEngine.weightRange.contains(kg) else { return nil }
        let previous = profile?.weightKg ?? kg
        context.insert(BodyWeightSample(weightKg: kg, fromHealthKit: fromHealthKit))
        profile?.weightKg = kg
        try? context.save()
        let change = kg - previous
        return Outcome(changeKg: change, suggestsRetarget: abs(change) >= retargetThresholdKg)
    }
}
