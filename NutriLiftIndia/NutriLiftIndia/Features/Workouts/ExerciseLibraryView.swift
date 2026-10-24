import SwiftUI
import SwiftData
import Charts

// MARK: - Library

/// Every exercise, built-in and custom. Tap one to see your history and progress.
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var query = ""
    @State private var muscle: MuscleGroup?
    @State private var showCreate = false
    @State private var editing: EditTarget?
    @State private var pendingDelete: Exercise?

    /// Wrapper so `.sheet(item:)` has a plain Identifiable value.
    private struct EditTarget: Identifiable {
        let exercise: Exercise
        var id: String { exercise.seedId }
    }

    private var filtered: [Exercise] {
        ExerciseFilter.apply(exercises, query: query, muscle: muscle)
    }

    var body: some View {
        List {
            EmojiSegmented(options: ExerciseFilter.muscleOptions, selection: $muscle)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            if filtered.isEmpty {
                FriendlyEmptyState(
                    emoji: "🔎",
                    title: "No exercise found",
                    message: "Try another search, or create your own.",
                    actionTitle: "Create exercise",
                    action: { showCreate = true }
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filtered, id: \.seedId) { exercise in
                        NavigationLink {
                            ExerciseDetailView(
                                seedId: exercise.seedId,
                                name: exercise.name,
                                muscle: exercise.muscleGroup,
                                equipment: exercise.equipment
                            )
                        } label: {
                            row(exercise)
                        }
                        .swipeActions(edge: .trailing) {
                            if exercise.isCustom {
                                Button(role: .destructive) {
                                    pendingDelete = exercise
                                } label: { Label("Delete", systemImage: "trash") }
                                Button {
                                    editing = EditTarget(exercise: exercise)
                                } label: { Label("Edit", systemImage: "pencil") }
                                .tint(Theme.teal)
                            }
                        }
                    }
                } footer: {
                    Text("Swipe a custom exercise to edit or delete it.")
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .tint(Theme.saffron)
        .searchable(text: $query, prompt: "Search exercises")
        .navigationTitle("Exercises")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: { Label("New exercise", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showCreate) { ExerciseEditorView(editing: nil) }
        .sheet(item: $editing) { target in ExerciseEditorView(editing: target.exercise) }
        .confirmationDialog(
            "Delete this exercise?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { exercise in
            // `exercise` is captured when the dialog appears, so it survives the binding being cleared.
            Button("Delete", role: .destructive) {
                modelContext.delete(exercise)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Your past workouts keep their history. Only the exercise is removed from the list.")
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            Text(exercise.muscleGroup.emoji)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Theme.saffron.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.rounded(.body, weight: .semibold))
                    if exercise.isCustom {
                        Text("Custom")
                            .font(.rounded(.caption2, weight: .bold))
                            .foregroundStyle(Theme.plum)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.plum.opacity(0.15), in: Capsule())
                    }
                }
                Text("\(exercise.muscleGroup.displayName) · \(exercise.equipment.displayName)")
                    .font(.rounded(.caption))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Detail and progress

/// One exercise's history: personal bests, a progress chart and every past session.
struct ExerciseDetailView: View {
    let seedId: String
    let name: String
    let muscle: MuscleGroup
    let equipment: EquipmentType?

    @Query private var sessions: [WorkoutSession]
    @Query private var library: [Exercise]
    @State private var metric: Metric = .oneRM

    enum Metric: String, CaseIterable, Identifiable {
        case oneRM = "Est. 1RM"
        case heaviest = "Heaviest"
        case volume = "Volume"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .oneRM: "📈"
            case .heaviest: "🏋️"
            case .volume: "📦"
            }
        }
    }

    private var entries: [WorkoutHistory.ExerciseEntry] {
        WorkoutHistory.entries(exerciseSeedId: seedId, in: sessions)
    }

    private var instructions: [String] {
        library.first { $0.seedId == seedId }?.instructions ?? []
    }

    private func value(_ entry: WorkoutHistory.ExerciseEntry) -> Double {
        switch metric {
        case .oneRM: entry.bestE1RM
        case .heaviest: entry.heaviestKg
        case .volume: entry.volume
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !instructions.isEmpty {
                    howToCard
                }
                if entries.isEmpty {
                    FriendlyEmptyState(
                        emoji: "📈",
                        title: "No history yet",
                        message: "Log this exercise in a workout and your progress will show up here."
                    )
                    .appCard()
                } else {
                    statTiles
                    chartCard
                    recordsCard
                    historySection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .appBackground()
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 14) {
            Text(muscle.emoji)
                .font(.system(size: 44))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.rounded(.title2, weight: .bold))
                Text([muscle.displayName, equipment?.displayName].compactMap { $0 }.joined(separator: " · "))
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            EmojiHeader(emoji: "📝", title: "How to")
            ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                Text("\(index + 1). \(step)")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .appCard()
    }

    private var statTiles: some View {
        let best1RM = entries.map(\.bestE1RM).max() ?? 0
        let heaviest = entries.map(\.heaviestKg).max() ?? 0
        let totalVolume = entries.reduce(0) { $0 + $1.volume }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            tile("🏆", Formatters.kg(best1RM), "Best est. 1RM", Theme.saffron)
            tile("🏋️", Formatters.kg(heaviest), "Heaviest weight", Theme.chilli)
            tile("🗓️", "\(entries.count)", entries.count == 1 ? "Session" : "Sessions", Theme.teal)
            tile("📦", "\(Int(totalVolume.rounded())) kg", "Total volume", Theme.leaf)
        }
    }

    private func tile(_ emoji: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title2).accessibilityHidden(true)
            Text(value)
                .font(.rounded(.headline, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.rounded(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "📈", title: "Progress")
            EmojiSegmented(
                options: Metric.allCases.map { EmojiOption(value: $0, emoji: $0.emoji, title: $0.rawValue) },
                selection: $metric
            )
            if entries.count < 2 {
                Text("Do this exercise in one more workout to see a trend 🔥")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                Chart(entries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value(metric.rawValue, value(entry))
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(Theme.chilli)
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value(metric.rawValue, value(entry))
                    )
                    .symbolSize(48)
                    .foregroundStyle(Theme.saffron)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 200)
            }
        }
        .appCard()
    }

    private var recordsCard: some View {
        let allSets = entries.flatMap(\.sets)
        let heaviestSet = allSets.max { ($0.weightKg, $0.reps) < ($1.weightKg, $1.reps) }
        let volumeSet = allSets.max { $0.volume < $1.volume }
        return VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "🏆", title: "Records")
            if let heaviestSet {
                recordRow("Heaviest set", "\(Formatters.kg(heaviestSet.weightKg)) × \(heaviestSet.reps)")
            }
            if let volumeSet {
                recordRow("Best set volume", "\(Formatters.kg(volumeSet.weightKg)) × \(volumeSet.reps)")
            }
        }
        .appCard()
    }

    private func recordRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.rounded(.subheadline))
            Spacer()
            Text(value).font(.rounded(.subheadline, weight: .bold))
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "🗓️", title: "History")
            ForEach(entries.reversed()) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.date, style: .date)
                            .font(.rounded(.subheadline, weight: .bold))
                        Spacer()
                        Text(entry.sessionName)
                            .font(.rounded(.caption))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                        Text("Set \(index + 1) · \(Formatters.kg(set.weightKg)) × \(set.reps)")
                            .font(.rounded(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                .appCard()
            }
        }
    }
}
