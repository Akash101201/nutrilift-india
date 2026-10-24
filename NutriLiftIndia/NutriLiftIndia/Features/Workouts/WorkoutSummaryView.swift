import SwiftUI
import SwiftData

// MARK: - Shared recap pieces (used by the summary and the history detail)

struct RecapStatTiles: View {
    let recap: WorkoutRecap

    var body: some View {
        HStack(spacing: 10) {
            tile("⏱️", "\(recap.durationMinutes) min", "Time")
            tile("🏋️", "\(Int(recap.totalVolume.rounded())) kg", "Volume")
            tile("✅", "\(recap.totalSets)", "Sets")
            tile("🏆", "\(recap.prExercises.count)", recap.prExercises.count == 1 ? "Record" : "Records")
        }
    }

    private func tile(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.title3).accessibilityHidden(true)
            Text(value)
                .font(.rounded(.subheadline, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.rounded(.caption2))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

struct RecapExerciseList: View {
    let recap: WorkoutRecap

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "📋", title: "What you did")
            ForEach(recap.exercises) { log in
                HStack(alignment: .top, spacing: 12) {
                    Text(log.muscle.emoji)
                        .font(.title2)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.name)
                            .font(.rounded(.body, weight: .semibold))
                        Text(setsText(log))
                            .font(.rounded(.footnote))
                            .foregroundStyle(.secondary)
                        if let note = changeText(log) {
                            Text(note)
                                .font(.rounded(.caption, weight: .semibold))
                                .foregroundStyle(log.isPR ? Theme.chilli : Theme.teal)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .appCard()
    }

    private func setsText(_ log: ExerciseLog) -> String {
        let parts = log.sets.map { "\(WorkoutSummary.kgText($0.weightKg)) × \($0.reps)" }
        return "\(log.sets.count) set\(log.sets.count == 1 ? "" : "s"): " + parts.joined(separator: ", ")
    }

    private func changeText(_ log: ExerciseLog) -> String? {
        if log.isPR { return "🏆 New personal record" }
        if log.isFirstTime { return "🆕 First time, a new baseline" }
        guard let previous = log.previousVolume else { return nil }
        let change = log.volume - previous
        if abs(change) < 1 { return "➡️ Same volume as last time" }
        let amount = Int(abs(change).rounded())
        return change > 0 ? "⬆️ \(amount) kg more volume than last time" : "➡️ \(amount) kg less volume than last time"
    }
}

struct RecapTips: View {
    let recap: WorkoutRecap
    var experience: ExperienceLevel = .intermediate

    private var tips: [String] {
        recap.exercises.prefix(6).compactMap {
            ProgressionAdvisor.suggestion(for: $0, experience: experience)
        }
    }

    var body: some View {
        if !tips.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                EmojiHeader(emoji: "💡", title: "Next time")
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•").foregroundStyle(Theme.saffron)
                        Text(tip).font(.rounded(.subheadline))
                    }
                }
            }
            .appCard()
        }
    }
}

/// The coach's message. Written on-device when Apple Intelligence is available, otherwise built in.
struct CoachSummaryCard: View {
    enum Content: Equatable {
        case loading
        case ready(text: String, onDevice: Bool)
    }

    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EmojiHeader(emoji: "🤖", title: "Your coach says")
            switch content {
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Writing your summary… ✍️")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            case .ready(let text, let onDevice):
                Text(text)
                    .font(.rounded(.body))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text(onDevice
                     ? "🔒 Written on your device with Apple Intelligence. Your data never leaves your phone."
                     : "💬 Written from your workout numbers.")
                    .font(.rounded(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
        .animation(.easeInOut(duration: 0.25), value: content)
    }
}

// MARK: - After-workout summary

struct WorkoutSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var launcher: WorkoutLauncher
    @Query private var profiles: [UserProfile]
    @Query private var allSessions: [WorkoutSession]
    @Query private var exercises: [Exercise]

    let session: WorkoutSession

    @State private var recap: WorkoutRecap?
    @State private var coach: CoachSummaryCard.Content = .loading
    @State private var celebrateCount = 0
    @State private var showSaveRoutine = false
    @State private var routineName = ""
    @State private var routineSaved = false

    private var experience: ExperienceLevel {
        profiles.first?.experience ?? .intermediate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let recap {
                        RecapStatTiles(recap: recap)
                        CoachSummaryCard(content: coach)
                        RecapExerciseList(recap: recap)
                        RecapTips(recap: recap, experience: experience)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Workout summary")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { actionBar }
            .celebrate(trigger: celebrateCount)
            .task { await prepare() }
            .alert("Save as routine", isPresented: $showSaveRoutine) {
                TextField("Routine name", text: $routineName)
                Button("Save") { saveRoutine() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Reuse this workout any time from your routines.")
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 6) {
            Text("🎉")
                .font(.system(size: 64))
                .accessibilityHidden(true)
            Text("Workout complete!")
                .font(.rounded(.largeTitle, weight: .bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("\(session.name) · \((session.finishedAt ?? session.startedAt).formatted(date: .abbreviated, time: .omitted))")
                .font(.rounded(.subheadline))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            if session.templateSeedId == nil && !routineSaved {
                Button("Save as routine 📋") {
                    routineName = session.name
                    showSaveRoutine = true
                }
                .buttonStyle(.soft)
            }
            Button("Done") { launcher.dismiss() }
                .buttonStyle(.gradient)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: Logic

    private func prepare() async {
        guard recap == nil else { return }
        let built = WorkoutRecapBuilder.build(session: session, allSessions: allSessions, exercises: exercises)
        recap = built
        celebrateCount += 1
        await loadCoach(for: built)
    }

    /// Runs on the main actor because it touches the SwiftData model.
    @MainActor
    private func loadCoach(for built: WorkoutRecap) async {
        if let saved = session.aiSummary, !saved.isEmpty {
            coach = .ready(text: saved, onDevice: true)
            return
        }
        guard OnDeviceWriter.isAvailable else {
            coach = .ready(text: WorkoutSummary.fallbackText(built, experience: experience), onDevice: false)
            return
        }
        do {
            let text = try await OnDeviceWriter.write(
                instructions: WorkoutSummary.instructions,
                prompt: WorkoutSummary.prompt(built, experience: experience),
                facts: WorkoutSummary.facts(built, experience: experience)
            )
            session.aiSummary = text
            try? modelContext.save()
            coach = .ready(text: text, onDevice: true)
        } catch {
            coach = .ready(text: WorkoutSummary.fallbackText(built, experience: experience), onDevice: false)
        }
    }

    private func saveRoutine() {
        let name = routineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        WorkoutService.saveAsRoutine(session: session, name: name, context: modelContext)
        routineSaved = true
        Haptics.success()
    }
}
