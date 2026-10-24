import SwiftUI
import SwiftData

struct WorkoutsHomeView: View {
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    private var finished: [WorkoutSession] {
        sessions.filter(\.isFinished)
    }

    private var prs: [PersonalRecord] {
        PRDetector.bestSets(from: finished)
    }

    private var weekVolume: [MuscleVolume] {
        VolumeAggregator.weeklySets(sessions: finished)
    }

    private let cardGradients: [LinearGradient] = [
        Theme.brandGradient,
        Theme.freshGradient,
        LinearGradient(colors: [Theme.plum, Theme.teal], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Theme.leaf, Theme.saffron], startPoint: .topLeading, endPoint: .bottomTrailing),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    templatesSection
                    volumeSection
                    recordsSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Workouts")
        }
    }

    // MARK: Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "🏋️", title: "Start a workout")
            if templates.isEmpty {
                Text("Templates load from seed data on first launch.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                    .appCard()
            } else {
                ForEach(Array(templates.enumerated()), id: \.element.seedId) { index, template in
                    NavigationLink {
                        WorkoutSessionView(template: template)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.rounded(.title3, weight: .bold))
                                Text(template.notes)
                                    .font(.rounded(.subheadline))
                                    .opacity(0.9)
                                    .multilineTextAlignment(.leading)
                                Text("\(template.exercises.count) exercises")
                                    .font(.rounded(.caption, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.22), in: Capsule())
                                    .padding(.top, 2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 34))
                        }
                        .foregroundStyle(.white)
                        .gradientCard(cardGradients[index % cardGradients.count])
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "📊", title: "This week: sets by muscle")
            if weekVolume.isEmpty {
                Text("Finish a workout to see your volume 💪")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                    .appCard()
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
                .appCard()
            }
        }
    }

    // MARK: Records

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "🏆", title: "Personal records")
            if prs.isEmpty {
                Text("PRs appear after logged sets.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                    .appCard()
            } else {
                VStack(spacing: 14) {
                    ForEach(prs, id: \.exerciseSeedId) { pr in
                        HStack(spacing: 12) {
                            Text("🏆")
                                .font(.title2)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pr.exerciseName)
                                    .font(.rounded(.body, weight: .semibold))
                                Text("\(Formatters.kg(pr.bestWeightKg)) × \(pr.bestReps) · e1RM \(Formatters.kg(pr.estimatedOneRM))")
                                    .font(.rounded(.caption))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
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
                    message: "Start a template above to log your first one."
                )
                .appCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(finished.prefix(20).enumerated()), id: \.element.id) { index, session in
                        NavigationLink {
                            WorkoutDetailView(session: session)
                        } label: {
                            HStack(spacing: 12) {
                                Text("✅")
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.name)
                                        .font(.rounded(.body, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(session.finishedAt ?? session.startedAt, style: .date)
                                        .font(.rounded(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < min(finished.count, 20) - 1 {
                            Divider()
                        }
                    }
                }
                .appCard(padding: 16)
            }
        }
    }
}

struct WorkoutDetailView: View {
    let session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Query private var templates: [WorkoutTemplate]

    var body: some View {
        List {
            Section {
                ForEach(session.sets.sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { set in
                    HStack(spacing: 10) {
                        Text(set.muscleGroup.emoji)
                            .accessibilityHidden(true)
                        Text("\(set.exerciseName): \(Formatters.kg(set.weightKg)) × \(set.reps)")
                            .font(.rounded(.body))
                    }
                }
            } header: {
                EmojiHeader(emoji: "📋", title: "Sets")
            }
            .listRowBackground(Theme.card)
            if let template = templates.first(where: { $0.seedId == session.templateSeedId }) {
                Section {
                    NavigationLink("Repeat workout 🔁") {
                        WorkoutSessionView(template: template)
                    }
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .tint(Theme.saffron)
        .navigationTitle(session.name)
    }
}
