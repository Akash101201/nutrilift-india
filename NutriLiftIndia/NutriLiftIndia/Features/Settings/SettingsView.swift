import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var settingsList: [AppSettings]
    @State private var exportURL: URL?
    @State private var showExport = false
    @State private var showDeleteConfirm = false
    @State private var showRecalcConfirm = false
    @State private var showExplainer = false
    @State private var weightInput = ""
    @State private var recalcError: String?
    @State private var showTargetPrompt = false
    @State private var weightChangeKg = 0.0

    private var profile: UserProfile? { profiles.first }
    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                if let profile {
                    aboutYouSection(profile)
                    bodySection(profile)
                    targetsSection(profile)
                }

                weightSection

                if let settings {
                    notificationsSection(settings)
                }

                Section {
                    Button("Request Health access") {
                        Task { await HealthKitService.shared.requestAuthorization() }
                    }
                } header: {
                    EmojiHeader(emoji: "❤️", title: "Health")
                }
                .listRowBackground(Theme.card)

                Section {
                    Button("Export all data (JSON)") { exportData() }
                    Button("Delete all data", role: .destructive) { showDeleteConfirm = true }
                } header: {
                    EmojiHeader(emoji: "🗂️", title: "Data")
                }
                .listRowBackground(Theme.card)

                Section {
                    NavigationLink("Disclaimer") { DisclaimerView() }
                    NavigationLink("About calculations") { AboutCalculationsView() }
                    Text("iCloud sync is not included in Phase 1 (planned for Phase 2).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    EmojiHeader(emoji: "ℹ️", title: "About")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .tint(Theme.saffron)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if settingsList.isEmpty {
                    modelContext.insert(AppSettings())
                    try? modelContext.save()
                }
            }
            .confirmationDialog("Delete all data and return to onboarding?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    try? ExportService.deleteAllUserData(context: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Recalculate your targets?",
                isPresented: $showRecalcConfirm,
                titleVisibility: .visible
            ) {
                Button("Recalculate") { recalculate() }
                Button("Keep my numbers", role: .cancel) {}
            } message: {
                Text("This replaces your calorie, macro, fiber and water targets, including any you edited by hand.")
            }
            .alert("Update your targets? 🎯", isPresented: $showTargetPrompt) {
                Button("Update targets") { recalculate() }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Your weight changed by \(abs(weightChangeKg).formatted(.number.precision(.fractionLength(1)))) kg. Want to refresh your targets to match?")
            }
            .alert("Couldn't recalculate 🤔", isPresented: Binding(
                get: { recalcError != nil },
                set: { if !$0 { recalcError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(recalcError ?? "")
            }
            .sheet(isPresented: $showExport) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .sheet(isPresented: $showExplainer) {
                if let profile, let result = try? GoalEngine.calculate(profile.goalInput) {
                    ExplainTargetsSheet(profile: profile, input: profile.goalInput, result: result)
                } else {
                    FriendlyEmptyState(
                        emoji: "🤔",
                        title: "Can't explain yet",
                        message: "Check that your height, weight and age are filled in."
                    )
                    .presentationDetents([.medium])
                }
            }
        }
    }

    // MARK: Sections

    private func aboutYouSection(_ profile: UserProfile) -> some View {
        Section {
            Stepper(
                "🎂 Age: \(profile.age)",
                value: Binding(
                    get: { profile.age },
                    set: { profile.age = $0; profile.updatedAt = Date() }
                ),
                in: GoalEngine.ageRange
            )
            Picker("Sex", selection: Binding(get: { profile.sex }, set: { profile.sex = $0 })) {
                ForEach(BiologicalSex.allCases) { Text("\($0.emoji) \($0.displayName)").tag($0) }
            }
            LabeledNumberField("Height", value: Binding(get: { profile.heightCm }, set: { profile.heightCm = $0 }), unit: "cm", emoji: "📏")
            LabeledNumberField("Weight", value: Binding(get: { profile.weightKg }, set: { profile.weightKg = $0 }), unit: "kg", emoji: "⚖️")
            Picker("Activity", selection: Binding(get: { profile.activity }, set: { profile.activity = $0 })) {
                ForEach(ActivityLevel.allCases) { Text("\($0.emoji) \($0.displayName)").tag($0) }
            }
            Picker("Goal", selection: Binding(get: { profile.goal }, set: { profile.goal = $0 })) {
                ForEach(FitnessGoal.allCases) { Text("\($0.emoji) \($0.displayName)").tag($0) }
            }
            if profile.goal.usesPace {
                Picker("Pace", selection: Binding(get: { profile.pace }, set: { profile.pace = $0 })) {
                    ForEach(Pace.allCases) { Text("\($0.emoji) \($0.displayName)").tag($0) }
                }
            }
            Picker("Diet", selection: Binding(get: { profile.dietPref }, set: { profile.dietPref = $0 })) {
                ForEach(DietPreference.allCases) { Text("\($0.emoji) \($0.displayName)").tag($0) }
            }
        } header: {
            EmojiHeader(emoji: "🙋", title: "About you")
        }
        .listRowBackground(Theme.card)
    }

    private func bodySection(_ profile: UserProfile) -> some View {
        Section {
            LabeledNumberField(
                "Body fat",
                value: Binding(
                    get: { profile.bodyFatPercent ?? 0 },
                    set: { profile.bodyFatPercent = $0 > 0 ? $0 : nil }
                ),
                unit: "%",
                emoji: "📊"
            )
            LabeledNumberField(
                "Lean mass",
                value: Binding(
                    get: { profile.leanMassKg ?? 0 },
                    set: { profile.leanMassKg = $0 > 0 ? $0 : nil }
                ),
                unit: "kg",
                emoji: "💪"
            )
        } header: {
            EmojiHeader(emoji: "🎯", title: "Fine-tune (optional)")
        } footer: {
            Text("Leave at 0 if you're not sure. Adding either one makes your targets more personal. Lean mass is used first if you enter both.")
        }
        .listRowBackground(Theme.card)
    }

    private func targetsSection(_ profile: UserProfile) -> some View {
        Section {
            LabeledNumberField("Calories", value: Binding(get: { profile.calorieTarget }, set: { profile.calorieTarget = $0 }), unit: "kcal", emoji: "🔥")
            LabeledNumberField("Protein", value: Binding(get: { profile.proteinTargetG }, set: { profile.proteinTargetG = $0 }), unit: "g", emoji: "🥚")
            LabeledNumberField("Carbs", value: Binding(get: { profile.carbTargetG }, set: { profile.carbTargetG = $0 }), unit: "g", emoji: "🍚")
            LabeledNumberField("Fat", value: Binding(get: { profile.fatTargetG }, set: { profile.fatTargetG = $0 }), unit: "g", emoji: "🥑")
            LabeledNumberField("Fiber", value: Binding(get: { profile.fiberTargetG }, set: { profile.fiberTargetG = $0 }), unit: "g", emoji: "🌾")
            LabeledNumberField("Water", value: Binding(get: { profile.waterTargetMl }, set: { profile.waterTargetMl = $0 }), unit: "ml", emoji: "💧")
            Stepper(
                "👟 Step target: \(profile.stepTarget)",
                value: Binding(get: { profile.stepTarget }, set: { profile.stepTarget = $0 }),
                in: 2000...30000,
                step: 500
            )
            Button("Recalculate from profile 🔄") { showRecalcConfirm = true }
            Button("Why these numbers? ✨") { showExplainer = true }
        } header: {
            EmojiHeader(emoji: "🎯", title: "Daily targets")
        }
        .listRowBackground(Theme.card)
    }

    private var weightSection: some View {
        Section {
            HStack {
                TextField("kg", text: $weightInput)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    if let kg = Double(weightInput.replacingOccurrences(of: ",", with: ".")),
                       GoalEngine.weightRange.contains(kg) {
                        logWeight(kg, fromHealthKit: false)
                        weightInput = ""
                    }
                }
                .buttonStyle(.borderless)
            }
            Button("Import latest from Health") {
                Task {
                    if let kg = await HealthKitService.shared.latestBodyMassKg() {
                        logWeight(kg, fromHealthKit: true)
                    }
                }
            }
        } header: {
            EmojiHeader(emoji: "⚖️", title: "Log weight")
        }
        .listRowBackground(Theme.card)
    }

    private func notificationsSection(_ settings: AppSettings) -> some View {
        Section {
            Toggle("Gentle meal reminder (local)", isOn: Binding(
                get: { settings.notificationsEnabled },
                set: { newValue in
                    settings.notificationsEnabled = newValue
                    Task {
                        if newValue {
                            await LocalNotificationService.requestAndSchedule(hour: settings.mealReminderHour)
                        } else {
                            LocalNotificationService.cancelAll()
                        }
                    }
                }
            ))
            Stepper(
                "Reminder hour: \(settings.mealReminderHour):00",
                value: Binding(
                    get: { settings.mealReminderHour },
                    set: { settings.mealReminderHour = $0 }
                ),
                in: 7...21
            )
            .disabled(!settings.notificationsEnabled)
        } header: {
            EmojiHeader(emoji: "🔔", title: "Notifications")
        }
        .listRowBackground(Theme.card)
    }

    // MARK: Actions

    /// Saves a weigh-in. Never changes targets silently: it only offers to refresh them.
    private func logWeight(_ kg: Double, fromHealthKit: Bool) {
        guard let outcome = WeightLogService.log(kg, fromHealthKit: fromHealthKit, profile: profile, context: modelContext) else { return }
        Haptics.success()
        if outcome.suggestsRetarget {
            weightChangeKg = outcome.changeKg
            showTargetPrompt = true
        }
    }

    private func recalculate() {
        guard let profile else { return }
        do {
            let result = try GoalEngine.calculate(profile.goalInput)
            profile.apply(result)
            try? modelContext.save()
            Haptics.success()
        } catch {
            recalcError = error.localizedDescription
        }
    }

    private func exportData() {
        do {
            let data = try ExportService.exportJSON(context: modelContext)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("nutrilift-export.json")
            try data.write(to: url, options: .atomic)
            exportURL = url
            showExport = true
        } catch {
            // silent — user can retry
        }
    }
}

