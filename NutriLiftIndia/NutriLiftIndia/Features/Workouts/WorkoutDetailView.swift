import SwiftUI
import SwiftData

/// A finished workout from your history: stats, what you did, the coach's message, and quick actions.
struct WorkoutDetailView: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var launcher: WorkoutLauncher
    @Query private var allSessions: [WorkoutSession]
    @Query private var exercises: [Exercise]

    @State private var showDeleteConfirm = false
    /// Deleting waits until this screen is gone, so the body never reads a deleted workout.
    @State private var deleteRequested = false

    private var recap: WorkoutRecap {
        WorkoutRecapBuilder.build(session: session, allSessions: allSessions, exercises: exercises)
    }

    var body: some View {
        if deleteRequested {
            Color.clear
                .appBackground()
                .onDisappear {
                    modelContext.delete(session)
                    try? modelContext.save()
                }
        } else {
            content
        }
    }

    private var content: some View {
        let recap = self.recap
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.rounded(.title, weight: .bold))
                    Text((session.finishedAt ?? session.startedAt).formatted(date: .complete, time: .shortened))
                        .font(.rounded(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                RecapStatTiles(recap: recap)

                CoachSummaryCard(content: .ready(
                    text: session.aiSummary ?? WorkoutSummary.fallbackText(recap),
                    onDevice: session.aiSummary != nil
                ))

                RecapExerciseList(recap: recap)
                RecapTips(recap: recap)

                if !session.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        EmojiHeader(emoji: "📝", title: "Your notes")
                        Text(session.notes)
                            .font(.rounded(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    .appCard()
                }

                Button("Repeat this workout 🔁") {
                    launcher.repeatWorkout(session, context: modelContext)
                }
                .buttonStyle(.gradient)

                Button("Delete workout", role: .destructive) { showDeleteConfirm = true }
                    .font(.rounded(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .appBackground()
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this workout?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) {
                deleteRequested = true
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will also be removed from your progress charts and records.")
        }
    }
}
