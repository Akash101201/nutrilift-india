import Foundation

/// Builds the plain-language "why these numbers" story for one person.
///
/// The numbers always come from `GoalEngine`. An on-device language model may only *phrase*
/// them: its answer is accepted only if every number it states appears in the facts we gave it
/// (`isGrounded`). Otherwise, and on devices without the model, `fallbackText` is shown.
enum TargetExplanation {
    // MARK: Facts

    /// Everything the explanation may talk about, one plain sentence per line.
    static func facts(input: GoalInput, result: GoalCalculationResult) -> [String] {
        let t = result.targets
        let calories = max(t.calories, 1)
        let proteinPct = pct(t.proteinGrams * 4, of: calories)
        let carbPct = pct(t.carbGrams * 4, of: calories)
        let fatPct = pct(t.fatGrams * 9, of: calories)
        let perKg = t.proteinGrams / input.weightKg
        let deltaKcal = result.tdee - t.calories
        let deltaPct = result.tdee > 0 ? abs(deltaKcal) / result.tdee * 100 : 0
        let weeklyKg = abs(deltaKcal) * 7 / 7700

        var lines: [String] = []
        lines.append(
            "About them: age \(input.age), \(whole(input.heightCm)) cm, \(oneDecimal(input.weightKg)) kg, "
            + "activity level \"\(input.activity.displayName.lowercased())\" (\(input.activity.detail.lowercased()))."
        )

        var bmrLine = "Resting burn (BMR): \(whole(result.bmr)) kcal a day, from the \(result.formula.displayName) formula."
        if let lean = leanMass(input) {
            bmrLine += " It used their lean mass of \(oneDecimal(lean)) kg, which makes it more personal than a height-and-weight formula."
        }
        lines.append(bmrLine)

        lines.append(
            "Daily burn (TDEE): \(whole(result.tdee)) kcal, which is resting burn times \(multiplierText(input.activity.multiplier)) for their activity level."
        )

        if deltaPct < 0.5 {
            lines.append("Goal: stay at the same weight, so the target equals the daily burn.")
        } else if deltaKcal > 0 {
            lines.append(
                "Goal: lose weight at a \(input.pace.displayName.lowercased()) pace. The target is \(whole(deltaPct)) percent "
                + "(\(whole(deltaKcal)) kcal) below the daily burn, roughly \(oneDecimal(weeklyKg)) kg a week. "
                + "It is a percentage of their own burn, so it suits their body size."
            )
        } else {
            lines.append(
                "Goal: gain weight at a \(input.pace.displayName.lowercased()) pace. The target is \(whole(deltaPct)) percent "
                + "(\(whole(-deltaKcal)) kcal) above the daily burn, roughly \(oneDecimal(weeklyKg)) kg a week."
            )
        }

        lines.append("Daily calorie target: \(whole(t.calories)) kcal.")
        if result.floorApplied {
            lines.append("The target was raised to a safe minimum because the app never sets calories lower than that automatically.")
        }
        for note in result.notes where !note.contains("lifted your target") {
            lines.append("Note: \(note)")
        }

        var proteinLine = "Protein target: \(whole(t.proteinGrams)) g a day, about \(oneDecimal(perKg)) g per kg of body weight."
        switch proteinBasis(input) {
        case .lean:
            proteinLine += " It is based on lean mass, so extra body fat does not inflate it."
        case .adjusted:
            proteinLine += " It is based on an adjusted weight, not full body weight, so it is not inflated."
        case .total:
            break
        }
        switch input.diet {
        case .veg, .jain:
            proteinLine += " Their diet is \(input.diet.displayName.lowercased()), and plant protein is a bit less digestible, so it is set about 10 percent higher."
        case .eggetarian:
            proteinLine += " Their diet is eggetarian, so it is set about 5 percent higher for plant protein."
        case .nonVeg, .custom:
            break
        }
        lines.append(proteinLine)

        lines.append(
            "Macro split: protein \(proteinPct) percent, carbs \(whole(t.carbGrams)) g (\(carbPct) percent), "
            + "fat \(whole(t.fatGrams)) g (\(fatPct) percent) of calories. Carbs fill what is left after protein and fat."
        )
        lines.append(
            "Fiber target: \(whole(result.fiberGrams)) g. Water target: \(whole(result.waterMl / 250)) glasses of 250 ml."
        )

        switch result.accuracy {
        case .basic:
            lines.append("Accuracy: basic. It uses age, height, weight, sex and activity. Adding body fat or lean mass would make it more personal.")
        case .good:
            lines.append("Accuracy: good. It used their body fat estimate.")
        case .sharp:
            lines.append("Accuracy: sharp. It used their lean mass.")
        }
        return lines
    }

    static let instructions = """
    You are a warm, encouraging nutrition coach inside an Indian fitness app. \
    Explain to the user, in second person, why their daily targets were calculated the way they were, \
    so they feel the numbers are personal to them. \
    Use simple, friendly English in two short paragraphs, at most 130 words, with at most three emoji. \
    Use ONLY the facts provided and quote numbers exactly as given. \
    Never invent, round, convert or add any other number, and do not do any maths. \
    Do not give medical advice, diagnose anything or recommend supplements. \
    Treat the numbers as helpful estimates, not guarantees.
    """

