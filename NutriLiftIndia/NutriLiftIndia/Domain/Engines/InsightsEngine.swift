import Foundation

struct Insight: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var body: String
}

enum InsightsEngine {
    struct Context {
        var dietPref: DietPreference
        var targets: MacroTargets
        var diaryEntries: [FoodDiaryEntry]
        var sessions: [WorkoutSession]
        var calendar: Calendar = .current
        var now: Date = Date()
    }

    static func generate(context: Context) -> [Insight] {
        var insights: [Insight] = []
        insights.append(contentsOf: proteinMissInsight(context))
        insights.append(contentsOf: calorieConsistencyInsight(context))
        insights.append(contentsOf: volumeDropInsight(context))
        insights.append(contentsOf: stallInsight(context))
        insights.append(contentsOf: deficitTrainingInsight(context))
        insights.append(contentsOf: carbBalanceInsight(context))
        insights.append(contentsOf: workoutFrequencyInsight(context))
        insights.append(contentsOf: fatTargetInsight(context))
        return insights
    }

    private static func proteinMissInsight(_ ctx: Context) -> [Insight] {
        let (hit, total) = DiaryTotals.proteinHitDays(
            entries: ctx.diaryEntries,
            proteinTarget: ctx.targets.proteinGrams,
            windowDays: 7,
            calendar: ctx.calendar,
            now: ctx.now
        )
        let misses = total - hit
        guard misses >= 3 else { return [] }
        let suggestions = highProteinSuggestions(for: ctx.dietPref)
        return [Insight(
            id: "protein_miss",
            title: "Protein under target most days",
            body: "You hit your protein target on \(hit)/\(total) days this week (target \(Int(ctx.targets.proteinGrams)) g). Try adding: \(suggestions)."
        )]
    }

    private static func calorieConsistencyInsight(_ ctx: Context) -> [Insight] {
        var daysLogged = 0
        for offset in 0..<7 {
            guard let day = ctx.calendar.date(byAdding: .day, value: -offset, to: ctx.now) else { continue }
            let cals = DiaryTotals.totals(for: ctx.diaryEntries, on: day, calendar: ctx.calendar).calories
            if cals > 0 { daysLogged += 1 }
        }
        guard daysLogged > 0, daysLogged < 4 else { return [] }
        return [Insight(
            id: "log_consistency",
            title: "Logging is light this week",
            body: "Food was logged on \(daysLogged)/7 days. Even rough logs help trends stay useful — no need for perfect days."
        )]
    }

    private static func volumeDropInsight(_ ctx: Context) -> [Insight] {
        let thisWeek = VolumeAggregator.weeklySets(sessions: ctx.sessions, weekOf: ctx.now, calendar: ctx.calendar)
        let avg = VolumeAggregator.averageWeeklySets(sessions: ctx.sessions, weeks: 4, endingAt: ctx.now, calendar: ctx.calendar)
        var drops: [String] = []
        for item in thisWeek {
            guard let baseline = avg[item.muscleGroup], baseline >= 4 else { continue }
            let drop = (baseline - Double(item.sets)) / baseline
            if drop > 0.25 {
                drops.append("\(item.muscleGroup.displayName) (\(item.sets) sets vs ~\(Int(baseline.rounded())) avg)")
            }
        }
        // Also check muscles that disappeared entirely
        for (group, baseline) in avg where baseline >= 4 {
            if !thisWeek.contains(where: { $0.muscleGroup == group }) {
                drops.append("\(group.displayName) (0 sets vs ~\(Int(baseline.rounded())) avg)")
            }
        }
        guard !drops.isEmpty else { return [] }
        return [Insight(
            id: "volume_drop",
            title: "Muscle volume dipped",
            body: "Compared with your 4-week average, volume dropped over 25% for: \(drops.joined(separator: "; ")). A lighter week is fine — plan a return set next session if you want."
        )]
    }

    private static func stallInsight(_ ctx: Context) -> [Insight] {
        let finished = ctx.sessions.filter(\.isFinished).sorted { ($0.finishedAt ?? $0.startedAt) > ($1.finishedAt ?? $1.startedAt) }
        guard finished.count >= 4 else { return [] }

        // Find an exercise with 3+ recent sessions and flat e1RM.
        var byExercise: [String: [(Date, Double, String)]] = [:]
        for session in finished.prefix(12) {
            var bestInSession: [String: (Double, String)] = [:]
            for set in session.sets {
                let e1rm = PRDetector.estimatedOneRM(weightKg: set.weightKg, reps: set.reps)
                if e1rm > (bestInSession[set.exerciseSeedId]?.0 ?? 0) {
                    bestInSession[set.exerciseSeedId] = (e1rm, set.exerciseName)
                }
            }
            let date = session.finishedAt ?? session.startedAt
            for (id, value) in bestInSession {
                byExercise[id, default: []].append((date, value.0, value.1))
            }
        }

        for (_, samples) in byExercise {
            let ordered = samples.sorted { $0.0 < $1.0 }
            guard ordered.count >= 3 else { continue }
            let lastThree = Array(ordered.suffix(3))
            let first = lastThree.first!.1
            let last = lastThree.last!.1
            guard first > 0 else { continue }
            let change = (last - first) / first
            if abs(change) < 0.02 {
                let name = lastThree.last!.2
                return [Insight(
                    id: "stall_\(name)",
                    title: "Strength stall on \(name)",
                    body: "Your estimated strength on \(name) has been flat across recent sessions (~\(Int(last.rounded())) kg e1RM). Try +1–2.5 kg or +1 rep next time, or a light deload week if joints feel beat up."
                )]
            }
        }
        return []
    }