/// Explains the plan the profile's details produce. If the saved targets were edited by hand,
/// it says so, because the explanation describes the calculated numbers.
struct ExplainTargetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    let input: GoalInput
    let result: GoalCalculationResult

    private var targetsMatch: Bool {
        abs(profile.calorieTarget - result.targets.calories) < 1
            && abs(profile.proteinTargetG - result.targets.proteinGrams) < 1
            && abs(profile.fatTargetG - result.targets.fatGrams) < 1
            && abs(profile.carbTargetG - result.targets.carbGrams) < 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !targetsMatch {
                        HStack(alignment: .top, spacing: 10) {
                            Text("✏️").accessibilityHidden(true)
                            Text("You've edited your targets, so they differ from the calculated plan below (\(Int(result.targets.calories)) kcal). Tap Recalculate in Settings to use it.")
                                .font(.rounded(.subheadline))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.saffron.opacity(0.16), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                    }
                    TargetExplainerCard(input: input, result: result)
                    Text("Estimates for everyday use, not medical advice.")
                        .font(.rounded(.footnote))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Why these numbers?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            Text("""
            NutriLift India is a personal logging tool, not medical advice, diagnosis, or treatment.

            Calorie and macro targets, photo estimates, and coaching tips are approximate. Talk to a qualified clinician before large diet changes, especially if you are pregnant, under 18, or managing a medical condition.

            Extreme or unsafe diet advice is intentionally limited in the app.
            """)
            .font(.rounded(.body))
            .padding()
        }
        .appBackground()
        .navigationTitle("Disclaimer")
    }
}

