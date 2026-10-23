import Foundation

enum GoalEngine {
    /// Soft-warn threshold (kcal/day). Not medical advice.
    static let veryLowCalorieThreshold = 1200.0
    /// Hard block for extreme targets in auto-calculation path.
    static let extremeLowCalorieFloor = 800.0

    static func mifflinStJeorBMR(weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex) -> Double {
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age))
        switch sex {
        case .male:
            return base + 5
        case .female:
            return base - 161
        case .other:
            // Average of male/female offsets for non-binary / prefer-not-to-say.
            return base - 78
        }
    }

    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    static func calculate(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex,
        activity: ActivityLevel,
        goal: FitnessGoal
    ) -> GoalCalculationResult {
        let bmr = mifflinStJeorBMR(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex)
        let tdeeValue = tdee(bmr: bmr, activity: activity)
        var calories = max(extremeLowCalorieFloor, (tdeeValue + goal.calorieDelta).rounded())

        var blockedExtreme = false
        if tdeeValue + goal.calorieDelta < extremeLowCalorieFloor {
            blockedExtreme = true
            calories = extremeLowCalorieFloor
        }

        let proteinG = (weightKg * goal.proteinGramsPerKg).rounded()
        // Fat ~27.5% of calories (mid of 25–30%).
        let fatG = ((calories * 0.275) / 9).rounded()
        let proteinKcal = proteinG * 4
        let fatKcal = fatG * 9
        let carbG = max(0, ((calories - proteinKcal - fatKcal) / 4).rounded())

        let isVeryLow = calories < veryLowCalorieThreshold

        let explanation = """
        BMR (Mifflin-St Jeor): \(Int(bmr.rounded())) kcal/day.
        TDEE (× \(activity.multiplier)): \(Int(tdeeValue.rounded())) kcal/day.
        Goal (\(goal.displayName)): \(Int(goal.calorieDelta)) kcal → target \(Int(calories)) kcal.
        Protein: \(goal.proteinGramsPerKg) g/kg → \(Int(proteinG)) g.
        Fat: ~27.5% of calories → \(Int(fatG)) g.
        Carbs: remainder → \(Int(carbG)) g.
        """

        return GoalCalculationResult(
            bmr: bmr,
            tdee: tdeeValue,
            targets: MacroTargets(
                calories: calories,
                proteinGrams: proteinG,
                fatGrams: fatG,
                carbGrams: carbG
            ),
            explanation: explanation,
            isVeryLowCalorie: isVeryLow,
            blockedExtreme: blockedExtreme
        )
    }
}