    private static func deficitTrainingInsight(_ ctx: Context) -> [Insight] {
        let today = DiaryTotals.totals(for: ctx.diaryEntries, on: ctx.now, calendar: ctx.calendar)
        guard today.calories > 0 else { return [] }
        let deficit = ctx.targets.calories - today.calories
        // Large deficit relative to a lose-goal style day while training hard same day
        let trainedToday = ctx.sessions.contains {
            ($0.finishedAt.map { ctx.calendar.isDate($0, inSameDayAs: ctx.now) } ?? false)
            || ctx.calendar.isDate($0.startedAt, inSameDayAs: ctx.now)
        }
        let hardSets = ctx.sessions
            .filter { ctx.calendar.isDate($0.startedAt, inSameDayAs: ctx.now) }
            .flatMap(\.sets)
            .filter { ($0.rpe ?? 0) >= 8 || $0.reps * Int($0.weightKg) > 0 }
            .count
        guard trainedToday, hardSets >= 8, deficit >= 700, ctx.targets.calories < 2200 else { return [] }
        return [Insight(
            id: "deficit_training",
            title: "Big deficit + hard training",
            body: "Today you’re about \(Int(deficit)) kcal under target with a solid session. Prioritize protein (\(Int(ctx.targets.proteinGrams)) g) and sleep — recovery matters more than an extra cardio grind."
        )]
    }

    private static func carbBalanceInsight(_ ctx: Context) -> [Insight] {
        let weekProteinHit = DiaryTotals.proteinHitDays(
            entries: ctx.diaryEntries,
            proteinTarget: ctx.targets.proteinGrams,
            windowDays: 7,
            calendar: ctx.calendar,
            now: ctx.now
        )
        var lowCarbDays = 0
        for offset in 0..<7 {
            guard let day = ctx.calendar.date(byAdding: .day, value: -offset, to: ctx.now) else { continue }
            let totals = DiaryTotals.totals(for: ctx.diaryEntries, on: day, calendar: ctx.calendar)
            if totals.calories > 0 && totals.carbGrams < ctx.targets.carbGrams * 0.5 {
                lowCarbDays += 1
            }
        }
        guard lowCarbDays >= 3, weekProteinHit.hit >= 3 else { return [] }
        return [Insight(
            id: "carb_balance",
            title: "Carbs running low on training weeks",
            body: "Carbs were under half your target on \(lowCarbDays) days. For Indian plates, a katori of rice or 1–2 roti around workouts can help performance without changing protein habits."
        )]
    }

    private static func workoutFrequencyInsight(_ ctx: Context) -> [Insight] {
        let weekStart = ctx.calendar.dateInterval(of: .weekOfYear, for: ctx.now)?.start ?? ctx.now
        let count = ctx.sessions.filter {
            $0.isFinished && ($0.finishedAt ?? $0.startedAt) >= weekStart
        }.count
        guard count == 0 else { return [] }
        // Only nudge if they have history
        guard ctx.sessions.contains(where: \.isFinished) else { return [] }
        return [Insight(
            id: "workout_frequency",
            title: "No finished workouts this week yet",
            body: "When you’re ready, open Workouts and repeat a template — even a short Full Body session keeps weekly volume moving."
        )]
    }

    private static func fatTargetInsight(_ ctx: Context) -> [Insight] {
        var lowFatDays = 0
        for offset in 0..<7 {
            guard let day = ctx.calendar.date(byAdding: .day, value: -offset, to: ctx.now) else { continue }
            let totals = DiaryTotals.totals(for: ctx.diaryEntries, on: day, calendar: ctx.calendar)
            if totals.calories > 0 && totals.fatGrams < ctx.targets.fatGrams * 0.5 {
                lowFatDays += 1
            }
        }
        guard lowFatDays >= 4 else { return [] }
        return [Insight(
            id: "fat_intake",
            title: "Fat intake often quite low",
            body: "Fat was under half your \(Int(ctx.targets.fatGrams)) g target on \(lowFatDays)/7 logged days. A spoon of ghee/oil in sabzi or a handful of peanuts can close the gap gently."
        )]
    }

    static func highProteinSuggestions(for diet: DietPreference) -> String {
        switch diet {
        case .veg, .jain:
            return "paneer bhurji, dal + curd, roasted chana, Greek-style dahi, tofu stir-fry"
        case .eggetarian:
            return "egg bhurji, paneer, dal, curd, boiled eggs"
        case .nonVeg:
            return "egg bhurji, chicken curry (lean), fish, paneer, dal + curd"
        case .custom:
            return "dal, paneer, eggs or lean meat if you eat them, curd, roasted chana"
        }
    }
}
