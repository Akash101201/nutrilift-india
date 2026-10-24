import SwiftUI
import SwiftData

/// Create a custom exercise, or edit one you created earlier.
struct ExerciseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [Exercise]

    /// Nil to create a new exercise.
    var editing: Exercise?
    /// Called with the saved exercise (useful to auto-select it in a picker).
    var onSaved: ((Exercise) -> Void)?

    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var equipment: EquipmentType = .barbell
    @State private var errorMessage: String?
    @State private var loaded = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 6) {
                        Text(muscle.emoji)
                            .font(.system(size: 56))
                            .accessibilityHidden(true)
                        TextField("Exercise name", text: $name)
                            .font(.rounded(.title2, weight: .bold))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.words)
                    }
                    .frame(maxWidth: .infinity)
                    .appCard()

                    Text("💪 Main muscle")
                        .font(.rounded(.headline, weight: .bold))
                    EmojiSegmented(
                        options: MuscleGroup.allCases.map { EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName) },
                        selection: $muscle
                    )

                    Text("🏋️ Equipment")
                        .font(.rounded(.headline, weight: .bold))
                    EmojiSegmented(
                        options: EquipmentType.allCases.map { EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName) },
                        selection: $equipment
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.chilli)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .navigationTitle(editing == nil ? "New exercise" : "Edit exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(editing == nil ? "Create exercise ✨" : "Save changes") { save() }
                    .buttonStyle(.gradient)
                    .disabled(trimmedName.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
            .onAppear {
                guard !loaded, let editing else { return }
                loaded = true
                name = editing.name
                muscle = editing.muscleGroup
                equipment = editing.equipment
            }
        }
    }

    private func save() {
        let clash = existing.contains {
            $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame && $0.seedId != editing?.seedId
        }
        guard !clash else {
            errorMessage = "You already have an exercise called “\(trimmedName)”."
            Haptics.warning()
            return
        }

        let saved: Exercise
        if let editing {
            let renamed = editing.name != trimmedName
            let remuscled = editing.muscleGroup != muscle
            editing.name = trimmedName
            editing.muscleGroup = muscle
            editing.equipment = equipment
            if renamed || remuscled {
                propagate(to: editing)
            }
            saved = editing
        } else {
            saved = Exercise(name: trimmedName, muscleGroup: muscle, equipment: equipment, isCustom: true)
            modelContext.insert(saved)
        }
        try? modelContext.save()
        Haptics.success()
        onSaved?(saved)
        dismiss()
    }

    /// Past workouts and routines store the exercise's name and muscle, so keep them in step after an edit.
    private func propagate(to exercise: Exercise) {
        let seedId = exercise.seedId
        let sets = (try? modelContext.fetch(FetchDescriptor<WorkoutSet>())) ?? []
        for set in sets where set.exerciseSeedId == seedId {
            set.exerciseName = exercise.name
            set.muscleGroup = exercise.muscleGroup
        }
        let planned = (try? modelContext.fetch(FetchDescriptor<TemplateExercise>())) ?? []
        for item in planned where item.exerciseSeedId == seedId {
            item.exerciseName = exercise.name
            item.muscleGroup = exercise.muscleGroup
        }
    }
}
