import SwiftUI
import SwiftData
import Charts

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var launcher: WorkoutLauncher
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyWeightSample.date, order: .reverse) private var weightSamples: [BodyWeightSample]
    @Query(sort: \FoodDiaryEntry.date, order: .reverse) private var diary: [FoodDiaryEntry]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query private var plans: [TrainingPlan]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WaterLogEntry.date, order: .reverse) private var waterLogs: [WaterLogEntry]
    @Query private var dailyReviews: [DailyReviewRecord]
    @ObservedObject private var health = HealthKitService.shared
    @AppStorage("proteinCelebratedDay") private var proteinCelebratedDay = ""
    @AppStorage("waterCelebratedDay") private var waterCelebratedDay = ""
    @State private var showSettings = false
    @State private var showLogWeight = false
    @State private var showTargetPrompt = false
    @State private var pendingRetarget = false
    @State private var weightChangeKg = 0.0
    @State private var celebrateCount = 0
    @State private var endOfDayPhase: DailyReviewPhase = .idle
    @State private var yesterdayTipsPhase: DailyReviewPhase = .idle
    @State private var reviewTaskToken = 0

    private static let glassMl = 250.0

    private var profile: UserProfile? { profiles.first }

    private var consumed: MacroSnapshot {
        DiaryTotals.totals(for: diary)
    }

    private var loggedDates: [Date] { diary.map(\.date) }

    private var waterTodayMl: Double { HabitStats.waterTotalMl(entries: waterLogs) }

    private var todaySnapshot: DaySnapshot? {
        guard let profile else { return nil }
        return DailyReview.snapshot(
            day: Date(),
            profile: profile,
            diary: diary,
            waterLogs: waterLogs,
            sessions: sessions,
            steps: health.todaySteps
        )
    }

    private var yesterdaySnapshot: DaySnapshot? {
        guard let profile,
              let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        return DailyReview.snapshot(
            day: yesterday,
            profile: profile,
            diary: diary,
            waterLogs: waterLogs,
            sessions: sessions,
            steps: 0
        )
    }

    private var todayReviewRecord: DailyReviewRecord? {
        let key = DailyReview.dayKey(Date())
        return dailyReviews.first { $0.dayKey == key }
    }

    private var yesterdayReviewRecord: DailyReviewRecord? {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        let key = DailyReview.dayKey(yesterday)
        return dailyReviews.first { $0.dayKey == key }
    }

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
                        yesterdayTipsSection
                        calorieCard(profile: profile)
                        habitsRow
                        waterCard(profile: profile)
                        weightCard(profile: profile)
                        activityCard(profile: profile)
                        workoutCard
                        endOfDaySection
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
            .task {
                await health.refreshToday()
                await refreshDailyReviews(force: false)
            }
            .refreshable {
                await health.refreshToday()
                await refreshDailyReviews(force: false)
            }
            .onChange(of: diary.count) { _, _ in
                Task { await refreshDailyReviews(force: false) }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogWeight, onDismiss: {
                // Presenting the alert in the same moment the sheet closes can get dropped, so wait for onDismiss.
                if pendingRetarget {
                    pendingRetarget = false
                    showTargetPrompt = true
                }
            }) {
                LogWeightSheet(weightKg: (weightSamples.first?.weightKg ?? profile?.weightKg ?? 65)) { kg, fromHealth in
                    saveWeight(kg, fromHealthKit: fromHealth)
                }
                .presentationDetents([.large])
            }
            .alert("Update your targets? 🎯", isPresented: $showTargetPrompt) {
                Button("Update targets") { refreshTargets() }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Your weight changed by \(abs(weightChangeKg).formatted(.number.precision(.fractionLength(1)))) kg. Want to refresh your targets to match?")
            }
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

    // MARK: Daily review (Foundation Models)

    @ViewBuilder
    private var yesterdayTipsSection: some View {
        if let yesterday = yesterdaySnapshot,
           DailyReview.shouldShowYesterdayTips(yesterdayHadFood: DailyReview.hasLoggedFood(yesterday)) {
            DailyReviewCard(
                emoji: "✨",
                title: "Improve today",
                subtitle: "Suggestions from yesterday’s food, water and workouts. On-device only.",
                phase: yesterdayTipsPhase,
                onRefresh: {
                    Task { await loadYesterdayTips(force: true) }
                }
            )
        }
    }

    @ViewBuilder
    private var endOfDaySection: some View {
        if let today = todaySnapshot, DailyReview.hasLoggedFood(today) {
            let eveningOrSaved = DailyReview.shouldShowEndOfDay(
                snapshot: today,
                hasSavedRecap: !(todayReviewRecord?.recapText ?? "").isEmpty
            )
            if eveningOrSaved || endOfDayPhase != .idle {
                DailyReviewCard(
                    emoji: "🌙",
                    title: eveningOrSaved ? "How you did today" : "Day so far",
                    subtitle: "Food, water and workouts — written on-device from your logs.",
                    phase: endOfDayPhase == .idle && eveningOrSaved ? .loading : endOfDayPhase,
                    onRefresh: {
                        Task { await loadEndOfDayRecap(force: true) }
                    }
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    EmojiHeader(emoji: "📝", title: "Day review")
                    Text("This evening we’ll sum up today’s food, water and workouts on-device. Or generate a mid-day check-in now.")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(.secondary)
                    Button("Review my day so far") {
                        Task { await loadEndOfDayRecap(force: true) }
                    }
                    .buttonStyle(.soft)
                }
                .appCard()
            }
        }
    }

    @MainActor
    private func refreshDailyReviews(force: Bool) async {
        reviewTaskToken += 1
        let token = reviewTaskToken
        await loadYesterdayTips(force: force)
        guard token == reviewTaskToken else { return }
        await loadEndOfDayRecap(force: force)
    }

    @MainActor
    private func loadYesterdayTips(force: Bool) async {
        guard let yesterday = yesterdaySnapshot,
              DailyReview.shouldShowYesterdayTips(yesterdayHadFood: DailyReview.hasLoggedFood(yesterday)) else {
            yesterdayTipsPhase = .idle
            return
        }
        if !force, let saved = yesterdayReviewRecord?.tipsText, !saved.isEmpty {
            yesterdayTipsPhase = .ready(text: saved, onDevice: yesterdayReviewRecord?.tipsOnDevice ?? false)
            return
        }
        yesterdayTipsPhase = .loading
        let result = await DailyReviewService.ensureTips(
            yesterday: yesterday,
            context: modelContext,
            force: force
        )
        yesterdayTipsPhase = .ready(text: result.text, onDevice: result.onDevice)
    }

    @MainActor
    private func loadEndOfDayRecap(force: Bool) async {
        guard let today = todaySnapshot, DailyReview.hasLoggedFood(today) else {
            endOfDayPhase = .idle
            return
        }
        let showAuto = DailyReview.shouldShowEndOfDay(
            snapshot: today,
            hasSavedRecap: !(todayReviewRecord?.recapText ?? "").isEmpty
        )
        // Only auto-generate in evening (or when forcing / already saved). Daytime waits for the button.
        guard force || showAuto else {
            if let saved = todayReviewRecord?.recapText, !saved.isEmpty {
                endOfDayPhase = .ready(text: saved, onDevice: todayReviewRecord?.recapOnDevice ?? false)
            }
            return
        }
        if !force, let saved = todayReviewRecord?.recapText, !saved.isEmpty {
            endOfDayPhase = .ready(text: saved, onDevice: todayReviewRecord?.recapOnDevice ?? false)
            return
        }
        endOfDayPhase = .loading
        let result = await DailyReviewService.ensureRecap(
            snapshot: today,
            context: modelContext,
            force: force
        )
        endOfDayPhase = .ready(text: result.text, onDevice: result.onDevice)
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
    private var workoutCard: some View {
        if let active = sessions.first(where: { WorkoutService.isInProgress($0) }) {
            Button {
                launcher.resumeActive(context: modelContext)
            } label: {
                HStack(spacing: 14) {
                    Text("⏱️")
                        .font(.system(size: 40))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workout in progress")
                            .font(.rounded(.subheadline, weight: .medium))
                            .opacity(0.85)
                        Text("Resume \(active.name)")
                            .font(.rounded(.title3, weight: .bold))
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                }
                .foregroundStyle(.white)
                .gradientCard(Theme.freshGradient)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                EmojiHeader(emoji: "🏋️", title: "Workout")

                if let next = todayNextPlanDay, let routine = templates.first(where: { $0.seedId == next.templateSeedId }) {
                    Button {
                        Haptics.tap()
                        launcher.start(routine, context: modelContext)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Next in your plan")
                                    .font(.rounded(.caption, weight: .semibold))
                                    .opacity(0.9)
                                Text(next.name)
                                    .font(.rounded(.headline, weight: .bold))
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Theme.brandGradient, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button("Start empty workout") {
                    Haptics.tap()
                    launcher.startEmpty(context: modelContext)
                }
                .buttonStyle(.gradient)

                let routines = templates.sorted { ($0.isCustom ? 0 : 1, $0.name) < ($1.isCustom ? 0 : 1, $1.name) }
                if !routines.isEmpty {
                    Text("Or start a routine")
                        .font(.rounded(.footnote, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(routines.prefix(6), id: \.seedId) { routine in
                                Button {
                                    Haptics.tap()
                                    launcher.start(routine, context: modelContext)
                                } label: {
                                    Text(routine.name)
                                        .font(.rounded(.subheadline, weight: .semibold))
                                        .foregroundStyle(Theme.saffron)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Theme.saffron.opacity(0.14), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if let last = sessions.first(where: \.isFinished) {
                    Text("Last: \(last.name) · \((last.finishedAt ?? last.startedAt).formatted(.relative(presentation: .named)))")
                        .font(.rounded(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .appCard()
        }
    }

    private var todayNextPlanDay: PlanScheduler.NextDay? {
        let plan = plans.first { $0.seedId == (profile?.activePlanSeedId ?? "") }
            ?? plans.first { $0.experience == (profile?.experience ?? .intermediate) }
        guard let plan else { return nil }
        let lastTemplate = sessions.first(where: \.isFinished)?.templateSeedId
        return PlanScheduler.nextDay(days: PlanScheduler.dayRefs(from: plan), lastFinishedTemplateSeedId: lastTemplate)
    }

    // MARK: Weight

    private var recentWeights: [BodyWeightSample] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return weightSamples.filter { $0.date >= cutoff }
    }

    private func weightCard(profile: UserProfile) -> some View {
        let latest = weightSamples.first?.weightKg ?? profile.weightKg
        let recent = recentWeights
        let change: Double? = {
            guard recent.count > 1, let newest = recent.first, let oldest = recent.last else { return nil }
            return newest.weightKg - oldest.weightKg
        }()
        return VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(
                emoji: "⚖️",
                title: "Weight",
                trailing: weightSamples.first.map { $0.date.formatted(.relative(presentation: .named)) }
            )
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.kg(latest))
                        .font(.rounded(.title, weight: .bold))
                        .contentTransition(.numericText())
                    Text(weightChangeText(change, goal: profile.goal))
                        .font(.rounded(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if recent.count > 1 {
                    Chart(recent.reversed(), id: \.id) { sample in
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
                        .symbolSize(24)
                        .foregroundStyle(Theme.saffron)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(width: 120, height: 56)
                    .accessibilityHidden(true)
                }
            }
            Button("Log weight ⚖️") {
                showLogWeight = true
            }
            .buttonStyle(.soft)
        }
        .appCard()
    }

    private func weightChangeText(_ change: Double?, goal: FitnessGoal) -> String {
        guard let change else { return "Log a few weigh-ins to see your trend 📈" }
        if abs(change) < 0.05 { return "➡️ Steady over the last 30 days" }
        let amount = abs(change).formatted(.number.precision(.fractionLength(1)))
        let direction = change < 0 ? "−" : "+"
        var text = "\(change < 0 ? "📉" : "📈") \(direction)\(amount) kg in 30 days"
        if (goal == .lose && change < 0) || (goal == .gain && change > 0) {
            text += " · heading the right way 🎉"
        }
        return text
    }

    private func saveWeight(_ kg: Double, fromHealthKit: Bool = false) {
        guard let outcome = WeightLogService.log(kg, fromHealthKit: fromHealthKit, profile: profile, context: modelContext) else { return }
        Haptics.success()
        if outcome.suggestsRetarget {
            weightChangeKg = outcome.changeKg
            pendingRetarget = true   // shown from the sheet's onDismiss
        }
    }

    private func refreshTargets() {
        guard let profile, let result = try? GoalEngine.calculate(profile.goalInput) else { return }
        profile.apply(result)
        try? modelContext.save()
        Haptics.success()
    }
}

/// Sheet for logging a weigh-in with a big number, a slider, and an optional Apple Health import.
struct LogWeightSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var weightKg: Double
    /// Called with the weight and whether it came from Apple Health.
    var onSave: (Double, Bool) -> Void

    @State private var importing = false
    @State private var importedFromHealth = false
    /// The value that came from Apple Health. If the user then edits the number, it's no longer an import.
    @State private var importedKg = 0.0
    @State private var healthMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BigNumberInput(
                        emoji: "⚖️",
                        title: "Today's weight",
                        value: $weightKg,
                        range: GoalEngine.weightRange,
                        step: 0.1,
                        unit: "kg",
                        fractionDigits: 1
                    )
                    Button(importing ? "Checking Apple Health…" : "Import latest from Apple Health ❤️") {
                        Task { await importFromHealth() }
                    }
                    .buttonStyle(.soft)
                    .disabled(importing)
                    if let healthMessage {
                        Text(healthMessage)
                            .font(.rounded(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Save weight") {
                    // Dismissing the keyboard commits a number still being typed; read it on the next run loop.
                    Keyboard.dismiss()
                    DispatchQueue.main.async {
                        guard GoalEngine.weightRange.contains(weightKg) else { return }
                        onSave(weightKg, importedFromHealth && weightKg == importedKg)
                        dismiss()
                    }
                }
                .buttonStyle(.gradient)
                .disabled(!GoalEngine.weightRange.contains(weightKg))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
    }

    @MainActor
    private func importFromHealth() async {
        importing = true
        defer { importing = false }
        if let kg = await HealthKitService.shared.latestBodyMassKg(), GoalEngine.weightRange.contains(kg) {
            weightKg = (kg * 10).rounded() / 10
            importedKg = weightKg
            importedFromHealth = true
            healthMessage = "Imported \(Formatters.kg(kg)) from Apple Health."
        } else {
            healthMessage = "No weight found in Apple Health, or access isn't allowed. You can type it instead."
        }
    }
}
