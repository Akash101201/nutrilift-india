import Foundation

/// Calculates daily calorie, macro, fiber and water targets.
///
/// General wellness estimates, not medical advice. Several constants below are
/// judgment calls inside published ranges (marked "judgment call"), not sourced values.
enum GoalEngine {
    // MARK: Input limits

    static let weightRange: ClosedRange<Double> = 30...300
    static let heightRange: ClosedRange<Double> = 120...230
    static let ageRange: ClosedRange<Int> = 15...90
    static let bodyFatRange: ClosedRange<Double> = 3...60

    // MARK: Tunables

    /// Never plan to lose faster than about 1% of body weight a week
    /// (1 kg of body fat is roughly 7700 kcal).
    private static let maxWeeklyLossFraction = 0.01
    private static let kcalPerKgFat = 7700.0
    /// Share of calories for fat, within the usual 20-35% range. Judgment call.
    private static let fatShare = 0.27
    private static let minFatShare = 0.20
    private static let minFatGramsPerKg = 0.6
    private static let minCarbShare = 0.30
    private static let maxProteinShare = 0.35
    private static let fiberGramsPer1000Kcal = 14.0
    private static let minFiberGrams = 25.0
    private static let waterMlPerKg = 35.0
    private static let waterGlassMl = 250.0

    // MARK: Building blocks

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

    static func katchMcArdleBMR(leanMassKg: Double) -> Double {
        370 + 21.6 * leanMassKg
    }

    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    /// Devine ideal body weight, in kg.
    static func idealWeightKg(heightCm: Double, sex: BiologicalSex) -> Double {
        let inchesOver60 = max(0, heightCm / 2.54 - 60)
        let male = 50 + 2.3 * inchesOver60
        let female = 45.5 + 2.3 * inchesOver60
        switch sex {
        case .male: return male
        case .female: return female
        case .other: return (male + female) / 2
        }
    }

    /// Protein per kg of the protein basis weight. Judgment call inside the ISSN
    /// (1.4-2.0 g/kg for exercisers) and ICMR-NIN (about 0.8-1.0 g/kg for sedentary adults) ranges.
    static func proteinGramsPerKg(goal: FitnessGoal, activity: ActivityLevel) -> Double {
        let maintain: Double
        switch activity {
        case .sedentary: maintain = 0.9
        case .light: maintain = 1.0
        case .moderate: maintain = 1.1
        case .active: maintain = 1.3
        case .veryActive: maintain = 1.4
        }
        switch goal {
        case .maintain: return maintain
        case .lose: return min(maintain + 0.4, 1.8)   // extra protein protects muscle in a deficit
        case .gain: return min(maintain + 0.3, 1.7)
        }
    }

    static func validate(_ input: GoalInput) throws {
        guard weightRange.contains(input.weightKg) else { throw GoalEngineError.weight }
        guard heightRange.contains(input.heightCm) else { throw GoalEngineError.height }
        guard ageRange.contains(input.age) else { throw GoalEngineError.age }
        if let bf = input.bodyFatPercent, !bodyFatRange.contains(bf) {
            throw GoalEngineError.bodyFat
        }
        if let lean = input.leanMassKg {
            let plausible = lean >= input.weightKg * 0.4 && lean <= input.weightKg * 0.97
            guard plausible else { throw GoalEngineError.leanMass }
        }
    }

    // MARK: Main entry point

