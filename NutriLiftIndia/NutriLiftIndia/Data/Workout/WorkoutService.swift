import Foundation
import SwiftData

/// All the ways a workout session changes, in one place so the screens stay simple.
///
/// A session is saved the moment it starts. Planned rows are `WorkoutSet`s with `isCompleted == false`;
/// ticking a row completes it. Finishing discards untouched rows, so finished workouts hold only real sets.
@MainActor
enum WorkoutService {
    // MARK: Lookup

    /// An unfinished workout with nothing ticked is treated as abandoned after this long.
    nonisolated static let staleAfter: TimeInterval = 24 * 60 * 60
    /// One with ticked sets is kept longer, so a workout left overnight isn't lost to the user.
    nonisolated static let staleAfterWithProgress: TimeInterval = 3 * 24 * 60 * 60

    /// Started, not finished, and not abandoned.
    nonisolated static func isInProgress(_ session: WorkoutSession, now: Date = Date()) -> Bool {
        guard !session.isFinished else { return false }
        let age = now.timeIntervalSince(session.startedAt)
        let hasProgress = session.sets.contains { $0.isCompleted }
        return age < (hasProgress ? staleAfterWithProgress : staleAfter)
    }

    /// The workout that was started but not finished or discarded, if any.
    static func activeSession(in context: ModelContext, now: Date = Date()) -> WorkoutSession? {
        let all = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        return all
            .filter { isInProgress($0, now: now) }
            .max { $0.startedAt < $1.startedAt }
    }

    /// Removes abandoned, empty workouts (the previous workout screen left one behind each time it opened).
    static func purgeAbandonedSessions(in context: ModelContext, now: Date = Date()) {
        let all = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let doomed = all.filter {
            !$0.isFinished && $0.sets.isEmpty && now.timeIntervalSince($0.startedAt) >= staleAfter
        }
        guard !doomed.isEmpty else { return }
        doomed.forEach(context.delete)
        try? context.save()
    }

