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

    var body: some View {
        NavigationStack {
            List {
                Section("Templates") {
                    if templates.isEmpty {
                        Text("Templates load from seed data on first launch.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(templates, id: \.seedId) { template in
                            NavigationLink {
                                WorkoutSessionView(template: template)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(template.name)
                                    Text(template.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("This week — sets by muscle") {
                    if weekVolume.isEmpty {
                        Text("Finish a workout to see volume.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(weekVolume) { item in
                            HStack {
                                Text(item.muscleGroup.displayName)
                                Spacer()
                                Text("\(item.sets) sets")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Personal records") {
                    if prs.isEmpty {
                        Text("PRs appear after logged sets.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(prs, id: \.exerciseSeedId) { pr in
                            VStack(alignment: .leading) {
                                Text(pr.exerciseName)
                                Text("\(Formatters.kg(pr.bestWeightKg)) × \(pr.reps) · e1RM \(Formatters.kg(pr.estimatedOneRM))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("History") {
                    if finished.isEmpty {
                        ContentUnavailableView(
                            "No workouts yet",
                            systemImage: "dumbbell",
                            description: Text("Start a template to begin.")
                        )
                        .frame(minHeight: 120)
                    } else {
                        ForEach(finished.prefix(20), id: \.id) { session in
                            NavigationLink {
                                WorkoutDetailView(session: session)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(session.name)
                                    Text(session.finishedAt ?? session.startedAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
        }
    }
}

struct WorkoutDetailView: View {
    let session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Query private var templates: [WorkoutTemplate]

    var body: some View {
        List {
            Section("Sets") {
                ForEach(session.sets.sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { set in
                    Text("\(set.exerciseName): \(Formatters.kg(set.weightKg)) × \(set.reps)")
                }
            }
            if let template = templates.first(where: { $0.seedId == session.templateSeedId }) {
                Section {
                    NavigationLink("Repeat workout") {
                        WorkoutSessionView(template: template)
                    }
                }
            }
        }
        .navigationTitle(session.name)
    }
}
