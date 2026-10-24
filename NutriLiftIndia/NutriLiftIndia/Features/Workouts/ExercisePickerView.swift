import SwiftUI
import SwiftData

/// Search and muscle-group filtering shared by the picker and the exercise library.
enum ExerciseFilter {
    static func apply(_ exercises: [Exercise], query: String, muscle: MuscleGroup?) -> [Exercise] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return exercises.filter { exercise in
            if let muscle, exercise.muscleGroup != muscle { return false }
            if q.isEmpty { return true }
            return exercise.name.lowercased().contains(q)
                || exercise.muscleGroup.displayName.lowercased().contains(q)
                || exercise.equipment.displayName.lowercased().contains(q)
        }
    }

    static var muscleOptions: [EmojiOption<MuscleGroup?>] {
        [EmojiOption<MuscleGroup?>(value: nil, emoji: "✨", title: "All")]
        + MuscleGroup.allCases.map { EmojiOption<MuscleGroup?>(value: .some($0), emoji: $0.emoji, title: $0.displayName) }
    }
}

/// Choose one or more exercises to add to a workout or routine.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    var onAdd: ([Exercise]) -> Void

    @State private var query = ""
    @State private var muscle: MuscleGroup?
    @State private var selected: [String] = []   // seed ids in the order they were tapped
    @State private var showCreate = false

    private var filtered: [Exercise] {
        ExerciseFilter.apply(exercises, query: query, muscle: muscle)
    }

    var body: some View {
        NavigationStack {
            List {
                EmojiSegmented(options: ExerciseFilter.muscleOptions, selection: $muscle)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                if filtered.isEmpty {
                    FriendlyEmptyState(
                        emoji: "🔎",
                        title: "No exercise found",
                        message: "Can't find it? Create your own.",
                        actionTitle: "Create exercise",
                        action: { showCreate = true }
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(filtered, id: \.seedId) { exercise in
                            row(exercise)
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .tint(Theme.saffron)
            .searchable(text: $query, prompt: "Search exercises")
            .navigationTitle("Add exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreate = true } label: { Label("New exercise", systemImage: "plus") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(selected.isEmpty ? "Select exercises" : "Add \(selected.count) exercise\(selected.count == 1 ? "" : "s")") {
                    let chosen = selected.compactMap { id in exercises.first { $0.seedId == id } }
                    onAdd(chosen)
                    dismiss()
                }
                .buttonStyle(.gradient)
                .disabled(selected.isEmpty)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .sheet(isPresented: $showCreate) {
                ExerciseEditorView(editing: nil) { created in
                    selected.append(created.seedId)
                }
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let isSelected = selected.contains(exercise.seedId)
        return Button {
            Haptics.selection()
            if isSelected {
                selected.removeAll { $0 == exercise.seedId }
            } else {
                selected.append(exercise.seedId)
            }
        } label: {
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
                            .foregroundStyle(.primary)
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
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.saffron : Color.secondary.opacity(0.4))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
