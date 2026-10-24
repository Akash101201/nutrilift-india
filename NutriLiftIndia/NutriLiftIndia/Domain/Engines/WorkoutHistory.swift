import Foundation

/// Read-only lookups over finished workouts: what you did last time, personal bests, per-exercise progress.
enum WorkoutHistory {
    /// One exercise in one finished workout.
    struct ExerciseEntry: Identifiable {
        let id: UUID
        let date: Date
        let sessionName: String
        let sets: [WorkoutSet]

        var bestE1RM: Double { sets.map { PRDetector.estimatedOneRM(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0 }
        var heaviestKg: Double { sets.map(\.weightKg).max() ?? 0 }
        var volume: Double { sets.reduce(0) { $0 + $1.volume } }
        var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
    }

    /// Exercise ids in the order they were done: by `exerciseOrder`, then by when the first set was
    /// logged. The time tiebreak keeps older workouts (saved before `exerciseOrder` existed, so all 0)
    /// from interleaving their exercises.
    static func orderedExerciseIDs(in sets: [WorkoutSet]) -> [String] {
        var firstOrder: [String: Int] = [:]
        var firstTime: [String: Date] = [:]
        for set in sets {
            let id = set.exerciseSeedId
            firstOrder[id] = min(firstOrder[id] ?? Int.max, set.exerciseOrder)
            firstTime[id] = min(firstTime[id] ?? .distantFuture, set.completedAt)
        }
        return firstOrder.keys.sorted { a, b in
            let orderA = firstOrder[a] ?? 0
            let orderB = firstOrder[b] ?? 0
            if orderA != orderB { return orderA < orderB }
            let timeA = firstTime[a] ?? .distantFuture
            let timeB = firstTime[b] ?? .distantFuture
            if timeA != timeB { return timeA < timeB }
            return a < b
        }
    }

    static func sessionDate(_ session: WorkoutSession) -> Date {
        session.finishedAt ?? session.startedAt
    }

    /// Completed sets of `exerciseSeedId` in the most recent earlier finished workout, in set order.
    static func lastSets(
        exerciseSeedId: String,
        in sessions: [WorkoutSession],
        before date: Date = .distantFuture,
        excluding sessionID: UUID? = nil
    ) -> [WorkoutSet] {
        let candidates = sessions
            .filter { $0.isFinished && $0.id != sessionID && $0.startedAt < date }
            .sorted { $0.startedAt > $1.startedAt }
        for session in candidates {
            let sets = session.sets
                .filter { $0.exerciseSeedId == exerciseSeedId && $0.isCompleted }
                .sorted { $0.setNumber < $1.setNumber }
            if !sets.isEmpty { return sets }
        }
        return []
    }

    /// Best estimated 1RM for the exercise across earlier finished workouts, or nil if never done.
    static func bestE1RM(
        exerciseSeedId: String,
        in sessions: [WorkoutSession],
        before date: Date = .distantFuture,
        excluding sessionID: UUID? = nil
    ) -> Double? {
        var best: Double?
        for session in sessions where session.isFinished && session.id != sessionID && session.startedAt < date {
            for set in session.sets where set.exerciseSeedId == exerciseSeedId && set.isCompleted {
                let value = PRDetector.estimatedOneRM(weightKg: set.weightKg, reps: set.reps)
                if best == nil || value > (best ?? 0) { best = value }
            }
        }
        return best
    }

    /// Every finished workout that includes the exercise, oldest first.
    static func entries(exerciseSeedId: String, in sessions: [WorkoutSession]) -> [ExerciseEntry] {
        sessions
            .filter(\.isFinished)
            .compactMap { session -> ExerciseEntry? in
                let sets = session.sets
                    .filter { $0.exerciseSeedId == exerciseSeedId && $0.isCompleted }
                    .sorted { $0.setNumber < $1.setNumber }
                guard !sets.isEmpty else { return nil }
                return ExerciseEntry(id: session.id, date: sessionDate(session), sessionName: session.name, sets: sets)
            }
            .sorted { $0.date < $1.date }
    }

    /// Finished workouts in the same calendar week as `date`.
    static func workoutsInWeek(of date: Date, sessions: [WorkoutSession], calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return sessions.filter { $0.isFinished && interval.contains(sessionDate($0)) }.count
    }
}

/// Builds the plain-value recap used for the after-workout summary.
enum WorkoutRecapBuilder {
    static func build(
        session: WorkoutSession,
        allSessions: [WorkoutSession],
        exercises: [Exercise]
    ) -> WorkoutRecap {
        let completed = session.sets.filter(\.isCompleted)

        // Keep the order the exercises were done in.
        let orderedIDs = WorkoutHistory.orderedExerciseIDs(in: completed)

        let logs: [ExerciseLog] = orderedIDs.compactMap { seedId in
            let sets = completed
                .filter { $0.exerciseSeedId == seedId }
                .sorted { $0.setNumber < $1.setNumber }
            guard let first = sets.first else { return nil }
            let previous = WorkoutHistory.lastSets(
                exerciseSeedId: seedId,
                in: allSessions,
                before: session.startedAt,
                excluding: session.id
            )
            return ExerciseLog(
                exerciseSeedId: seedId,
                name: first.exerciseName,
                muscle: first.muscleGroup,
                equipment: exercises.first { $0.seedId == seedId }?.equipment,
                sets: sets.map { LoggedSet(weightKg: $0.weightKg, reps: $0.reps, rpe: $0.rpe) },
                previousBestE1RM: WorkoutHistory.bestE1RM(
                    exerciseSeedId: seedId,
                    in: allSessions,
                    before: session.startedAt,
                    excluding: session.id
                ),
                previousSets: previous.isEmpty
                    ? nil
                    : previous.map { LoggedSet(weightKg: $0.weightKg, reps: $0.reps, rpe: $0.rpe) }
            )
        }

        let end = session.finishedAt ?? Date()
        let minutes = max(1, Int((end.timeIntervalSince(session.startedAt) / 60).rounded()))
        return WorkoutRecap(
            name: session.name,
            durationMinutes: minutes,
            exercises: logs,
            workoutsThisWeek: WorkoutHistory.workoutsInWeek(of: end, sessions: allSessions)
        )
    }
}
