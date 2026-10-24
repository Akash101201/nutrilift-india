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
    @State private var restTotalSeconds = 90
    @State private var restTask: Task<Void, Never>?
    @State private var notes = ""
    @State private var showSummary = false
    @State private var prFlags: Set<UUID> = []
    @State private var celebrateCount = 0

    private static let effortOptions: [EmojiOption<Double>] = [
        EmojiOption(value: 6, emoji: "😌", title: "Easy"),
        EmojiOption(value: 7, emoji: "🙂", title: "Good"),
        EmojiOption(value: 8, emoji: "😅", title: "Hard"),
        EmojiOption(value: 9, emoji: "😤", title: "Tough"),
        EmojiOption(value: 10, emoji: "🥵", title: "Max"),
    ]

    private var orderedExercises: [TemplateExercise] {
        template.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            if restSecondsRemaining > 0 {
                Section {
                    restCard
                }
                .listRowBackground(Theme.card)
            }

            ForEach(orderedExercises, id: \.id) { exercise in
                exerciseSection(exercise)
            }

            Section {
                TextField("How did it feel?", text: $notes, axis: .vertical)
            } header: {
                EmojiHeader(emoji: "📝", title: "Notes")
            }
            .listRowBackground(Theme.card)

            Section {
                Button("Finish workout 🏁") {
                    finish()
                }
                .buttonStyle(.gradient)
                .disabled(session?.sets.isEmpty != false)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .tint(Theme.saffron)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ensureSession() }
        .onDisappear { stopRest() }
        .celebrate(trigger: celebrateCount)
        .alert("Workout saved 🎉", isPresented: $showSummary) {
            Button("Done") { dismiss() }
        } message: {
            Text(summaryText)
        }
    }

    // MARK: Pieces

    private var restCard: some View {
        HStack(spacing: 16) {
            ProgressRing(
                progress: Double(restSecondsRemaining) / Double(max(restTotalSeconds, 1)),
                lineWidth: 8,
                colors: [Theme.teal, Theme.leaf]
            ) {
                Text("\(restSecondsRemaining)")
                    .font(.rounded(.title3, weight: .bold).monospacedDigit())
            }
            .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text("⏱️ Rest up")
                    .font(.rounded(.headline, weight: .bold))
                Text("Next set when you're ready")
                    .font(.rounded(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Skip") { stopRest() }
                .buttonStyle(.plain)
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.teal)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.teal.opacity(0.14), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func exerciseSection(_ exercise: TemplateExercise) -> some View {
        let key = exercise.exerciseSeedId
        let logged = (session?.sets ?? [])
            .filter { $0.exerciseSeedId == key }
            .sorted(by: { $0.setNumber < $1.setNumber })
        Section {
            HStack(spacing: 10) {
                CompactStepperField(
                    title: "Weight",
                    value: Binding(
                        get: { draftWeights[key] ?? 20 },
                        set: { draftWeights[key] = $0 }
                    ),
                    step: 2.5,
                    unit: "kg"
                )
                CompactStepperField(
                    title: "Reps",
                    value: Binding(
                        get: { Double(draftReps[key] ?? exercise.defaultReps) },
                        set: { draftReps[key] = Int($0.rounded()) }
                    ),
                    step: 1,
                    range: 1...100,
                    unit: "reps",
                    fractionDigits: 0
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text("How hard was it? (optional)")
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                EmojiSegmented(
                    options: Self.effortOptions,
                    selection: Binding(
                        get: { draftRPE[key] ?? 7 },
                        set: { draftRPE[key] = $0 }
                    )
                )
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

            Button("Log set ✅") {
                logSet(exercise)
            }
            .buttonStyle(.gradient)
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))

            ForEach(logged, id: \.id) { set in
                HStack {
                    Text("Set \(set.setNumber): \(Formatters.kg(set.weightKg)) × \(set.reps)")
                        .font(.rounded(.body, weight: .medium))
                    Spacer()
                    if prFlags.contains(set.id) {
                        Text("🏆 PR!")
                            .font(.rounded(.caption, weight: .bold))
                            .foregroundStyle(Theme.chilli)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.saffron.opacity(0.25), in: Capsule())
                    }
                }
            }
        } header: {
            EmojiHeader(emoji: exercise.muscleGroup.emoji, title: exercise.exerciseName)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: Logic

    private var summaryText: String {
        guard let session else { return "" }
        let sets = session.sets.count
        let volume = session.sets.reduce(0.0) { $0 + $1.volume }
        let prCount = prFlags.count
        let prLine = prCount > 0 ? " \(prCount) new PR\(prCount == 1 ? "" : "s")! 🏆" : ""
        return "\(sets) sets · volume \(Int(volume)) kg·reps.\(prLine) Nice work."
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
        let earlierSets = session.sets
        set.session = session
        session.sets.append(set)

        let prior = priorSessions.filter { $0.id != session.id && $0.isFinished }
        if PRDetector.isNewPR(set: set, priorSessions: prior, earlierSetsThisSession: earlierSets) {
            prFlags.insert(set.id)
            celebrateCount += 1
        } else {
            Haptics.tap()
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
        celebrateCount += 1
        // Let the confetti play before the summary appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            showSummary = true
        }
    }

    private func startRest(_ seconds: Int) {
        stopRest()
        restTotalSeconds = seconds
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
