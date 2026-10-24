import Foundation

struct PersonalRecord: Equatable, Sendable {
    var exerciseSeedId: String
    var exerciseName: String
    var bestWeightKg: Double
    var bestReps: Int
    var estimatedOneRM: Double
    var achievedAt: Date
}

enum PRDetector {
    /// Epley estimate: weight * (1 + reps/30).
    static func estimatedOneRM(weightKg: Double, reps: Int) -> Double {
        guard reps > 0, weightKg > 0 else { return 0 }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30.0)
    }

    static func bestSets(from sessions: [WorkoutSession]) -> [PersonalRecord] {
        var best: [String: PersonalRecord] = [:]
        for session in sessions where session.isFinished {
            for set in session.sets where set.reps > 0 && set.weightKg > 0 {
                let e1rm = estimatedOneRM(weightKg: set.weightKg, reps: set.reps)
                let candidate = PersonalRecord(
                    exerciseSeedId: set.exerciseSeedId,
                    exerciseName: set.exerciseName,
                    bestWeightKg: set.weightKg,
                    bestReps: set.reps,
                    estimatedOneRM: e1rm,
                    achievedAt: set.completedAt
                )
                if let existing = best[set.exerciseSeedId] {
                    if candidate.estimatedOneRM > existing.estimatedOneRM {
                        best[set.exerciseSeedId] = candidate
                    }
                } else {
                    best[set.exerciseSeedId] = candidate
                }
            }
        }
        return best.values.sorted { $0.exerciseName < $1.exerciseName }
    }

    /// A set worth celebrating: it beats the best from earlier sessions AND every earlier set of the
    /// same exercise in this session. With no history for the exercise there is nothing to beat,
    /// so a first-ever set is not a "PR".
    static func isNewPR(set: WorkoutSet, priorSessions: [WorkoutSession], earlierSetsThisSession: [WorkoutSet]) -> Bool {
        guard let priorBest = bestSets(from: priorSessions)
            .first(where: { $0.exerciseSeedId == set.exerciseSeedId }) else { return false }
        let e1rm = estimatedOneRM(weightKg: set.weightKg, reps: set.reps)
        let earlierBest = earlierSetsThisSession
            .filter { $0.exerciseSeedId == set.exerciseSeedId && $0.id != set.id }
            .map { estimatedOneRM(weightKg: $0.weightKg, reps: $0.reps) }
            .max() ?? 0
        return e1rm > priorBest.estimatedOneRM && e1rm > earlierBest
    }

    static func isPR(set: WorkoutSet, priorSessions: [WorkoutSession]) -> Bool {
        let priorBest = bestSets(from: priorSessions)
            .first { $0.exerciseSeedId == set.exerciseSeedId }
        let e1rm = estimatedOneRM(weightKg: set.weightKg, reps: set.reps)
        guard let priorBest else { return e1rm > 0 }
        return e1rm > priorBest.estimatedOneRM
    }
}