    static func prompt(input: GoalInput, result: GoalCalculationResult) -> String {
        let bullets = facts(input: input, result: result).map { "- \($0)" }.joined(separator: "\n")
        return """
        Facts about this user and their calculated targets:
        \(bullets)

        Write the explanation now. Focus on what makes these targets personal to this user, \
        such as their body, activity, goal pace and diet.
        """
    }

    // MARK: Grounding check

    /// True when every number in `text` also appears in `facts` (or is a tiny count like 1-3).
    static func isGrounded(_ text: String, facts: [String]) -> Bool {
        var allowed: [Double] = [0, 1, 2, 3]
        for line in facts { allowed.append(contentsOf: numbers(in: line)) }
        for value in numbers(in: text) {
            guard allowed.contains(where: { abs($0 - value) < 0.06 }) else { return false }
        }
        return true
    }

    /// Cleans a model answer and returns it only if it is usable and grounded.
    static func validated(_ text: String, facts: [String]) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 40, trimmed.count <= 1200 else { return nil }
        guard isGrounded(trimmed, facts: facts) else { return nil }
        return trimmed
    }

    /// Numbers as written in `text`: "1,682" -> 1682, "1.65" -> 1.65.
    static func numbers(in text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: #"\d+(?:,\d{3})*(?:\.\d+)?"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return Double(text[r].replacingOccurrences(of: ",", with: ""))
        }
    }

    // MARK: Fallback

    /// Personalised explanation written from the same facts, with no model involved.
    static func fallbackText(input: GoalInput, result: GoalCalculationResult) -> String {
        let t = result.targets
        let deltaKcal = result.tdee - t.calories
        let deltaPct = result.tdee > 0 ? abs(deltaKcal) / result.tdee * 100 : 0
        let weeklyKg = abs(deltaKcal) * 7 / 7700
        let perKg = t.proteinGrams / input.weightKg

        var first = "Your body uses about \(whole(result.bmr)) kcal a day at rest. "
        if leanMass(input) != nil {
            first += "We worked that out from your lean mass, so it is based on you and not just your height and weight. "
        }
        first += "Adding your \(input.activity.displayName.lowercased()) lifestyle brings your daily burn to about \(whole(result.tdee)) kcal."

        var second: String
        if deltaPct < 0.5 {
            second = "You want to stay where you are, so your target matches that burn: \(whole(t.calories)) kcal a day."
        } else if deltaKcal > 0 {
            second = "To lose weight at a \(input.pace.displayName.lowercased()) pace, we set your target \(whole(deltaPct)) percent below your burn, "
                + "at \(whole(t.calories)) kcal a day. That is roughly \(oneDecimal(weeklyKg)) kg a week, and because it is a percentage of your own burn it suits your body size."
        } else {
            second = "To gain weight at a \(input.pace.displayName.lowercased()) pace, we set your target \(whole(deltaPct)) percent above your burn, "
                + "at \(whole(t.calories)) kcal a day, roughly \(oneDecimal(weeklyKg)) kg a week."
        }
        if result.floorApplied {
            second += " We raised it to a safe minimum, because we never go lower than that automatically."
        }

        var third = "Your protein is \(whole(t.proteinGrams)) g, about \(oneDecimal(perKg)) g per kg of body weight"
        switch proteinBasis(input) {
        case .lean: third += ", based on your lean mass"
        case .adjusted: third += ", based on an adjusted weight so it is not inflated"
        case .total: break
        }
        switch input.diet {
        case .veg, .jain: third += ". As you eat \(input.diet.displayName.lowercased()), it is set about 10 percent higher because plant protein is less digestible"
        case .eggetarian: third += ". As an eggetarian, it is set about 5 percent higher for plant protein"
        case .nonVeg, .custom: break
        }
        third += ". Fat is \(whole(t.fatGrams)) g and carbs are \(whole(t.carbGrams)) g, which fill the rest. "
            + "Aim for \(whole(result.fiberGrams)) g of fiber and \(whole(result.waterMl / 250)) glasses of water."

        var closing = ""
        switch result.accuracy {
        case .basic: closing = " These use your age, height, weight and activity. Adding body fat or lean mass would make them even more personal."
        case .good: closing = " These also use your body fat estimate."
        case .sharp: closing = " These also use your lean mass, so they are as personal as it gets."
        }
        return "\(first)\n\n\(second) \(third)\(closing)"
    }

    // MARK: Helpers

    private enum ProteinBasis { case lean, adjusted, total }

    private static func proteinBasis(_ input: GoalInput) -> ProteinBasis {
        if leanMass(input) != nil { return .lean }
        if GoalEngine.bmi(weightKg: input.weightKg, heightCm: input.heightCm) >= 25 { return .adjusted }
        return .total
    }

    private static func leanMass(_ input: GoalInput) -> Double? {
        if let lean = input.leanMassKg { return lean }
        if let bf = input.bodyFatPercent { return input.weightKg * (1 - bf / 100) }
        return nil
    }

    private static func pct(_ part: Double, of total: Double) -> Int {
        Int((part / total * 100).rounded())
    }

    private static func whole(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    // Pinned to a fixed locale so the text always uses "." and the grounding check can parse it.
    private static let posix = Locale(identifier: "en_US_POSIX")

    private static func oneDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).grouping(.never).locale(posix))
    }

    private static func multiplierText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)).grouping(.never).locale(posix))
    }
}
