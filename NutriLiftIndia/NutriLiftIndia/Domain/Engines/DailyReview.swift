import Foundation

/// Plain snapshot of one calendar day for end-of-day recap and next-day tips.
struct DaySnapshot: Equatable, Sendable {
    var dayStart: Date
    var dietPref: DietPreference
    var calorieTarget: Double
    var proteinTargetG: Double
    var carbTargetG: Double
    var fatTargetG: Double
    var waterTargetMl: Double
    var stepTarget: Int

    var calories: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double
    var waterMl: Double
    var steps: Double
    var foodEntryCount: Int
    var mealNames: [String]
    var finishedWorkouts: [DayWorkoutBrief]
}

struct DayWorkoutBrief: Equatable, Sendable {
    var name: String
    var setCount: Int
    var durationMinutes: Int
}

/// End-of-day “how you did” and next-morning improvement tips.
/// Numbers come from the snapshot; Foundation Models may only phrase them (`Grounding`).
enum DailyReview {
    static let eveningHour = 17
    static let glassMl = 250.0

    // MARK: Eligibility

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    static func hasLoggedFood(_ snapshot: DaySnapshot) -> Bool {
        snapshot.foodEntryCount > 0 || snapshot.calories > 0
    }

    /// End-of-day card: food logged today and it is evening (or a recap already exists).
    static func shouldShowEndOfDay(
        snapshot: DaySnapshot,
        hasSavedRecap: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard hasLoggedFood(snapshot) else { return false }
        if hasSavedRecap { return true }
        return calendar.component(.hour, from: now) >= eveningHour
    }

    static func shouldShowYesterdayTips(yesterdayHadFood: Bool) -> Bool {
        yesterdayHadFood
    }

    // MARK: Snapshot builder

    static func snapshot(
        day: Date,
        profile: UserProfile,
        diary: [FoodDiaryEntry],
        waterLogs: [WaterLogEntry],
        sessions: [WorkoutSession],
        steps: Double = 0,
        calendar: Calendar = .current
    ) -> DaySnapshot {
        let dayStart = calendar.startOfDay(for: day)
        let macros = DiaryTotals.totals(for: diary, on: day, calendar: calendar)
        let water = HabitStats.waterTotalMl(entries: waterLogs, on: day, calendar: calendar)
        let dayEntries = diary.filter { calendar.isDate($0.date, inSameDayAs: day) }
        let meals = dayEntries
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.displayName)
        let workouts = sessions.filter { session in
            guard session.isFinished, let finished = session.finishedAt else { return false }
            return calendar.isDate(finished, inSameDayAs: day)
        }.map { session -> DayWorkoutBrief in
            let sets = session.sets.filter(\.isCompleted).count
            let minutes: Int
            if let finished = session.finishedAt {
                minutes = max(1, Int(finished.timeIntervalSince(session.startedAt) / 60))
            } else {
                minutes = 0
            }
            return DayWorkoutBrief(name: session.name, setCount: sets, durationMinutes: minutes)
        }

