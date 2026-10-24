import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \FoodDiaryEntry.date, order: .reverse) private var diary: [FoodDiaryEntry]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WaterLogEntry.date, order: .reverse) private var waterLogs: [WaterLogEntry]
    @ObservedObject private var health = HealthKitService.shared
    @AppStorage("proteinCelebratedDay") private var proteinCelebratedDay = ""
    @AppStorage("waterCelebratedDay") private var waterCelebratedDay = ""
    @State private var showSettings = false
    @State private var celebrateCount = 0

    private static let glassMl = 250.0

    private var profile: UserProfile? { profiles.first }

    private var consumed: MacroSnapshot {
        DiaryTotals.totals(for: diary)
    }

    private var nextTemplate: WorkoutTemplate? { templates.first }

    private var loggedDates: [Date] { diary.map(\.date) }

    private var waterTodayMl: Double { HabitStats.waterTotalMl(entries: waterLogs) }

    /// Local calendar day, so "once a day" celebrations reset at local midnight (ISO8601 style defaults to GMT).
    private var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private var proteinHit: Bool {
        guard let profile, profile.proteinTargetG > 0 else { return false }
        return consumed.proteinGrams >= profile.proteinTargetG
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let profile {
                        calorieCard(profile: profile)
                        habitsRow
                        waterCard(profile: profile)
                        activityCard(profile: profile)
                        workoutCTA
                        Text("Burn and net calories are estimates.")
                            .font(.rounded(.caption))
                            .foregroundStyle(.secondary)
                    } else {
                        FriendlyEmptyState(
                            emoji: "🙋",
                            title: "No profile yet",
                            message: "Finish setting up to see your day."
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task { await health.refreshToday() }
            .refreshable { await health.refreshToday() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .celebrate(trigger: celebrateCount)
            .onAppear { celebrateProteinIfNeeded() }
            .onChange(of: proteinHit) { _, _ in celebrateProteinIfNeeded() }
        }
    }

    // MARK: Header

    private var header: some View {
        let greeting = Greeting.forNow()
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(greeting.emoji) \(greeting.text)")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Let's eat well today")
                    .font(.rounded(.largeTitle, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.brandGradient)
            }
            .accessibilityLabel("Profile and settings")
        }
        .padding(.top, 12)
    }

    // MARK: Calories

    private func calorieCard(profile: UserProfile) -> some View {
        let target = max(profile.calorieTarget, 1)
        let eaten = consumed.calories
        let left = target - eaten
        let over = left < 0
        return VStack(spacing: 18) {
            HStack(spacing: 20) {
                ProgressRing(
                    progress: eaten / target,
                    lineWidth: 16,
                    colors: over ? [Theme.chilli, Theme.chilli] : [Theme.saffron, Theme.chilli]
                ) {
                    VStack(spacing: 0) {
                        Text("\(Int(abs(left).rounded()))")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.6)
                        Text(over ? "kcal over" : "kcal left")
                            .font(.rounded(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, height: 140)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(over ? "Calories over target" : "Calories left")
                .accessibilityValue("\(Int(abs(left).rounded())) kilocalories")

                VStack(alignment: .leading, spacing: 10) {
                    statLine("🍽️", "Eaten", "\(Int(eaten.rounded()))")
                    statLine("🎯", "Goal", "\(Int(profile.calorieTarget.rounded()))")
                    statLine("🔥", "Burned", "\(Int(health.todayActiveEnergyKcal.rounded()))")
                }
            }

            Text(Microcopy.calorieLine(consumed: eaten, target: target))
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                MacroBar(emoji: "🥚", name: "Protein", value: consumed.proteinGrams, target: profile.proteinTargetG, color: Theme.protein)
                MacroBar(emoji: "🍚", name: "Carbs", value: consumed.carbGrams, target: profile.carbTargetG, color: Theme.carbs)
                MacroBar(emoji: "🥑", name: "Fat", value: consumed.fatGrams, target: profile.fatTargetG, color: Theme.fat)
            }
        }
        .appCard(padding: 18)
    }

    private func statLine(_ emoji: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.rounded(.headline, weight: .bold))
                Text(label).font(.rounded(.caption)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: Habits

    private var habitsRow: some View {
        let streak = HabitStats.currentStreak(loggedDates: loggedDates)
        let today = HabitStats.loggedToday(loggedDates: loggedDates)
        return HStack(spacing: 14) {
            Text("🔥")
                .font(.system(size: 44))
                .opacity(streak > 0 ? 1 : 0.35)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(streak == 1 ? "1 day streak" : "\(streak) day streak")
                    .font(.rounded(.title3, weight: .bold))
                Text(Microcopy.streakLine(streak: streak, loggedToday: today))
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .appCard()
        .accessibilityElement(children: .combine)
    }

    private func waterCard(profile: UserProfile) -> some View {
        let goalGlasses = max(1, Int((profile.waterTargetMl / Self.glassMl).rounded()))
        let glasses = Int((waterTodayMl / Self.glassMl).rounded())
        return VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "💧", title: "Water", trailing: "\(glasses) / \(goalGlasses) glasses")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(goalGlasses, 8)), spacing: 8) {
                ForEach(0..<goalGlasses, id: \.self) { index in
                    Image(systemName: index < glasses ? "drop.fill" : "drop")
                        .font(.title3)
                        .foregroundStyle(index < glasses ? Theme.water : Color.secondary.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .scaleEffect(index == glasses - 1 ? 1.15 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: glasses)
                }
            }
            .accessibilityHidden(true)

            Text(Microcopy.waterLine(glasses: glasses, goal: goalGlasses))
                .font(.rounded(.subheadline))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Add a glass 🥛") { addWater(profile: profile) }
                    .buttonStyle(GradientButtonStyle(gradient: Theme.freshGradient))
                if glasses > 0 {
                    Button("Undo") { undoWater() }
                        .buttonStyle(SoftButtonStyle(tint: Theme.water))
                        .frame(width: 90)
                }
            }
        }
        .appCard()
    }

    private func addWater(profile: UserProfile) {
        let before = waterTodayMl
        modelContext.insert(WaterLogEntry(amountMl: Self.glassMl))
        try? modelContext.save()
        Haptics.tap()
        if before < profile.waterTargetMl, before + Self.glassMl >= profile.waterTargetMl, waterCelebratedDay != todayKey {
            waterCelebratedDay = todayKey
            celebrateCount += 1
        }
    }

    private func undoWater() {
        let calendar = Calendar.current
        if let last = waterLogs.first(where: { calendar.isDateInToday($0.date) }) {
            modelContext.delete(last)
            try? modelContext.save()
            Haptics.tap()
        }
    }

    private func celebrateProteinIfNeeded() {
        guard proteinHit, proteinCelebratedDay != todayKey else { return }
        proteinCelebratedDay = todayKey
        celebrateCount += 1
    }

    // MARK: Activity

    private func activityCard(profile: UserProfile) -> some View {
        let steps = health.todaySteps.rounded()
        let burn = health.todayActiveEnergyKcal
        let net = consumed.calories - burn
        return VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "👟", title: "Activity")
            MacroBar(emoji: "🚶", name: "Steps", value: steps, target: Double(profile.stepTarget), unit: "", color: Theme.teal)
            HStack {
                Label("Active energy ≈ \(Int(burn.rounded())) kcal", systemImage: "flame.fill")
                    .labelStyle(.titleAndIcon)
                Spacer()
            }
            .font(.rounded(.subheadline))
            .foregroundStyle(.secondary)
            Text("Net intake ≈ \(Int(net.rounded())) kcal")
                .font(.rounded(.subheadline))
                .foregroundStyle(.secondary)
        }
        .appCard()
    }

    // MARK: Workout

    @ViewBuilder
    private var workoutCTA: some View {
        if let nextTemplate {
            NavigationLink {
                WorkoutSessionView(template: nextTemplate)
            } label: {
                HStack(spacing: 14) {
                    Text("🏋️")
                        .font(.system(size: 40))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next workout")
                            .font(.rounded(.subheadline, weight: .medium))
                            .opacity(0.85)
                        Text("Start \(nextTemplate.name)")
                            .font(.rounded(.title3, weight: .bold))
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                }
                .foregroundStyle(.white)
                .gradientCard(Theme.brandGradient)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                EmojiHeader(emoji: "🏋️", title: "Next workout")
                if let last = sessions.first(where: \.isFinished) {
                    Text("Last: \(last.name)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No templates yet. Check Workouts after seed loads.")
                        .foregroundStyle(.secondary)
                }
            }
            .appCard()
        }
    }
}
