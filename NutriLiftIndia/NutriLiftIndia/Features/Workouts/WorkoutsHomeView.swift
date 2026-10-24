import SwiftUI
import SwiftData

struct WorkoutsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var launcher: WorkoutLauncher
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var exercises: [Exercise]

    @State private var showNewRoutine = false
    @State private var editingRoutine: RoutineTarget?
    @State private var pendingDelete: WorkoutTemplate?

    /// Wrapper so `.sheet(item:)` has a plain Identifiable value.
    private struct RoutineTarget: Identifiable {
        let routine: WorkoutTemplate
        var id: String { routine.seedId }
    }

    private var finished: [WorkoutSession] {
        sessions.filter(\.isFinished)
    }

    private var active: WorkoutSession? {
        sessions.first { WorkoutService.isInProgress($0) }
    }

    private var prs: [PersonalRecord] {
        PRDetector.bestSets(from: finished)
    }

    private var weekVolume: [MuscleVolume] {
        VolumeAggregator.weeklySets(sessions: finished)
    }

    private var myRoutines: [WorkoutTemplate] { templates.filter(\.isCustom) }
    private var starterRoutines: [WorkoutTemplate] { templates.filter { !$0.isCustom } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    startSection
                    routinesSection
                    weekSection
                    libraryLink
                    recordsSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Workouts")
            .sheet(isPresented: $showNewRoutine) { RoutineEditorView(routine: nil) }
            .sheet(item: $editingRoutine) { target in RoutineEditorView(routine: target.routine) }
            .confirmationDialog(
                "Delete this routine?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { routine in
                // `routine` is captured when the dialog appears, so it survives the binding being cleared.
                Button("Delete routine", role: .destructive) {
                    modelContext.delete(routine)
                    try? modelContext.save()
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Your past workouts are not affected.")
            }
        }
    }

    // MARK: Start

    @ViewBuilder
    private var startSection: some View {
        if let active {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("⏱️").font(.system(size: 34)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workout in progress")
                            .font(.rounded(.headline, weight: .bold))
                        Text("\(active.name) · started \(active.startedAt, style: .relative) ago")
                            .font(.rounded(.footnote))
                            .opacity(0.9)
                    }
                    Spacer(minLength: 0)
                }
                Button {
                    launcher.resumeActive(context: modelContext)
                } label: {
                    Text("Resume workout")
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundStyle(Theme.chilli)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .gradientCard(Theme.freshGradient)
        } else {
            Button {
                Haptics.tap()
                launcher.startEmpty(context: modelContext)
            } label: {
                HStack(spacing: 12) {
                    Text("🏋️").font(.system(size: 34)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start empty workout")
                            .font(.rounded(.title3, weight: .bold))
                        Text("Add exercises as you go")
                            .font(.rounded(.footnote))
                            .opacity(0.9)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "plus.circle.fill").font(.title)
                }
                .foregroundStyle(.white)
                .gradientCard(Theme.brandGradient)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Routines

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EmojiHeader(emoji: "📋", title: "Routines")
                Button {
                    showNewRoutine = true
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.rounded(.subheadline, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.saffron.opacity(0.16), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.saffron)
            }

            if myRoutines.isEmpty {
                HStack(spacing: 12) {
                    Text("✨").font(.title).accessibilityHidden(true)
                    Text("Create your own routine, or start one of the starter routines below.")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .appCard()
            } else {
                routineGrid(myRoutines)
            }

            if !starterRoutines.isEmpty {
                Text("Starter routines")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(.secondary)
                routineGrid(starterRoutines)
            }
        }
    }

    private func routineGrid(_ routines: [WorkoutTemplate]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(routines, id: \.seedId) { routine in
                routineCard(routine)
            }
        }
    }

    private func routineCard(_ routine: WorkoutTemplate) -> some View {
        let ordered = routine.exercises.sorted { $0.sortOrder < $1.sortOrder }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(routine.name)
                    .font(.rounded(.headline, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Menu {
                    if routine.isCustom {
                        Button { editingRoutine = RoutineTarget(routine: routine) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    Button {
                        let copy = WorkoutService.duplicate(routine, context: modelContext)
                        editingRoutine = RoutineTarget(routine: copy)
                    } label: {
                        Label(routine.isCustom ? "Duplicate" : "Customise a copy", systemImage: "doc.on.doc")
                    }
                    if routine.isCustom {
                        Button(role: .destructive) { pendingDelete = routine } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(routine.name)")
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(ordered.prefix(3), id: \.id) { item in
                    Text("\(item.defaultSets) × \(item.exerciseName)")
                        .font(.rounded(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if ordered.count > 3 {
                    Text("+\(ordered.count - 3) more")
                        .font(.rounded(.caption))
                        .foregroundStyle(.tertiary)
                }
                if ordered.isEmpty {
                    Text("No exercises yet")
                        .font(.rounded(.caption))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            Button("Start") {
                Haptics.tap()
                launcher.start(routine, context: modelContext)
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.saffron))
            .disabled(ordered.isEmpty)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    // MARK: This week

    private var weekSection: some View {
        let workouts = WorkoutHistory.workoutsInWeek(of: Date(), sessions: sessions)
        let sets = weekVolume.reduce(0) { $0 + $1.sets }
        let volume = weekVolume.reduce(0) { $0 + $1.volumeKg }
        return VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "📊", title: "This week")
            HStack(spacing: 10) {
                weekTile("🗓️", "\(workouts)", workouts == 1 ? "Workout" : "Workouts")
                weekTile("✅", "\(sets)", "Sets")
                weekTile("🏋️", "\(Int(volume.rounded())) kg", "Volume")
            }
            if weekVolume.isEmpty {
                Text("Finish a workout to see your volume 💪")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                let maxSets = Double(max(weekVolume.map(\.sets).max() ?? 1, 1))
                VStack(spacing: 12) {
                    ForEach(weekVolume) { item in
                        MacroBar(
                            emoji: item.muscleGroup.emoji,
                            name: item.muscleGroup.displayName,
                            value: Double(item.sets),
                            target: maxSets,
                            unit: "sets",
                            color: Theme.teal
                        )
                    }
                }
            }
        }
        .appCard()
    }

    private func weekTile(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(emoji) \(value)")
                .font(.rounded(.headline, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.rounded(.caption2))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Theme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: Library and records

    private var libraryLink: some View {
        NavigationLink {
            ExerciseLibraryView()
        } label: {
            HStack(spacing: 12) {
                Text("📚").font(.system(size: 30)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exercise library")
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("\(exercises.count) exercises · add your own and track progress")
                        .font(.rounded(.footnote))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "🏆", title: "Personal records")
            if prs.isEmpty {
                Text("PRs appear after your first finished workout.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                    .appCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(prs.enumerated()), id: \.element.exerciseSeedId) { index, pr in
                        NavigationLink {
                            ExerciseDetailView(
                                seedId: pr.exerciseSeedId,
                                name: pr.exerciseName,
                                muscle: exercises.first { $0.seedId == pr.exerciseSeedId }?.muscleGroup ?? .fullBody,
                                equipment: exercises.first { $0.seedId == pr.exerciseSeedId }?.equipment
                            )
                        } label: {
                            HStack(spacing: 12) {
                                Text("🏆").font(.title2).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pr.exerciseName)
                                        .font(.rounded(.body, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(Formatters.kg(pr.bestWeightKg)) × \(pr.bestReps) · e1RM \(Formatters.kg(pr.estimatedOneRM))")
                                        .font(.rounded(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < prs.count - 1 { Divider() }
                    }
                }
                .appCard()
            }
        }
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "🗓️", title: "History")
            if finished.isEmpty {
                FriendlyEmptyState(
                    emoji: "💪",
                    title: "No workouts yet",
                    message: "Start a workout above and it will show up here."
                )
                .appCard()
            } else {
                ForEach(finished.prefix(20), id: \.id) { session in
                    NavigationLink {
                        WorkoutDetailView(session: session)
                    } label: {
                        historyCard(session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func historyCard(_ session: WorkoutSession) -> some View {
        let completed = session.sets.filter(\.isCompleted)
        let volume = completed.reduce(0) { $0 + $1.volume }
        let minutes = max(1, Int(((session.finishedAt ?? session.startedAt).timeIntervalSince(session.startedAt) / 60).rounded()))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.name)
                    .font(.rounded(.headline, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(session.finishedAt ?? session.startedAt, style: .date)
                    .font(.rounded(.caption))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                Label("\(minutes) min", systemImage: "clock")
                Label("\(Int(volume.rounded())) kg", systemImage: "scalemass")
                Label("\(completed.count) sets", systemImage: "checkmark.circle")
            }
            .font(.rounded(.caption, weight: .medium))
            .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(exercisePreview(completed), id: \.name) { line in
                    Text("\(line.count) × \(line.name)")
                        .font(.rounded(.footnote))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .appCard()
    }

    /// Exercises in the order they were done, with how many sets of each (first three).
    private func exercisePreview(_ sets: [WorkoutSet]) -> [(name: String, count: Int)] {
        var names: [String: String] = [:]
        var counts: [String: Int] = [:]
        for set in sets {
            names[set.exerciseSeedId] = names[set.exerciseSeedId] ?? set.exerciseName
            counts[set.exerciseSeedId, default: 0] += 1
        }
        return WorkoutHistory.orderedExerciseIDs(in: sets).prefix(3).compactMap { id in
            guard let name = names[id] else { return nil }
            return (name: name, count: counts[id] ?? 0)
        }
    }
}
