import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \FoodDiaryEntry.date, order: .reverse) private var diary: [FoodDiaryEntry]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @ObservedObject private var health = HealthKitService.shared

    private var profile: UserProfile? { profiles.first }

    private var consumed: MacroSnapshot {
        DiaryTotals.totals(for: diary)
    }

    private var remaining: MacroTargets {
        guard let profile else { return .empty }
        return DiaryTotals.remaining(targets: profile.targets, consumed: consumed)
    }

    private var nextTemplate: WorkoutTemplate? { templates.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let profile {
                        macroCard(profile: profile)
                        activityCard(profile: profile)
                        workoutCTA
                        Text("Burn and net calories are estimates.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView("No profile", systemImage: "person", description: Text("Finish onboarding to see Today."))
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .task { await health.refreshToday() }
            .refreshable { await health.refreshToday() }
        }
    }

    private func macroCard(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calories remaining")
                .font(.headline)
            Text("\(Int(remaining.calories.rounded()))")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text("of \(Int(profile.calorieTarget)) · eaten \(Int(consumed.calories))")
                .foregroundStyle(.secondary)
            HStack {
                macroChip("P", remaining.proteinGrams, profile.proteinTargetG)
                macroChip("C", remaining.carbGrams, profile.carbTargetG)
                macroChip("F", remaining.fatGrams, profile.fatTargetG)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func macroChip(_ label: String, _ rem: Double, _ target: Double) -> some View {
        VStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(Int(rem.rounded()))g")
                .font(.headline)
            Text("tgt \(Int(target))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func activityCard(profile: UserProfile) -> some View {
        let steps = Int(health.todaySteps.rounded())
        let burn = health.todayActiveEnergyKcal
        let net = consumed.calories - burn
        return VStack(alignment: .leading, spacing: 8) {
            Text("Activity (estimate)")
                .font(.headline)
            Text("Steps: \(steps) / \(profile.stepTarget)")
            ProgressView(value: min(1, Double(steps) / Double(max(profile.stepTarget, 1))))
            Text("Active energy: \(Int(burn.rounded())) kcal (estimate)")
            Text("Net intake ≈ \(Int(net.rounded())) kcal (estimate)")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var workoutCTA: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next workout")
                .font(.headline)
            if let nextTemplate {
                NavigationLink {
                    WorkoutSessionView(template: nextTemplate)
                } label: {
                    Label("Start \(nextTemplate.name)", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else if let last = sessions.first(where: \.isFinished) {
                Text("Last: \(last.name)")
                    .foregroundStyle(.secondary)
            } else {
                Text("No templates yet — check Workouts after seed loads.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
