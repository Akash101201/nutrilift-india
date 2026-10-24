import Foundation

// MARK: - Recap model (plain values, easy to test)

struct LoggedSet: Equatable, Sendable {
    var weightKg: Double
    var reps: Int

    var e1RM: Double { PRDetector.estimatedOneRM(weightKg: weightKg, reps: reps) }
    var volume: Double { weightKg * Double(reps) }
}

struct ExerciseLog: Equatable, Sendable, Identifiable {
    var exerciseSeedId: String
    var name: String
    var muscle: MuscleGroup
    var equipment: EquipmentType?
    var sets: [LoggedSet]
    /// Best estimated 1RM from earlier finished sessions. Nil when this exercise is new to the user.
    var previousBestE1RM: Double?
    /// Sets from the most recent earlier session with this exercise.
    var previousSets: [LoggedSet]?

    var id: String { exerciseSeedId }

    var volume: Double { sets.reduce(0) { $0 + $1.volume } }

    /// Heaviest-looking set: highest estimated 1RM, or most reps for bodyweight work.
    var bestSet: LoggedSet? {
        sets.max { a, b in
            if a.e1RM != b.e1RM { return a.e1RM < b.e1RM }
            if a.reps != b.reps { return a.reps < b.reps }
            return a.weightKg < b.weightKg
        }
    }

    var isFirstTime: Bool { previousBestE1RM == nil }

    /// A first-ever set has nothing to beat, so it is not a record.
    var isPR: Bool {
        guard let previous = previousBestE1RM, let best = bestSet, best.e1RM > 0 else { return false }
        return best.e1RM > previous + 0.0001
    }

    var previousVolume: Double? {
        previousSets.map { $0.reduce(0) { $0 + $1.volume } }
    }
}

struct WorkoutRecap: Equatable, Sendable {
    var name: String
    var durationMinutes: Int
    var exercises: [ExerciseLog]
    /// Finished workouts this calendar week, including this one.
    var workoutsThisWeek: Int

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var totalVolume: Double { exercises.reduce(0) { $0 + $1.volume } }
    var prExercises: [ExerciseLog] { exercises.filter(\.isPR) }
}

// MARK: - Progression suggestions

/// Simple, honest progressive-overload rules: add reps first, then add weight.
enum ProgressionAdvisor {
    static func increment(for equipment: EquipmentType?) -> Double {
        switch equipment {
        case .dumbbell?, .kettlebell?: 2
        default: 2.5
        }
    }

    static func suggestion(for log: ExerciseLog) -> String? {
        guard let best = log.bestSet else { return nil }
        if best.weightKg <= 0 {
            return "Next time, try to add one or two reps to each set of \(log.name)."
        }
        let topWeightSets = log.sets.filter { abs($0.weightKg - best.weightKg) < 0.001 }
        let minReps = topWeightSets.map(\.reps).min() ?? best.reps
        let weight = WorkoutSummary.kgText(best.weightKg)

        if minReps >= 10 {
            let next = WorkoutSummary.kgText(best.weightKg + increment(for: log.equipment))
            return "Next time try \(next) kg on \(log.name), because you got \(minReps) reps on every set at \(weight) kg."
        }
        if best.reps >= 6 {
            return "Stay at \(weight) kg on \(log.name) and aim for \(minReps + 1) reps on every set before adding weight."
        }
        return "Keep \(weight) kg on \(log.name) and focus on smooth, controlled reps until you can reach 6 reps a set."
    }
}

// MARK: - Summary text

/// The after-workout story: appreciation, what was done, and how to improve next time.
/// Numbers come from the recap; an on-device model may only phrase them (see `Grounding`).
enum WorkoutSummary {
    static func facts(_ recap: WorkoutRecap) -> [String] {
        var lines: [String] = []
        lines.append(
            "Workout: \"\(recap.name)\". Duration \(recap.durationMinutes) minutes, \(recap.exercises.count) exercises, "
            + "\(recap.totalSets) sets, total volume \(whole(recap.totalVolume)) kg."
        )
        if recap.workoutsThisWeek > 0 {
            lines.append("This is workout number \(recap.workoutsThisWeek) this week.")
        }
        let prs = recap.prExercises
        if prs.isEmpty {
            lines.append("No new personal records this time, and that is completely fine.")
        } else {
            lines.append("New personal records on: \(prs.map(\.name).joined(separator: ", ")).")
        }

        for log in recap.exercises.prefix(6) {
            guard let best = log.bestSet else { continue }
            var line = "\(log.name): \(log.sets.count) sets, best set \(kgText(best.weightKg)) kg x \(best.reps) reps."
            if log.isPR {
                line += " This is a new personal record."
            } else if log.isFirstTime {
                line += " First time logged, so this sets a baseline."
            } else if let previous = log.previousVolume {
                let change = log.volume - previous
                if abs(change) < 1 {
                    line += " Total volume is about the same as last time."
                } else if change > 0 {
                    line += " Total volume is \(whole(change)) kg higher than last time."
                } else {
                    line += " Total volume is \(whole(-change)) kg lower than last time."
                }
            }
            if let tip = ProgressionAdvisor.suggestion(for: log) {
                line += " Suggestion for next time: \(tip)"
            }
            lines.append(line)
        }
        return lines
    }

    static let instructions = """
    You are a warm, encouraging strength coach inside a fitness app. \
    Write a short after-workout message to the user in second person. \
    In two short paragraphs, at most 150 words and at most three emoji: \
    first, sincerely appreciate their effort and recap what they did; \
    second, give two or three specific tips for improving next time, taken from the suggestions in the facts. \
    Use ONLY the facts provided and quote numbers exactly as given. \
    Never invent, round, convert or add any other number, and do not do any maths. \
    Do not give medical advice or recommend supplements. Keep it positive and practical.
    """

    static func prompt(_ recap: WorkoutRecap) -> String {
        let bullets = facts(recap).map { "- \($0)" }.joined(separator: "\n")
        return """
        Facts about the workout the user just finished:
        \(bullets)

        Write the message now.
        """
    }

    /// Always-available version, written from the same facts with no model involved.
    static func fallbackText(_ recap: WorkoutRecap) -> String {
        let prs = recap.prExercises
        var opening: String
        if prs.isEmpty {
            opening = "Nice work finishing \"\(recap.name)\" 💪 Showing up is the hardest part, and you did it."
        } else {
            opening = "Brilliant work! 🏆 You set a new personal record on \(prs.map(\.name).joined(separator: ", "))."
        }
        opening += " You did \(recap.totalSets) sets across \(recap.exercises.count) exercises in \(recap.durationMinutes) minutes, "
            + "moving \(whole(recap.totalVolume)) kg in total."

        let tips = recap.exercises.prefix(6).compactMap { ProgressionAdvisor.suggestion(for: $0) }.prefix(2)
        var second = ""
        if !tips.isEmpty {
            second = "To keep improving: " + tips.joined(separator: " ")
        }
        let closing = "Rest well, eat enough protein and drink water so you recover. See you at the next one!"
        return [opening, second, closing].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    // MARK: Formatting

    private static let posix = Locale(identifier: "en_US_POSIX")

    /// 60 -> "60", 62.5 -> "62.5". Fixed locale so the grounding check can parse it.
    static func kgText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never).locale(posix))
    }

    private static func whole(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
