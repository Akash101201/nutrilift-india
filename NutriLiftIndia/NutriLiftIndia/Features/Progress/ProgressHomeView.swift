import SwiftUI
import SwiftData
import Charts

struct ProgressHomeView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyWeightSample.date) private var weights: [BodyWeightSample]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \FoodDiaryEntry.date, order: .reverse) private var diary: [FoodDiaryEntry]
    @State private var range: WeightChartRange = .weeks4
    @State private var selectedExerciseId: String?

    private var profile: UserProfile? { profiles.first }
    private var finished: [WorkoutSession] { sessions.filter(\.isFinished) }

    private var filteredWeights: [BodyWeightSample] {
        weights.filter { $0.date >= range.startDate }
    }

    private var exerciseOptions: [(id: String, name: String)] {
        var map: [String: String] = [:]
        for session in finished {
            for set in session.sets {
                map[set.exerciseSeedId] = set.exerciseName
            }
        }
        return map.map { ($0.key, $0.value) }.sorted { $0.1 < $1.1 }
    }

    private var strengthPoints: [(Date, Double)] {
        guard let selectedExerciseId else { return [] }
        var points: [(Date, Double)] = []
        for session in finished.sorted(by: { ($0.finishedAt ?? $0.startedAt) < ($1.finishedAt ?? $1.startedAt) }) {
            let best = session.sets
                .filter { $0.exerciseSeedId == selectedExerciseId }
                .map { PRDetector.estimatedOneRM(weightKg: $0.weightKg, reps: $0.reps) }
                .max() ?? 0
            if best > 0 {
                points.append((session.finishedAt ?? session.startedAt, best))
            }
        }
        return points
    }

    private var weekVolume: [MuscleVolume] {
        VolumeAggregator.weeklySets(sessions: finished)
    }

    private var proteinAdherence: (hit: Int, total: Int) {
        guard let profile else { return (0, 0) }
        return DiaryTotals.proteinHitDays(
            entries: diary,
            proteinTarget: profile.proteinTargetG,
            windowDays: 7
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    weightSection
                    strengthSection
                    volumeSection
                    nutritionSection
                    InsightsSectionView()
                }
                .padding()
            }
            .navigationTitle("Progress")
            .onAppear {
                if selectedExerciseId == nil {
                    selectedExerciseId = exerciseOptions.first?.id
                }
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight").font(.headline)
            Picker("Range", selection: $range) {
                ForEach(WeightChartRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if filteredWeights.isEmpty {
                empty("Log weight in Settings or sync Health to see a chart.", cta: nil)
            } else {
                Chart(filteredWeights, id: \.id) { sample in
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("kg", sample.weightKg)
                    )
                    PointMark(
                        x: .value("Date", sample.date),
                        y: .value("kg", sample.weightKg)
                    )
                }
                .frame(height: 200)
            }
        }
    }

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Strength trend").font(.headline)
            if exerciseOptions.isEmpty {
                empty("Finish workouts with weighted sets to track e1RM.", cta: "Open Workouts")
            } else {
                Picker("Exercise", selection: Binding(
                    get: { selectedExerciseId ?? exerciseOptions.first!.id },
                    set: { selectedExerciseId = $0 }
                )) {
                    ForEach(exerciseOptions, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                }
                if strengthPoints.count < 2 {
                    Text("Need at least two sessions for a trend.")
                        .foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(Array(strengthPoints.enumerated()), id: \.offset) { _, point in
                            LineMark(
                                x: .value("Date", point.0),
                                y: .value("e1RM", point.1)
                            )
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Muscle-group volume (this week)").font(.headline)
            if weekVolume.isEmpty {
                empty("No sets this week yet.", cta: "Start a workout")
            } else {
                Chart(weekVolume) { item in
                    BarMark(
                        x: .value("Sets", item.sets),
                        y: .value("Muscle", item.muscleGroup.displayName)
                    )
                }
                .frame(height: CGFloat(max(160, weekVolume.count * 28)))
            }
        }
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutrition adherence").font(.headline)
            let p = proteinAdherence
            if p.total == 0 {
                empty("Log food to see protein hit rate.", cta: "Log food")
            } else {
                Text("Protein target hit \(p.hit)/\(p.total) days this week")
                ProgressView(value: Double(p.hit), total: Double(p.total))
            }
        }
    }

    private func empty(_ text: String, cta: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).foregroundStyle(.secondary)
            if let cta {
                Text(cta)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct InsightsSectionView: View {
    @Query private var profiles: [UserProfile]
    @Query private var diary: [FoodDiaryEntry]
    @Query private var sessions: [WorkoutSession]

    private var insights: [Insight] {
        guard let profile = profiles.first else { return [] }
        return InsightsEngine.generate(context: .init(
            dietPref: profile.dietPref,
            targets: profile.targets,
            diaryEntries: diary,
            sessions: sessions.filter(\.isFinished)
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insights").font(.headline)
            if insights.isEmpty {
                Text("Keep logging — insights appear when patterns show up.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(insights) { insight in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title).font(.subheadline.weight(.semibold))
                        Text(insight.body).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
