import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var priorSessions: [WorkoutSession]

    let template: WorkoutTemplate

    @State private var session: WorkoutSession?
    @State private var draftWeights: [String: Double] = [:]
    @State private var draftReps: [String: Int] = [:]
    @State private var draftRPE: [String: Double] = [:]
    @State private var restSecondsRemaining = 0
    @State private var restTask: Task<Void, Never>?
    @State private var notes = ""
    @State private var showSummary = false
    @State private var prFlags: Set<UUID> = []

    private var orderedExercises: [TemplateExercise] {
        template.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            if restSecondsRemaining > 0 {
                Section {
                    HStack {
                        Label("Rest", systemImage: "timer")
                        Spacer()
                        Text("\(restSecondsRemaining)s")
                            .font(.title2.monospacedDigit())
                    }
                    Button("Skip rest") { stopRest() }
                }
            }

            ForEach(orderedExercises, id: \.id) { exercise in
                Section(exercise.exerciseName) {
                    let key = exercise.exerciseSeedId
                    HStack {
                        Text("kg")
                        TextField("kg", value: Binding(
                            get: { draftWeights[key] ?? 20 },
                            set: { draftWeights[key] = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        Text("reps")
                        TextField("reps", value: Binding(
                            get: { draftReps[key] ?? exercise.defaultReps },
                            set: { draftReps[key] = $0 }
                        ), format: .number)
                        .keyboardType(.numberPad)
                    }
                    HStack {
                        Text("RPE (optional)")
                        Slider(value: Binding(
                            get: { draftRPE[key] ?? 7 },
                            set: { draftRPE[key] = $0 }
                        ), in: 5...10, step: 0.5)
                        Text(String(format: "%.1f", draftRPE[key] ?? 7))
                            .frame(width: 36)
                    }
                    Button("Log set") {
                        logSet(exercise)
                    }
                    let logged = (session?.sets ?? []).filter { $0.exerciseSeedId == key }
                    ForEach(logged.sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { set in
                        HStack {
                            Text("Set \(set.setNumber): \(Formatters.kg(set.weightKg)) × \(set.reps)")
                            if prFlags.contains(set.id) {
                                Text("PR")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            Section("Notes") {
                TextField("Session notes", text: $notes, axis: .vertical)
            }

            Section {
                Button("Finish workout") {
                    finish()
                }
                .disabled(session?.sets.isEmpty != false)
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ensureSession() }
        .onDisappear { stopRest() }
        .alert("Workout saved", isPresented: $showSummary) {
            Button("Done") { dismiss() }
        } message: {
            Text(summaryText)
        }
    }

    private var summaryText: String {
        guard let session else { return "" }
        let sets = session.sets.count
        let volume = session.sets.reduce(0.0) { $0 + $1.volume }
        return "\(sets) sets · volume \(Int(volume)) kg·reps. Nice work."
    }

    private func ensureSession() {
        guard session == nil else { return }
        let s = WorkoutSession(name: template.name, templateSeedId: template.seedId)
        modelContext.insert(s)
        session = s
        for ex in orderedExercises {
            draftReps[ex.exerciseSeedId] = ex.defaultReps
            draftWeights[ex.exerciseSeedId] = 20
            draftRPE[ex.exerciseSeedId] = 7
        }
    }

    private func logSet(_ exercise: TemplateExercise) {
        ensureSession()
        guard let session else { return }
        let key = exercise.exerciseSeedId
        let setNumber = session.sets.filter { $0.exerciseSeedId == key }.count + 1
        let weight = draftWeights[key] ?? 20
        let reps = draftReps[key] ?? exercise.defaultReps
        let rpe = draftRPE[key]
        let set = WorkoutSet(
            exerciseSeedId: key,
            exerciseName: exercise.exerciseName,
            muscleGroup: exercise.muscleGroup,
            setNumber: setNumber,
            weightKg: weight,
            reps: reps,
            rpe: rpe
        )
        set.session = session
        session.sets.append(set)

        let prior = priorSessions.filter { $0.id != session.id && $0.isFinished }
        if PRDetector.isPR(set: set, priorSessions: prior) {
            prFlags.insert(set.id)
        }
        startRest(90)
        try? modelContext.save()
    }

    private func finish() {
        guard let session else { return }
        session.finishedAt = Date()
        session.notes = notes
        try? modelContext.save()
        stopRest()
        showSummary = true
    }

    private func startRest(_ seconds: Int) {
        stopRest()
        restSecondsRemaining = seconds
        restTask = Task { @MainActor in
            while restSecondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                restSecondsRemaining -= 1
            }
        }
    }

    private func stopRest() {
        restTask?.cancel()
        restTask = nil
        restSecondsRemaining = 0
    }
}