    nonisolated static func defaultName(for date: Date = Date(), calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Morning Workout"
        case 12..<17: "Afternoon Workout"
        case 17..<21: "Evening Workout"
        default: "Night Workout"
        }
    }

    // MARK: Start

    @discardableResult
    static func startEmpty(context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(name: defaultName())
        context.insert(session)
        try? context.save()
        return session
    }

    /// Starts a workout from a routine, with a row per planned set prefilled from what you did last time.
    @discardableResult
    static func start(template: WorkoutTemplate, context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(name: template.name, templateSeedId: template.seedId)
        context.insert(session)

        let history = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let ordered = template.exercises.sorted { $0.sortOrder < $1.sortOrder }
        for (order, planned) in ordered.enumerated() {
            let previous = WorkoutHistory.lastSets(exerciseSeedId: planned.exerciseSeedId, in: history, excluding: session.id)
            for number in 1...max(1, planned.defaultSets) {
                let reference = previous.indices.contains(number - 1) ? previous[number - 1] : previous.last
                let set = WorkoutSet(
                    exerciseSeedId: planned.exerciseSeedId,
                    exerciseName: planned.exerciseName,
                    muscleGroup: planned.muscleGroup,
                    setNumber: number,
                    weightKg: reference?.weightKg ?? 0,
                    reps: reference?.reps ?? planned.defaultReps,
                    isCompleted: false,
                    exerciseOrder: order
                )
                session.sets.append(set)
            }
        }
        try? context.save()
        return session
    }

    /// Starts a new workout shaped like an earlier one (same exercises and number of sets).
    @discardableResult
    static func startRepeating(_ old: WorkoutSession, context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(name: old.name, templateSeedId: old.templateSeedId)
        context.insert(session)
        let completed = old.sets.filter(\.isCompleted)
        for (rank, seedId) in WorkoutHistory.orderedExerciseIDs(in: completed).enumerated() {
            for oldSet in completed.filter({ $0.exerciseSeedId == seedId }).sorted(by: { $0.setNumber < $1.setNumber }) {
                let set = WorkoutSet(
                    exerciseSeedId: oldSet.exerciseSeedId,
                    exerciseName: oldSet.exerciseName,
                    muscleGroup: oldSet.muscleGroup,
                    setNumber: oldSet.setNumber,
                    weightKg: oldSet.weightKg,
                    reps: oldSet.reps,
                    isCompleted: false,
                    exerciseOrder: rank
                )
                session.sets.append(set)
            }
        }
        try? context.save()
        return session
    }

    // MARK: Edit

    /// Adds an exercise to the end of the workout with one planned set.
    static func addExercise(
        seedId: String,
        name: String,
        muscle: MuscleGroup,
        to session: WorkoutSession,
        context: ModelContext
    ) {
        let history = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let previous = WorkoutHistory.lastSets(exerciseSeedId: seedId, in: history, excluding: session.id)
        let order = (session.sets.map(\.exerciseOrder).max() ?? -1) + 1
        let set = WorkoutSet(
            exerciseSeedId: seedId,
            exerciseName: name,
            muscleGroup: muscle,
            setNumber: 1,
            weightKg: previous.first?.weightKg ?? 0,
            reps: previous.first?.reps ?? 10,
            isCompleted: false,
            exerciseOrder: order
        )
        session.sets.append(set)
        try? context.save()
    }

    /// Adds a planned set that copies the last set of that exercise.
    static func addSet(exerciseSeedId: String, to session: WorkoutSession, context: ModelContext) {
        let existing = session.sets
            .filter { $0.exerciseSeedId == exerciseSeedId }
            .sorted { $0.setNumber < $1.setNumber }
        guard let last = existing.last else { return }
        let set = WorkoutSet(
            exerciseSeedId: exerciseSeedId,
            exerciseName: last.exerciseName,
            muscleGroup: last.muscleGroup,
            setNumber: last.setNumber + 1,
            weightKg: last.weightKg,
            reps: last.reps,
            isCompleted: false,
            exerciseOrder: last.exerciseOrder
        )
        session.sets.append(set)
        try? context.save()
    }

    static func removeSet(_ set: WorkoutSet, from session: WorkoutSession, context: ModelContext) {
        let seedId = set.exerciseSeedId
        session.sets.removeAll { $0.id == set.id }
        context.delete(set)
        renumber(exerciseSeedId: seedId, in: session)
        try? context.save()
    }

    static func removeExercise(seedId: String, from session: WorkoutSession, context: ModelContext) {
        let doomed = session.sets.filter { $0.exerciseSeedId == seedId }
        session.sets.removeAll { $0.exerciseSeedId == seedId }
        doomed.forEach(context.delete)
        try? context.save()
    }

    // MARK: Finish and discard

    /// Finishes the workout. Returns false when there is nothing completed to save.
    @discardableResult
    static func finish(session: WorkoutSession, notes: String, context: ModelContext) -> Bool {
        guard session.sets.contains(where: \.isCompleted) else { return false }
        let untouched = session.sets.filter { !$0.isCompleted }
        session.sets.removeAll { !$0.isCompleted }
        untouched.forEach(context.delete)
        for seedId in Set(session.sets.map(\.exerciseSeedId)) {
            renumber(exerciseSeedId: seedId, in: session)
        }
        session.notes = notes
        session.finishedAt = Date()
        try? context.save()
        return true
    }

    static func discard(session: WorkoutSession, context: ModelContext) {
        context.delete(session)
        try? context.save()
    }

    // MARK: Routines

    /// Turns a workout's exercises into a reusable routine.
    @discardableResult
    static func saveAsRoutine(session: WorkoutSession, name: String, context: ModelContext) -> WorkoutTemplate {
        let routine = WorkoutTemplate(name: name, notes: "", isCustom: true)
        let grouped = Dictionary(grouping: session.sets.filter(\.isCompleted), by: \.exerciseSeedId)
        let ordered = grouped.values
            .compactMap { sets -> [WorkoutSet]? in sets.isEmpty ? nil : sets.sorted { $0.setNumber < $1.setNumber } }
            .sorted { ($0.first?.exerciseOrder ?? 0) < ($1.first?.exerciseOrder ?? 0) }
        for (index, sets) in ordered.enumerated() {
            guard let first = sets.first else { continue }
            let planned = TemplateExercise(
                exerciseSeedId: first.exerciseSeedId,
                exerciseName: first.exerciseName,
                muscleGroup: first.muscleGroup,
                defaultSets: sets.count,
                defaultReps: first.reps,
                sortOrder: index
            )
            routine.exercises.append(planned)
        }
        context.insert(routine)
        try? context.save()
        return routine
    }

    /// A custom copy of a routine, so built-in routines can be customised without changing the originals.
    @discardableResult
    static func duplicate(_ template: WorkoutTemplate, context: ModelContext) -> WorkoutTemplate {
        let copy = WorkoutTemplate(
            name: template.isCustom ? "\(template.name) copy" : "My \(template.name)",
            notes: template.notes,
            isCustom: true
        )
        for planned in template.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let item = TemplateExercise(
                exerciseSeedId: planned.exerciseSeedId,
                exerciseName: planned.exerciseName,
                muscleGroup: planned.muscleGroup,
                defaultSets: planned.defaultSets,
                defaultReps: planned.defaultReps,
                sortOrder: planned.sortOrder
            )
            copy.exercises.append(item)
        }
        context.insert(copy)
        try? context.save()
        return copy
    }

    // MARK: Helpers

    /// Keeps set numbers 1, 2, 3... after a set is removed.
    private static func renumber(exerciseSeedId: String, in session: WorkoutSession) {
        let sets = session.sets
            .filter { $0.exerciseSeedId == exerciseSeedId }
            .sorted { $0.setNumber < $1.setNumber }
        for (index, set) in sets.enumerated() {
            set.setNumber = index + 1
        }
    }
}