        return DaySnapshot(
            dayStart: dayStart,
            dietPref: profile.dietPref,
            calorieTarget: profile.calorieTarget,
            proteinTargetG: profile.proteinTargetG,
            carbTargetG: profile.carbTargetG,
            fatTargetG: profile.fatTargetG,
            waterTargetMl: profile.waterTargetMl,
            stepTarget: profile.stepTarget,
            calories: macros.calories,
            proteinG: macros.proteinGrams,
            carbG: macros.carbGrams,
            fatG: macros.fatGrams,
            waterMl: water,
            steps: steps,
            foodEntryCount: dayEntries.count,
            mealNames: Array(meals.prefix(12)),
            finishedWorkouts: workouts
        )
    }

    // MARK: Facts (shared)

    static func facts(_ snap: DaySnapshot) -> [String] {
        var lines: [String] = []
        let glasses = Int((snap.waterMl / glassMl).rounded())
        let goalGlasses = max(1, Int((snap.waterTargetMl / glassMl).rounded()))
        let proteinHit = snap.proteinG >= snap.proteinTargetG && snap.proteinTargetG > 0
        let calorieDiff = snap.calorieTarget - snap.calories
        let proteinGap = abs(snap.proteinTargetG - snap.proteinG)

        lines.append(
            "Diet preference: \(snap.dietPref.displayName)."
        )
        lines.append(
            "Calories: ate \(whole(snap.calories)) kcal of \(whole(snap.calorieTarget)) kcal target "
            + "(difference \(whole(abs(calorieDiff))) kcal \(calorieDiff >= 0 ? "under" : "over"))."
        )
        lines.append(
            "Protein: \(whole(snap.proteinG)) g of \(whole(snap.proteinTargetG)) g target"
            + (proteinHit
               ? " (hit target, surplus \(whole(proteinGap)) g)."
               : " (short by \(whole(proteinGap)) g).")
        )
        lines.append(
            "Carbs: \(whole(snap.carbG)) g of \(whole(snap.carbTargetG)) g. "
            + "Fat: \(whole(snap.fatG)) g of \(whole(snap.fatTargetG)) g."
        )
        lines.append(
            "Water: \(glasses) of \(goalGlasses) glasses (\(whole(snap.waterMl)) ml of \(whole(snap.waterTargetMl)) ml)."
        )
        if snap.steps > 0 || snap.stepTarget > 0 {
            lines.append("Steps: \(whole(snap.steps)) of \(snap.stepTarget) step target.")
        }
        lines.append("Food diary entries logged: \(snap.foodEntryCount).")
        if snap.mealNames.isEmpty {
            lines.append("No individual foods listed.")
        } else {
            lines.append("Foods logged include: \(snap.mealNames.joined(separator: ", ")).")
        }
        if snap.finishedWorkouts.isEmpty {
            lines.append("Workouts finished today: 0.")
        } else {
            let totalSets = snap.finishedWorkouts.reduce(0) { $0 + $1.setCount }
            lines.append("Workouts finished today: \(snap.finishedWorkouts.count).")
            lines.append("Total completed sets across workouts: \(totalSets).")
            for w in snap.finishedWorkouts.prefix(4) {
                lines.append(
                    "Workout \"\(w.name)\": \(w.setCount) sets in \(w.durationMinutes) minutes."
                )
            }
        }
        return lines
    }

    // MARK: End-of-day recap

    static let recapInstructions = """
    You are a warm, encouraging coach inside an Indian fitness app. \
    Write a short end-of-day review in second person. \
    Cover food, water, and workouts using ONLY the facts. \
    At most 120 words and at most three emoji. \
    Be honest about misses without shaming. Celebrate hits. \
    Use ONLY the facts provided and quote numbers exactly as given. \
    Never invent, round, convert or add any other number, and do not do any maths. \
    Do not give medical advice or recommend supplements.
    """

    static func recapPrompt(_ snap: DaySnapshot) -> String {
        let bullets = facts(snap).map { "- \($0)" }.joined(separator: "\n")
        return """
        Facts about the user's day:
        \(bullets)

        Write the end-of-day review now.
        """
    }

    static func recapFallback(_ snap: DaySnapshot) -> String {
        let glasses = Int((snap.waterMl / glassMl).rounded())
        let goalGlasses = max(1, Int((snap.waterTargetMl / glassMl).rounded()))
        let proteinHit = snap.proteinG >= snap.proteinTargetG && snap.proteinTargetG > 0
        let calorieDiff = snap.calorieTarget - snap.calories

        var parts: [String] = []
        var food = "You logged \(snap.foodEntryCount) foods for \(whole(snap.calories)) kcal "
            + "against a \(whole(snap.calorieTarget)) kcal target"
        if calorieDiff >= 0 {
            food += " (\(whole(calorieDiff)) kcal under)."
        } else {
            food += " (\(whole(-calorieDiff)) kcal over)."
        }
        food += proteinHit
            ? " Protein hit: \(whole(snap.proteinG)) g of \(whole(snap.proteinTargetG)) g 🥚"
            : " Protein was \(whole(snap.proteinG)) g of \(whole(snap.proteinTargetG)) g — room to add dal, paneer or curd next meal."
        parts.append(food)

        var water = "Water: \(glasses) of \(goalGlasses) glasses."
        if glasses >= goalGlasses {
            water += " Nice hydration today 💧"
        } else {
            water += " A couple more glasses would close the gap."
        }
        parts.append(water)

        if snap.finishedWorkouts.isEmpty {
            parts.append("No finished workout today — rest days count too. If you train tomorrow, keep it simple and consistent 💪")
        } else {
            let names = snap.finishedWorkouts.map(\.name).joined(separator: ", ")
            let sets = snap.finishedWorkouts.reduce(0) { $0 + $1.setCount }
            parts.append("Training: \(snap.finishedWorkouts.count) workout(s) (\(names)) with \(sets) sets logged. Solid work showing up.")
        }
        return parts.joined(separator: "\n\n")
    }

    // MARK: Next-day tips (from yesterday)

    static let tipsInstructions = """
    You are a warm, practical coach inside an Indian fitness app. \
    Write short suggestions for TODAY based on YESTERDAY's facts. \
    Give 2 or 3 concrete tips (food, water, or training) in second person. \
    Prefer Indian household foods (roti, dal, paneer, curd, eggs if diet allows). \
    At most 100 words and at most three emoji. \
    Use ONLY the facts provided and quote numbers exactly as given. \
    Never invent, round, convert or add any other number, and do not do any maths. \
    Do not give medical advice or recommend supplements.
    """

    static func tipsPrompt(_ yesterday: DaySnapshot) -> String {
        let bullets = facts(yesterday).map { "- \($0)" }.joined(separator: "\n")
        return """
        Facts about YESTERDAY (use these to suggest what to improve today):
        \(bullets)

        Write today's improvement suggestions now.
        """
    }

    static func tipsFallback(_ yesterday: DaySnapshot) -> String {
        var tips: [String] = []
        let proteinShort = yesterday.proteinTargetG - yesterday.proteinG
        if proteinShort > 10 {
            tips.append(
                "Yesterday protein was \(whole(yesterday.proteinG)) g vs \(whole(yesterday.proteinTargetG)) g. "
                + "Today aim for an extra \(whole(proteinShort)) g — try \(InsightsEngine.highProteinSuggestions(for: yesterday.dietPref))."
            )
        } else if yesterday.proteinG >= yesterday.proteinTargetG {
            tips.append(
                "Protein was on point yesterday (\(whole(yesterday.proteinG)) g). Keep that pattern with another solid dal or paneer meal today."
            )
        }

        let glasses = Int((yesterday.waterMl / glassMl).rounded())
        let goalGlasses = max(1, Int((yesterday.waterTargetMl / glassMl).rounded()))
        if glasses < goalGlasses {
            tips.append(
                "Hydration was \(glasses) of \(goalGlasses) glasses. Start today with a glass after waking and one with each meal 💧"
            )
        }

        if yesterday.finishedWorkouts.isEmpty {
            tips.append("No workout yesterday — if energy is good, schedule a short session today and keep protein steady around it 💪")
        } else {
            tips.append("You trained yesterday — prioritise sleep, carbs around meals, and easy movement today so you recover well.")
        }

        let calorieDiff = yesterday.calorieTarget - yesterday.calories
        if calorieDiff < -200 {
            tips.append(
                "Calories ran \(whole(-calorieDiff)) kcal over yesterday. Today portion rice/roti with a katori measure and keep oils light."
            )
        } else if calorieDiff > 300 && yesterday.foodEntryCount > 0 {
            tips.append(
                "You finished \(whole(calorieDiff)) kcal under yesterday. If hunger was high, add a snack like curd + fruit or roasted chana."
            )
        }

        if tips.isEmpty {
            tips.append(
                "Yesterday looked balanced. Repeat what worked: log meals early, hit \(whole(yesterday.proteinTargetG)) g protein, and drink \(goalGlasses) glasses of water."
            )
        }
        return tips.prefix(3).joined(separator: "\n\n")
    }

    private static func whole(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