struct AboutCalculationsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                card("🔥", "Resting burn (BMR)",
                     "Mifflin-St Jeor: (10 × kg) + (6.25 × cm) − (5 × age) + sex offset (+5 male, −161 female, −78 other). If you add body fat or lean mass, we use Katch-McArdle instead: 370 + 21.6 × lean mass in kg.")
                card("🏃", "Daily burn (TDEE)",
                     "BMR × an activity factor: 1.2, 1.375, 1.5, 1.65 or 1.8. The top factors are a little lower than the classic ones because people tend to over-estimate how much they exercise.")
                card("🎯", "Your goal",
                     "Lose: eat 10%, 15% or 20% below your daily burn (gentle, steady, ambitious), never losing faster than about 1% of body weight a week. Gain: 5%, 10% or 15% above. A percentage fits your body size better than a fixed number.")
                card("🛟", "Safety",
                     "We won't set a target below 1200 kcal (female), 1500 kcal (male) or 1350 kcal (other), and never above maintenance for a weight-loss goal. Under 18, we use maintenance instead of a deficit.")
                card("🥚", "Protein",
                     "About 0.9 to 1.4 g per kg to maintain, and 1.2 to 1.8 g per kg when losing or gaining, based on your activity. For heavier bodies we use an adjusted weight, or your lean mass if you gave it. Vegetarian and Jain diets get about 10% more, eggetarian 5%, because plant protein is less digestible. Capped at 35% of calories.")
                card("🥑", "Fat and carbs",
                     "Fat is about 27% of calories, never less than 0.6 g per kg. Carbs are the rest, with at least 30% of calories kept for carbs. The macros always add up to your calorie target.")
                card("🌾", "Fiber and water",
                     "Fiber: 14 g per 1000 kcal, at least 25 g. Water: about 35 ml per kg plus extra for activity, shown in 250 ml glasses.")
                card("🍛", "Food database",
                     "Seed foods use IFCT-inspired or estimated household values with confidence tags. Treat as guides.")
                card("📸", "Photo estimates",
                     "On-device Apple Foundation Models only when available. Photos are not uploaded. Values are estimates, so always confirm or edit before saving. Photos are discarded after logging by default.")
                card("🏋️", "Strength",
                     "Estimated 1RM uses Epley: weight × (1 + reps/30).")
                Text("All numbers are estimates for everyday use, not medical advice.")
                    .font(.rounded(.footnote))
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .appBackground()
        .navigationTitle("Calculations")
    }

    private func card(_ emoji: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(emoji) \(title)")
                .font(.rounded(.headline, weight: .bold))
            Text(text)
                .font(.rounded(.subheadline))
                .foregroundStyle(.secondary)
        }
        .appCard()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
