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
                VStack(alignment: .leading, spacing: 22) {
                    weightSection
                    strengthSection
                    volumeSection
                    nutritionSection
                    InsightsSectionView()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Progress")
            .task {
                if selectedExerciseId == nil {
                    selectedExerciseId = exerciseOptions.first?.id
                }
            }
        }
    }

    // MARK: Weight

    private var weightSummary: String? {
        guard let first = filteredWeights.first, let last = filteredWeights.last, filteredWeights.count > 1 else {
            return filteredWeights.last.map { "\(Formatters.kg($0.weightKg))" }
        }
        let change = last.weightKg - first.weightKg
        let sign = change > 0 ? "+" : (change < 0 ? "−" : "")
        let amount = abs(change).formatted(.number.precision(.fractionLength(1)))
        return "\(Formatters.kg(last.weightKg)) · \(sign)\(amount) kg"
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "⚖️", title: "Weight", trailing: weightSummary)
            EmojiSegmented(
                options: WeightChartRange.allCases.map { EmojiOption(value: $0, emoji: "", title: $0.rawValue) },
                selection: $range
            )
            if filteredWeights.isEmpty {
                empty("📈", "Log your weight in Settings or sync Health to see a chart.", cta: nil)
            } else {
                Chart(filteredWeights, id: \.id) { sample in
                    AreaMark(
                        x: .value("Date", sample.date),
                        y: .value("kg", sample.weightKg)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.saffron.opacity(0.35), Theme.saffron.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("kg", sample.weightKg)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(Theme.chilli)
                    PointMark(
                        x: .value("Date", sample.date),
                        y: .value("kg", sample.weightKg)
                    )
                    .symbolSize(40)
                    .foregroundStyle(Theme.saffron)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 200)
                .appCard()
            }
        }
    }

    // MARK: Strength

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "🏋️", title: "Strength trend")
            if exerciseOptions.isEmpty {
                empty("💪", "Finish workouts with weighted sets to track your estimated 1RM.", cta: "Open Workouts")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Exercise", selection: Binding(
                        get: { selectedExerciseId ?? exerciseOptions.first!.id },
                        set: { selectedExerciseId = $0 }
                    )) {
                        ForEach(exerciseOptions, id: \.id) { Text($0.name).tag($0.id) }
                    }
                    .tint(Theme.saffron)
                    if strengthPoints.count < 2 {
                        Text("Need at least two sessions for a trend. Keep going! 🔥")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(.secondary)
                    } else {
                        Chart {
                            ForEach(Array(strengthPoints.enumerated()), id: \.offset) { _, point in
                                LineMark(
                                    x: .value("Date", point.0),
                                    y: .value("e1RM", point.1)
                                )
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                .foregroundStyle(Theme.teal)
                                PointMark(
                                    x: .value("Date", point.0),
                                    y: .value("e1RM", point.1)
                                )
                                .symbolSize(40)
                                .foregroundStyle(Theme.leaf)
                            }
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 200)
                    }
                }
                .appCard()
            }
        }
    }

    // MARK: Volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "📊", title: "Muscle-group volume (this week)")
            if weekVolume.isEmpty {
                empty("🗓️", "No sets this week yet.", cta: "Start a workout")
            } else {
                Chart(weekVolume) { item in
                    BarMark(
                        x: .value("Sets", item.sets),
                        y: .value("Muscle", "\(item.muscleGroup.emoji) \(item.muscleGroup.displayName)")
                    )
                    .cornerRadius(6)
                    .foregroundStyle(Theme.teal.gradient)
                }
                .frame(height: CGFloat(max(160, weekVolume.count * 32)))
                .appCard()
            }
        }
    }

    // MARK: Nutrition

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "🥚", title: "Protein consistency")
            let p = proteinAdherence
            if p.total == 0 {
                empty("🍛", "Log food to see how often you hit your protein.", cta: "Log food")
            } else {
                HStack(spacing: 18) {
                    ProgressRing(
                        progress: Double(p.hit) / Double(max(p.total, 1)),
                        lineWidth: 12,
                        colors: [Theme.chilli, Theme.saffron]
                    ) {
                        Text("\(p.hit)/\(p.total)")
                            .font(.rounded(.title3, weight: .bold))
                    }
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Protein target hit \(p.hit) of \(p.total) days this week")
                            .font(.rounded(.subheadline, weight: .semibold))
                        Text(p.hit >= p.total ? "Perfect week! 🎉" : "Every day you hit it counts 💪")
                            .font(.rounded(.caption))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .appCard()
            }
        }
    }

    private func empty(_ emoji: String, _ text: String, cta: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.title)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                if let cta {
                    Text(cta)
                        .font(.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Theme.saffron)
                }
            }
        }
        .appCard()
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
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "💡", title: "Insights")
            if insights.isEmpty {
                HStack(spacing: 12) {
                    Text("🌱")
                        .font(.title)
                        .accessibilityHidden(true)
                    Text("Keep logging. Insights appear when patterns show up.")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .appCard()
            } else {
                ForEach(insights) { insight in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.rounded(.subheadline, weight: .bold))
                        Text(insight.body)
                            .font(.rounded(.footnote))
                            .foregroundStyle(.secondary)
                    }
                    .appCard()
                }
            }
        }
    }
}
