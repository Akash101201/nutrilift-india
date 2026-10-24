import Foundation

/// Builds the grounded context pack and rule-based fallback for Coach chat.
enum CoachChat {
    static let quickPrompts = [
        "How many calories remaining today?",
        "How much protein remaining?",
        "How is my weekly volume?",
        "Suggest a high-protein meal",
    ]

    static let welcomeText =
        "Hi! I'm your coach 👋 Ask about calories, protein, weekly volume, workouts, or Indian meal ideas. I use your on-device logs — nothing leaves your phone."

    static let instructions = """
    You are NutriLift India's fitness coach. You help with calories, macros, Indian food ideas, \
    workouts, and weekly training volume.
    Rules:
    - Use ONLY the numbers listed in FACTS. Never invent calories, grams, sets, or weights.
    - Prefer Indian household foods and units (roti, katori, dal, paneer, curd).
    - Respect the user's diet preference from FACTS.
    - Be brief, encouraging, and direct. No shaming.
    - Not medical advice. Refuse extreme deficits, crash diets, or disordered-eating tips.
    - If FACTS lack what you need, say what to log in the app instead of guessing numbers.
    - For meal ideas, name foods without inventing exact kcal unless those numbers appear in FACTS.
    """

    // MARK: Context pack

    struct Context: Equatable, Sendable {
        var facts: [String]
        var promptBody: String
    }

