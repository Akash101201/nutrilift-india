import SwiftUI
import SwiftData

/// The live workout, laid out like the popular lifting apps: one table per exercise with
/// SET / PREVIOUS / KG / REPS / ✓ columns, add sets and exercises on the fly, and a rest timer.
struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var launcher: WorkoutLauncher
    @Query private var profiles: [UserProfile]
    @Query private var allSessions: [WorkoutSession]
    @Query private var exercises: [Exercise]

    @Bindable var session: WorkoutSession

    /// The preferred rest length, remembered between workouts.
    @AppStorage("restSeconds") private var restSeconds = 90
    /// When the running rest timer ends. The countdown itself lives in `RestTimerBar`.
    @State private var restEndsAt: Date?
    @State private var restTotal = 90
    @State private var showPicker = false
    @State private var showFinishConfirm = false
    @State private var showDiscardConfirm = false
    @State private var showNothingToSave = false
    @State private var detail: DetailTarget?
    @State private var prSetIDs: Set<UUID> = []
    @State private var celebrateCount = 0
    /// Form tip rows expanded under an exercise (beginners).
    @State private var expandedTips: Set<String> = []

    private var experience: ExperienceLevel {
        profiles.first?.experience ?? .intermediate
    }

    private var showsRPE: Bool {
        experience == .intermediate || experience == .advanced
    }

    private var showsFormTips: Bool {
        experience == .beginner
    }

    private struct DetailTarget: Identifiable {
        let seedId: String
        let name: String
        let muscle: MuscleGroup
        var id: String { seedId }
    }

    private struct ExerciseGroup: Identifiable {
        let seedId: String
        let name: String
        let muscle: MuscleGroup
        let sets: [WorkoutSet]
        var id: String { seedId }
    }

    // MARK: Derived

    private var groups: [ExerciseGroup] {
        WorkoutHistory.orderedExerciseIDs(in: session.sets).compactMap { id in
            let sets = session.sets
                .filter { $0.exerciseSeedId == id }
                .sorted { $0.setNumber < $1.setNumber }
            guard let first = sets.first else { return nil }
            return ExerciseGroup(seedId: id, name: first.exerciseName, muscle: first.muscleGroup, sets: sets)
        }
    }

    private var completedSets: [WorkoutSet] { session.sets.filter(\.isCompleted) }
    private var volume: Double { completedSets.reduce(0) { $0 + $1.volume } }

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $session.name)
                        .font(.rounded(.title3, weight: .bold))
                    statsRow
                    Stepper(value: $restSeconds, in: 30...300, step: 15) {
                        Text("⏱️ Rest timer: \(restSeconds) s")
                            .font(.rounded(.subheadline, weight: .medium))
                    }
                }
                .listRowBackground(Theme.card)

                ForEach(groups) { group in
                    exerciseSection(group)
                }

                Section {
                    Button { showPicker = true } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                            .font(.rounded(.headline, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.soft)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
                .listRowBackground(Color.clear)

                Section {
                    // Bound straight to the workout so notes survive minimising or quitting.
                    TextField("How did it feel? Notes for this workout", text: $session.notes, axis: .vertical)
                } header: {
                    EmojiHeader(emoji: "📝", title: "Notes")
                }
                .listRowBackground(Theme.card)

                Section {
                    Button("Discard workout", role: .destructive) { showDiscardConfirm = true }
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .tint(Theme.saffron)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Keyboard.dismiss()
                        launcher.dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Minimise workout")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { tapFinish() }
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundStyle(Theme.leaf)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { Keyboard.dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let endsAt = restEndsAt {
                    RestTimerBar(
                        endsAt: endsAt,
                        total: restTotal,
                        onAdjust: { adjustRest(by: $0) },
                        onFinish: {
                            Haptics.success()
                            restEndsAt = nil
                        },
                        onSkip: { stopRest() }
                    )
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { chosen in
                    let present = Set(session.sets.map(\.exerciseSeedId))
                    for exercise in chosen where !present.contains(exercise.seedId) {
                        WorkoutService.addExercise(
                            seedId: exercise.seedId,
                            name: exercise.name,
                            muscle: exercise.muscleGroup,
                            to: session,
                            context: modelContext
                        )
                    }
                }
            }
            .sheet(item: $detail) { target in
                NavigationStack {
                    ExerciseDetailView(
                        seedId: target.seedId,
                        name: target.name,
                        muscle: target.muscle,
                        equipment: exercises.first { $0.seedId == target.seedId }?.equipment
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { detail = nil }
                        }
                    }
                }
            }
            .confirmationDialog("Finish workout?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
                Button("Finish workout") { finishNow() }
                Button("Keep going", role: .cancel) {}
            } message: {
                let open = session.sets.count - completedSets.count
                Text("\(open) set\(open == 1 ? "" : "s") you haven't ticked will be left out.")
            }
            .confirmationDialog("Discard this workout?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) {
                    stopRest()
                    WorkoutService.discard(session: session, context: modelContext)
                }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Everything you logged in this workout will be deleted.")
            }
            .alert("Nothing to save yet", isPresented: $showNothingToSave) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tick at least one set to finish your workout.")
            }
            .celebrate(trigger: celebrateCount)
        }
    }

    // MARK: Header pieces

    private var statsRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 8) {
                statTile("⏱️", elapsedText(context.date), "Duration")
                statTile("🏋️", "\(Int(volume.rounded())) kg", "Volume")
                statTile("✅", "\(completedSets.count)", "Sets")
            }
        }
    }

    private func statTile(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(emoji) \(value)")
                .font(.rounded(.headline, weight: .bold).monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.rounded(.caption2))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func elapsedText(_ now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(session.startedAt)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    // MARK: Exercise table

    @ViewBuilder
    private func exerciseSection(_ group: ExerciseGroup) -> some View {
        let previous = WorkoutHistory.lastSets(exerciseSeedId: group.seedId, in: allSessions, excluding: session.id)
        let tips = formTips(for: group.seedId)
        Section {
            if showsFormTips, !tips.isEmpty, expandedTips.contains(group.seedId) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        Text("\(index + 1). \(tip)")
                            .font(.rounded(.caption))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .listRowBackground(Theme.saffron.opacity(0.08))
            }
            tableHeader
            ForEach(group.sets, id: \.id) { set in
                setRow(set, previous: previous)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            WorkoutService.removeSet(set, from: session, context: modelContext)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            Button {
                Haptics.tap()
                WorkoutService.addSet(exerciseSeedId: group.seedId, to: session, context: modelContext)
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.soft)
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 8, trailing: 12))
            .listRowBackground(Theme.card)
        } header: {
            exerciseHeader(group, tips: tips)
        }
    }

    private func formTips(for seedId: String) -> [String] {
        let steps = exercises.first { $0.seedId == seedId }?.instructions ?? []
        return Array(steps.prefix(2))
    }

    private func exerciseHeader(_ group: ExerciseGroup, tips: [String]) -> some View {
        HStack(spacing: 8) {
            Text(group.muscle.emoji).accessibilityHidden(true)
            Text(group.name)
                .font(.rounded(.headline, weight: .bold))
                .foregroundStyle(.primary)
                .textCase(nil)
            Spacer()
            if showsFormTips, !tips.isEmpty {
                Button {
                    Haptics.selection()
                    if expandedTips.contains(group.seedId) {
                        expandedTips.remove(group.seedId)
                    } else {
                        expandedTips.insert(group.seedId)
                    }
                } label: {
                    Label(
                        expandedTips.contains(group.seedId) ? "Hide tip" : "Form tip",
                        systemImage: expandedTips.contains(group.seedId) ? "lightbulb.fill" : "lightbulb"
                    )
                    .font(.rounded(.caption, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.saffron)
                .accessibilityLabel("Form tip for \(group.name)")
            }
            Menu {
                Button {
                    detail = DetailTarget(seedId: group.seedId, name: group.name, muscle: group.muscle)
                } label: {
                    Label("History and progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                Button(role: .destructive) {
                    WorkoutService.removeExercise(seedId: group.seedId, from: session, context: modelContext)
                } label: {
                    Label("Remove exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Options for \(group.name)")
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text("SET").frame(width: 28)
            Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
            Text("KG").frame(width: showsRPE ? 56 : 66)
            Text("REPS").frame(width: showsRPE ? 44 : 54)
            if showsRPE {
                Text("RPE").frame(width: 40)
            }
            Image(systemName: "checkmark").frame(width: 30)
        }
        .font(.rounded(.caption2, weight: .bold))
        .foregroundStyle(.secondary)
        .listRowBackground(Theme.card)
        .accessibilityHidden(true)
    }

    private func setRow(_ set: WorkoutSet, previous: [WorkoutSet]) -> some View {
        let reference = previous.indices.contains(set.setNumber - 1) ? previous[set.setNumber - 1] : previous.last
        return HStack(spacing: 8) {
            Text("\(set.setNumber)")
                .font(.rounded(.subheadline, weight: .bold))
                .frame(width: 28, height: 28)
                .background(
                    (set.isCompleted ? Theme.leaf : Color.secondary).opacity(0.18),
                    in: Circle()
                )

            Group {
                if let reference {
                    Button {
                        // Commit anything being typed first, so it can't overwrite this value later.
                        Keyboard.dismiss()
                        Haptics.selection()
                        set.weightKg = reference.weightKg
                        set.reps = reference.reps
                        if showsRPE { set.rpe = reference.rpe }
                    } label: {
                        Text("\(WorkoutSummary.kgText(reference.weightKg)) × \(reference.reps)")
                            .font(.rounded(.caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous: \(WorkoutSummary.kgText(reference.weightKg)) kilograms, \(reference.reps) reps. Tap to use.")
                } else {
                    Text("—")
                        .font(.rounded(.caption))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("0", value: weightBinding(set), format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.rounded(.body, weight: .semibold))
                .padding(.vertical, 6)
                .frame(width: showsRPE ? 56 : 66)
                .background(Theme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel("Weight in kilograms, set \(set.setNumber)")

            TextField("0", value: repsBinding(set), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.rounded(.body, weight: .semibold))
                .padding(.vertical, 6)
                .frame(width: showsRPE ? 44 : 54)
                .background(Theme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel("Reps, set \(set.setNumber)")

            if showsRPE {
                TextField("—", value: rpeBinding(set), format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.rounded(.caption, weight: .semibold))
                    .padding(.vertical, 6)
                    .frame(width: 40)
                    .background(Theme.plum.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel("RPE from 1 to 10, set \(set.setNumber)")
            }

            Button {
                toggle(set)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Theme.leaf : Color.secondary.opacity(0.5))
                    .frame(width: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Mark set \(set.setNumber) not done" : "Mark set \(set.setNumber) done")
        }
        .overlay(alignment: .topTrailing) {
            if prSetIDs.contains(set.id) {
                Text("🏆 PR")
                    .font(.rounded(.caption2, weight: .bold))
                    .foregroundStyle(Theme.chilli)
                    .offset(y: -8)
            }
        }
        .listRowBackground(set.isCompleted ? Theme.leaf.opacity(0.12) : Theme.card)
    }

    private func weightBinding(_ set: WorkoutSet) -> Binding<Double> {
        Binding(
            get: { set.weightKg },
            set: { newValue in
                guard newValue.isFinite else { return }
                set.weightKg = min(max(newValue, 0), 1000)
            }
        )
    }

    private func repsBinding(_ set: WorkoutSet) -> Binding<Int> {
        Binding(
            get: { set.reps },
            set: { set.reps = min(max($0, 0), 1000) }
        )
    }

    /// Optional RPE (1–10). Zero in the field means unset.
    private func rpeBinding(_ set: WorkoutSet) -> Binding<Double> {
        Binding(
            get: { set.rpe ?? 0 },
            set: { newValue in
                guard newValue.isFinite, newValue > 0 else {
                    set.rpe = nil
                    return
                }
                set.rpe = min(max(newValue, 1), 10)
            }
        )
    }

    // MARK: Rest timer

    private func startRest() {
        restTotal = restSeconds
        restEndsAt = Date().addingTimeInterval(Double(restSeconds))
    }

    private func stopRest() {
        restEndsAt = nil
    }

    /// Adds or removes seconds from the running timer.
    private func adjustRest(by seconds: Int) {
        guard let end = restEndsAt else { return }
        let newEnd = end.addingTimeInterval(Double(seconds))
        let remaining = newEnd.timeIntervalSinceNow
        if remaining <= 0 {
            restEndsAt = nil
        } else {
            restEndsAt = newEnd
            restTotal = max(restTotal, Int(remaining.rounded(.up)))
        }
    }

    // MARK: Actions

    private func toggle(_ set: WorkoutSet) {
        // Dismissing the keyboard commits a number still being typed. Wait a beat so the
        // record check below sees the committed weight and reps.
        Keyboard.dismiss()
        DispatchQueue.main.async {
            applyToggle(set)
        }
    }

    private func applyToggle(_ set: WorkoutSet) {
        guard set.modelContext != nil else { return }
        set.isCompleted.toggle()
        if set.isCompleted {
            set.completedAt = Date()
            let prior = allSessions.filter { $0.id != session.id && $0.isFinished }
            let earlier = session.sets.filter {
                $0.isCompleted && $0.exerciseSeedId == set.exerciseSeedId && $0.id != set.id
            }
            if PRDetector.isNewPR(set: set, priorSessions: prior, earlierSetsThisSession: earlier) {
                prSetIDs.insert(set.id)
                celebrateCount += 1
            } else {
                Haptics.tap()
            }
            startRest()
        } else {
            prSetIDs.remove(set.id)
            stopRest()
        }
        try? modelContext.save()
    }

    private func tapFinish() {
        Keyboard.dismiss()
        let completed = completedSets.count
        if completed == 0 {
            showNothingToSave = true
        } else if session.sets.count > completed {
            showFinishConfirm = true
        } else {
            finishNow()
        }
    }

    private func finishNow() {
        stopRest()
        if WorkoutService.finish(session: session, notes: session.notes, context: modelContext) {
            Haptics.success()
        }
    }
}

/// The rest countdown. It owns its own clock, so the workout list isn't redrawn every second.
private struct RestTimerBar: View {
    let endsAt: Date
    let total: Int
    var onAdjust: (Int) -> Void
    var onFinish: () -> Void
    var onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
            HStack(spacing: 12) {
                ProgressRing(
                    progress: min(1, Double(remaining) / Double(max(total, 1))),
                    lineWidth: 6,
                    colors: [Theme.teal, Theme.leaf]
                ) {
                    Text("\(remaining)")
                        .font(.rounded(.caption, weight: .bold).monospacedDigit())
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Rest")
                        .font(.rounded(.subheadline, weight: .bold))
                    Text("Next set when ready")
                        .font(.rounded(.caption2))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                button("−15") { onAdjust(-15) }
                button("+15") { onAdjust(15) }
                button("Skip") { onSkip() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .accessibilityElement(children: .contain)
        }
        // Fires once when the countdown reaches zero (and restarts if the end time is adjusted).
        .task(id: endsAt) {
            let wait = endsAt.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
            if !Task.isCancelled && Date() >= endsAt {
                onFinish()
            }
        }
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.teal)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.teal.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
