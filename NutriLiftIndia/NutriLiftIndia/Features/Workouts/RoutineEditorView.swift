import SwiftUI
import SwiftData

/// Build or edit your own routine: pick exercises, then set how many sets and reps to aim for.
struct RoutineEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Nil to create a new routine.
    var routine: WorkoutTemplate?

    struct Draft: Identifiable, Equatable {
        let id = UUID()
        var seedId: String
        var name: String
        var muscle: MuscleGroup
        var sets: Int
        var reps: Int
    }

    @State private var name = ""
    @State private var notes = ""
    @State private var items: [Draft] = []
    @State private var showPicker = false
    @State private var loaded = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !items.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Routine name, e.g. Push Day", text: $name)
                        .font(.rounded(.title3, weight: .bold))
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .font(.rounded(.subheadline))
                }
                .listRowBackground(Theme.card)

                Section {
                    if items.isEmpty {
                        Text("No exercises yet. Add some below 👇")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text(item.muscle.emoji).accessibilityHidden(true)
                                Text(item.name)
                                    .font(.rounded(.headline, weight: .semibold))
                            }
                            HStack(spacing: 10) {
                                CompactStepperField(
                                    title: "Sets",
                                    value: Binding(get: { Double(item.sets) }, set: { item.sets = Int($0.rounded()) }),
                                    step: 1,
                                    range: 1...10,
                                    fractionDigits: 0
                                )
                                CompactStepperField(
                                    title: "Reps",
                                    value: Binding(get: { Double(item.reps) }, set: { item.reps = Int($0.rounded()) }),
                                    step: 1,
                                    range: 1...100,
                                    fractionDigits: 0
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { items.remove(atOffsets: $0) }
                } header: {
                    EmojiHeader(emoji: "🏋️", title: "Exercises")
                }
                .listRowBackground(Theme.card)

                Section {
                    Button { showPicker = true } label: {
                        Label("Add exercises", systemImage: "plus.circle.fill")
                            .font(.rounded(.headline, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.soft)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .tint(Theme.saffron)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(routine == nil ? "New routine" : "Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(routine == nil ? "Create routine ✨" : "Save changes") { save() }
                    .buttonStyle(.gradient)
                    .disabled(!canSave)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { chosen in
                    for exercise in chosen where !items.contains(where: { $0.seedId == exercise.seedId }) {
                        items.append(Draft(
                            seedId: exercise.seedId,
                            name: exercise.name,
                            muscle: exercise.muscleGroup,
                            sets: 3,
                            reps: 10
                        ))
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded, let routine else { return }
        loaded = true
        name = routine.name
        notes = routine.notes
        items = routine.exercises
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { Draft(seedId: $0.exerciseSeedId, name: $0.exerciseName, muscle: $0.muscleGroup, sets: $0.defaultSets, reps: $0.defaultReps) }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !items.isEmpty else { return }
        Keyboard.dismiss()

        let target: WorkoutTemplate
        if let routine {
            target = routine
            let old = routine.exercises
            routine.exercises.removeAll()
            old.forEach(modelContext.delete)
        } else {
            target = WorkoutTemplate(name: trimmed, notes: notes, isCustom: true)
            modelContext.insert(target)
        }
        target.name = trimmed
        target.notes = notes

        for (index, draft) in items.enumerated() {
            let planned = TemplateExercise(
                exerciseSeedId: draft.seedId,
                exerciseName: draft.name,
                muscleGroup: draft.muscle,
                defaultSets: draft.sets,
                defaultReps: draft.reps,
                sortOrder: index
            )
            target.exercises.append(planned)
        }
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