    static func calculate(_ input: GoalInput) throws -> GoalCalculationResult {
        try validate(input)

        let weight = input.weightKg
        var notes: [String] = []

        // 1. Body composition (all optional).
        var leanKg: Double?
        var accuracy = AccuracyLevel.basic
        if let lean = input.leanMassKg {
            leanKg = lean
            accuracy = .sharp
        } else if let bf = input.bodyFatPercent {
            leanKg = weight * (1 - bf / 100)
            accuracy = .good
        }

        // 2. BMR and TDEE.
        let formula: BMRFormula
        let bmr: Double
        if let lean = leanKg {
            formula = .katchMcArdle
            bmr = katchMcArdleBMR(leanMassKg: lean)
        } else {
            formula = .mifflinStJeor
            bmr = mifflinStJeorBMR(weightKg: weight, heightCm: input.heightCm, age: input.age, sex: input.sex)
        }
        let tdeeValue = tdee(bmr: bmr, activity: input.activity)

        // 3. Goal and pace, with the under-18 rule.
        var goal = input.goal
        var pace = input.pace
        if input.age < 18 {
            if goal == .lose {
                goal = .maintain
                notes.append("You're still growing, so we've set a maintenance target instead of a deficit. A doctor or dietitian can give you personal advice.")
            } else if goal == .gain, pace != .gentle {
                pace = .gentle
                notes.append("We've used a gentle pace because you're still growing.")
            }
        }

        let fraction = pace.fraction(for: goal)
        var signedDelta = 0.0
        switch goal {
        case .lose:
            let cap = weight * maxWeeklyLossFraction * kcalPerKgFat / 7
            signedDelta = -min(tdeeValue * fraction, cap)
        case .gain:
            signedDelta = tdeeValue * fraction
        case .maintain:
            break
        }
        let rawTarget = (tdeeValue + signedDelta).rounded()

        // 4. Safety floor, never pushing a target above maintenance.
        let calorieFloor = input.sex.calorieFloor
        var calories = rawTarget
        var floorApplied = false
        if calories < calorieFloor {
            calories = min(calorieFloor, tdeeValue.rounded())
            floorApplied = calories > rawTarget
        }
        if floorApplied {
            notes.append("We lifted your target to \(Int(calories)) kcal. We won't set it lower automatically.")
        }
        if calories < calorieFloor {
            notes.append("Your estimated needs are quite low. Check with a doctor or dietitian before dieting.")
        }

        // 5. Protein basis weight.
        let basisKg: Double
        let basisLabel: String
        if let lean = leanKg {
            basisKg = min(lean / 0.8, weight)
            basisLabel = "your lean mass"
        } else if bmi(weightKg: weight, heightCm: input.heightCm) >= 25 {
            let ideal = idealWeightKg(heightCm: input.heightCm, sex: input.sex)
            basisKg = min(ideal + 0.25 * (weight - ideal), weight)
            basisLabel = "an adjusted weight"
        } else {
            basisKg = weight
            basisLabel = "your weight"
        }

        let perKg = proteinGramsPerKg(goal: goal, activity: input.activity)
        let dietMultiplier = input.diet.proteinMultiplier
        var protein = min(basisKg * perKg * dietMultiplier, calories * maxProteinShare / 4)
        var fat = max(calories * fatShare / 9, basisKg * minFatGramsPerKg)

        // 6. Keep carbs at a sensible minimum by trimming fat, then protein, so the
        // macros always add up to the calorie target.
        let room = calories - calories * minCarbShare
        if protein * 4 + fat * 9 > room {
            let fatMin = calories * minFatShare / 9
            fat = max(fatMin, min(fat, (room - protein * 4) / 9))
            if protein * 4 + fat * 9 > room {
                protein = max(0, (room - fat * 9) / 4)
            }
        }
        let proteinG = protein.rounded()
        let fatG = fat.rounded()
        let carbG = max(0, ((calories - proteinG * 4 - fatG * 9) / 4).rounded())

        // 7. Fiber and water.
        let fiberG = max(minFiberGrams, (calories / 1000 * fiberGramsPer1000Kcal).rounded())
        let waterBonus: Double
        switch input.activity {
        case .sedentary: waterBonus = 0
        case .light: waterBonus = 250
        case .moderate: waterBonus = 500
        case .active: waterBonus = 750
        case .veryActive: waterBonus = 1000
        }
        let waterRaw = weight * waterMlPerKg + waterBonus
        let waterMl = min(5000, max(1500, (waterRaw / waterGlassMl).rounded() * waterGlassMl))

        // 8. Explainer rows.
        let goalValue: String
        let goalDetail: String
        switch goal {
        case .maintain:
            goalValue = "Stay put"
            goalDetail = "Eating at your daily burn keeps your weight steady."
        case .lose:
            // Show the deficit actually applied, which is smaller than planned if the safety floor kicked in.
            let applied = max(0, tdeeValue - calories)
            if applied < 0.5 {
                goalValue = "No deficit"
                goalDetail = "Your safe minimum is about what you burn, so we kept you at maintenance."
            } else {
                goalValue = "−\(Int(applied.rounded())) kcal (\(Int((applied / tdeeValue * 100).rounded()))%)"
                goalDetail = floorApplied
                    ? "A smaller cut than the \(pace.displayName.lowercased()) pace, because we never go below a safe minimum."
                    : "\(pace.displayName) pace, a share of your daily burn so it fits your body size."
            }
        case .gain:
            let applied = max(0, calories - tdeeValue)
            goalValue = "+\(Int(applied.rounded())) kcal (\(Int((applied / tdeeValue * 100).rounded()))%)"
            goalDetail = "\(pace.displayName) pace, a small surplus to build without too much fat."
        }

        let perKgText = String(format: "%.2f", perKg * dietMultiplier)
        var proteinDetail = "\(perKgText) g per kg of \(basisLabel)."
        if dietMultiplier > 1 {
            proteinDetail += " Includes a small boost for plant-based protein."
        }

        let breakdown = [
            BreakdownRow(
                emoji: "🔥",
                title: "Resting burn",
                value: "\(Int(bmr.rounded())) kcal",
                detail: "What your body uses at rest, from the \(formula.displayName) formula."
            ),
            BreakdownRow(
                emoji: input.activity.emoji,
                title: "Daily burn",
                value: "\(Int(tdeeValue.rounded())) kcal",
                detail: "Resting burn × \(String(format: "%.3g", input.activity.multiplier)) for \(input.activity.displayName.lowercased())."
            ),
            BreakdownRow(emoji: goal.emoji, title: "Your goal", value: goalValue, detail: goalDetail),
            BreakdownRow(
                emoji: "🍽️",
                title: "Daily target",
                value: "\(Int(calories)) kcal",
                detail: floorApplied ? "Raised to a safe minimum." : "Your goal applied to your daily burn."
            ),
            BreakdownRow(emoji: "🥚", title: "Protein", value: "\(Int(proteinG)) g", detail: proteinDetail),
            BreakdownRow(emoji: "🥑", title: "Fat", value: "\(Int(fatG)) g", detail: "About a quarter of your calories, enough for hormones and vitamins."),
            BreakdownRow(emoji: "🍚", title: "Carbs", value: "\(Int(carbG)) g", detail: "The rest of your calories, fuel for training and the brain."),
            BreakdownRow(emoji: "🌾", title: "Fiber", value: "\(Int(fiberG)) g", detail: "About 14 g per 1000 kcal, with a minimum of 25 g."),
            BreakdownRow(
                emoji: "💧",
                title: "Water",
                value: "\(Int(waterMl / waterGlassMl)) glasses",
                detail: "About 35 ml per kg plus extra for activity."
            ),
        ]

        return GoalCalculationResult(
            bmr: bmr,
            tdee: tdeeValue,
            formula: formula,
            accuracy: accuracy,
            targets: MacroTargets(
                calories: calories,
                proteinGrams: proteinG,
                fatGrams: fatG,
                carbGrams: carbG
            ),
            fiberGrams: fiberG,
            waterMl: waterMl,
            floorApplied: floorApplied,
            breakdown: breakdown,
            notes: notes
        )
    }
}