    static func context(
        profile: UserProfile?,
        diary: [FoodDiaryEntry],
        sessions: [WorkoutSession],
        templates: [WorkoutTemplate],
        history: [(isUser: Bool, text: String)],
        question: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Context {
        let facts = facts(
            profile: profile,
            diary: diary,
            sessions: sessions,
            templates: templates,
            now: now,
            calendar: calendar
        )
        var lines: [String] = []
        lines.append("FACTS (authoritative — use only these numbers):")
        for fact in facts {
            lines.append("- \(fact)")
        }
        if !history.isEmpty {
            lines.append("")
            lines.append("Recent conversation:")
            for turn in history.suffix(12) {
                lines.append("\(turn.isUser ? "User" : "Coach"): \(turn.text)")
            }
        }
        lines.append("")
        lines.append("User's new message: \(question)")
        lines.append("Reply as the coach in plain language.")
        return Context(facts: facts, promptBody: lines.joined(separator: "\n"))
    }

    static func facts(
        profile: UserProfile?,
        diary: [FoodDiaryEntry],
        sessions: [WorkoutSession],
        templates: [WorkoutTemplate],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        var lines: [String] = []
        guard let profile else {
            lines.append("User has not finished onboarding. Ask them to complete profile setup.")
            return lines
        }

        let consumed = DiaryTotals.totals(for: diary, on: now, calendar: calendar)
        let remaining = DiaryTotals.remaining(targets: profile.targets, consumed: consumed)
        let (proteinHits, proteinWindow) = DiaryTotals.proteinHitDays(
            entries: diary,
            proteinTarget: profile.proteinTargetG,
            windowDays: 7,
            calendar: calendar,
            now: now
        )

        lines.append(
            "Profile: age \(profile.age), weight \(oneDecimal(profile.weightKg)) kg, "
            + "goal \(profile.goal.displayName.lowercased()), diet \(profile.dietPref.displayName), "
            + "activity \(profile.activity.displayName.lowercased())."
        )
        lines.append(
            "Daily targets: \(whole(profile.calorieTarget)) kcal, "
            + "\(whole(profile.proteinTargetG)) g protein, "
            + "\(whole(profile.carbTargetG)) g carbs, "
            + "\(whole(profile.fatTargetG)) g fat, "
            + "\(profile.stepTarget) steps."
        )
        lines.append(
            "Eaten today: \(whole(consumed.calories)) kcal, "
            + "\(whole(consumed.proteinGrams)) g protein, "
            + "\(whole(consumed.carbGrams)) g carbs, "
            + "\(whole(consumed.fatGrams)) g fat."
        )
        lines.append(
            "Remaining today: \(whole(remaining.calories)) kcal, "
            + "\(whole(remaining.proteinGrams)) g protein, "
            + "\(whole(remaining.carbGrams)) g carbs, "
            + "\(whole(remaining.fatGrams)) g fat."
        )
        lines.append("Protein target hit on \(proteinHits) of \(proteinWindow) days this week.")
        lines.append("High-protein \(profile.dietPref.displayName) ideas: \(InsightsEngine.highProteinSuggestions(for: profile.dietPref)).")

        let finished = sessions.filter(\.isFinished)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let workoutsThisWeek = finished.filter { ($0.finishedAt ?? $0.startedAt) >= weekStart }.count
        lines.append("Finished workouts this week: \(workoutsThisWeek).")

        let vol = VolumeAggregator.weeklySets(sessions: finished, weekOf: now, calendar: calendar)
        if vol.isEmpty {
            lines.append("Weekly muscle volume: no finished sets logged this week yet.")
        } else {
            let summary = vol.prefix(8).map { "\($0.muscleGroup.displayName) \($0.sets) sets" }.joined(separator: "; ")
            lines.append("Weekly muscle volume: \(summary).")
        }

        if let last = finished.max(by: { ($0.finishedAt ?? $0.startedAt) < ($1.finishedAt ?? $1.startedAt) }) {
            let when = (last.finishedAt ?? last.startedAt)
            lines.append("Last workout: \(last.name) on \(dayStamp(when, calendar: calendar)) with \(last.sets.filter(\.isCompleted).count) completed sets.")
        }

        if !templates.isEmpty {
            let names = templates.prefix(6).map(\.name).joined(separator: ", ")
            lines.append("Available workout templates: \(names).")
        }

        let insights = InsightsEngine.generate(
            context: .init(
                dietPref: profile.dietPref,
                targets: profile.targets,
                diaryEntries: diary,
                sessions: sessions,
                calendar: calendar,
                now: now
            )
        )
        if insights.isEmpty {
            lines.append("No special coaching alerts right now.")
        } else {
            for insight in insights.prefix(4) {
                lines.append("Insight — \(insight.title): \(insight.body)")
            }
        }

        return lines
    }

    // MARK: Rule-based fallback

    static func ruleBasedAnswer(
        question: String,
        profile: UserProfile?,
        diary: [FoodDiaryEntry],
        sessions: [WorkoutSession],
        templates: [WorkoutTemplate],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let q = question.lowercased()
        guard let profile else {
            return "Finish onboarding so I can use your targets."
        }
        let consumed = DiaryTotals.totals(for: diary, on: now, calendar: calendar)
        let remaining = DiaryTotals.remaining(targets: profile.targets, consumed: consumed)

        if q.contains("calorie") || q.contains("kcal") {
            return "You have about \(whole(remaining.calories)) kcal remaining today (target \(whole(profile.calorieTarget)), eaten \(whole(consumed.calories))). Estimates only — not medical advice."
        }
        if q.contains("protein") {
            return "Protein remaining: about \(whole(remaining.proteinGrams)) g (target \(whole(profile.proteinTargetG)) g). Ideas for \(profile.dietPref.displayName): \(InsightsEngine.highProteinSuggestions(for: profile.dietPref))."
        }
        if q.contains("volume") || q.contains("muscle") {
            let vol = VolumeAggregator.weeklySets(sessions: sessions.filter(\.isFinished), weekOf: now, calendar: calendar)
            if vol.isEmpty {
                return "No finished sets this week yet. Try a template like \(templates.first?.name ?? "Full Body A")."
            }
            let summary = vol.prefix(5).map { "\($0.muscleGroup.displayName): \($0.sets)" }.joined(separator: ", ")
            return "This week's sets — \(summary)."
        }
        if q.contains("meal") || q.contains("eat") || q.contains("food") {
            return "Simple \(profile.dietPref.displayName) ideas: \(InsightsEngine.highProteinSuggestions(for: profile.dietPref)). Log with favorites or a meal template for speed."
        }
        if q.contains("workout") || q.contains("train") {
            return "Next idea: \(templates.first?.name ?? "any template") in the Workouts tab. Keep rest times honest and chase small PRs."
        }
        return "I can help with remaining calories/protein, weekly volume, and meal ideas. Try one of the quick questions. Not medical advice."
    }

    static func title(from firstUserMessage: String) -> String {
        let trimmed = firstUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "New chat" }
        if trimmed.count <= 42 { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: 42)
        return String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func whole(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}
