import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = OnboardingViewModel()
    @State private var celebrateCount = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.step != .welcome {
                    header
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        page
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .id(vm.step)
                    .transition(.asymmetric(
                        insertion: .move(edge: vm.goingForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: vm.goingForward ? .leading : .trailing).combined(with: .opacity)
                    ))
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                footer
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
            .appBackground()
            .toolbar(.hidden, for: .navigationBar)
            .celebrate(trigger: celebrateCount)
            .alert(
                "Let's double-check 🤔",
                isPresented: Binding(
                    get: { vm.errorMessage != nil },
                    set: { if !$0 { vm.errorMessage = nil } }
                ),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(vm.errorMessage ?? "") }
            )
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                move(forward: false)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            }
            .accessibilityLabel("Back")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.saffron.opacity(0.2))
                    Capsule()
                        .fill(Theme.brandGradient)
                        .frame(width: geo.size.width * vm.progress)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.progress)
                }
            }
            .frame(height: 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Setup progress")
            .accessibilityValue("\(Int(vm.progress * 100)) percent")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var footer: some View {
        switch vm.step {
        case .health:
            VStack(spacing: 10) {
                Button("Connect Apple Health ❤️") {
                    Task {
                        await HealthKitService.shared.requestAuthorization()
                        finish()
                    }
                }
                .buttonStyle(.gradient)
                Button("Not now") { finish() }
                    .buttonStyle(.soft)
            }
        default:
            Button(footerTitle) { move(forward: true) }
                .buttonStyle(.gradient)
        }
    }

    private var footerTitle: String {
        switch vm.step {
        case .welcome: "Let's go 🚀"
        case .fineTune: vm.hasBodyDetails ? "Continue" : "Skip for now ⏭️"
        case .results: "Looks good! 🎉"
        default: "Continue"
        }
    }

    private func move(forward: Bool) {
        // The number pad has no Return key, so a value still being typed isn't committed yet.
        // Dismissing the keyboard commits it; then we read the values on the next run loop.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                if forward {
                    if vm.goNext() && vm.step == .results { celebrateCount += 1 }
                } else {
                    vm.goBack()
                }
            }
            if vm.errorMessage != nil { Haptics.warning() } else { Haptics.tap() }
        }
    }

    // MARK: Pages

    @ViewBuilder
    private var page: some View {
        switch vm.step {
        case .welcome: welcomePage
        case .about: aboutPage
        case .body: bodyPage
        case .activity: activityPage
        case .goal: goalPage
        case .diet: dietPage
        case .fineTune: fineTunePage
        case .results: resultsPage
        case .health: healthPage
        }
    }

    private func pageTitle(_ emoji: String, _ title: String, _ subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emoji)
                .font(.system(size: 44))
                .accessibilityHidden(true)
            Text(title)
                .font(.rounded(.largeTitle, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.rounded(.body))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image("LogoTransparent")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
                .padding(.top, 40)
            VStack(alignment: .leading, spacing: 6) {
                Text("NutriLift India")
                    .font(.rounded(.largeTitle, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Text("Eat well. Lift strong. Have fun. 💪")
                    .font(.rounded(.title3, weight: .semibold))
                    .foregroundStyle(Theme.chilli)
            }
            VStack(alignment: .leading, spacing: 14) {
                featureRow("🔒", "Private by design", "Your food, workouts and health data stay on this phone. No account, no ads.")
                featureRow("🍛", "Made for Indian food", "Roti, dal, katori and more, with portions that make sense.")
                featureRow("🎉", "Habits that feel fun", "Streaks, rings and little celebrations along the way.")
            }
            .appCard()
            Text("Not medical advice. Your targets are estimates to guide everyday logging.")
                .font(.rounded(.footnote))
                .foregroundStyle(.secondary)
        }
    }

    private func featureRow(_ emoji: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.system(size: 30))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rounded(.headline, weight: .semibold))
                Text(detail).font(.rounded(.subheadline)).foregroundStyle(.secondary)
            }
        }
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle("👋", "Let's get to know you", "We use this to estimate how much energy your body uses.")
            sectionLabel("Sex")
            EmojiChoiceGrid(
                options: BiologicalSex.allCases.map { EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName) },
                selection: $vm.sex,
                columns: 3
            )
            sectionLabel("Age")
            BigStepper(
                value: Binding(get: { Double(vm.age) }, set: { vm.age = Int($0) }),
                range: Double(GoalEngine.ageRange.lowerBound)...Double(GoalEngine.ageRange.upperBound),
                unit: "years"
            )
            .padding(.vertical, 8)
            .appCard()
        }
    }

    private var bodyPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle("📏", "Your body", "Tap the number to type it, or slide.")
            BigNumberInput(
                emoji: "📏",
                title: "Height",
                value: $vm.heightCm,
                range: GoalEngine.heightRange,
                step: 1,
                unit: "cm"
            )
            BigNumberInput(
                emoji: "⚖️",
                title: "Weight",
                value: $vm.weightKg,
                range: GoalEngine.weightRange,
                step: 0.5,
                unit: "kg",
                fractionDigits: 1
            )
            bmiHint
        }
    }

    @ViewBuilder
    private var bmiHint: some View {
        if GoalEngine.heightRange.contains(vm.heightCm), GoalEngine.weightRange.contains(vm.weightKg) {
            let bmi = GoalEngine.bmi(weightKg: vm.weightKg, heightCm: vm.heightCm)
            let info = bmiDescription(bmi)
            HStack(spacing: 12) {
                Text(info.emoji).font(.title).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BMI \(bmi.formatted(.number.precision(.fractionLength(1)))): \(info.text)")
                        .font(.rounded(.subheadline, weight: .semibold))
                    Text("BMI is only a rough guide. It doesn't see muscle.")
                        .font(.rounded(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .appCard()
        }
    }

    private func bmiDescription(_ bmi: Double) -> (emoji: String, text: String) {
        switch bmi {
        case ..<18.5: return ("🌱", "A little under the typical range")
        case ..<23: return ("🌿", "In the typical range for Indian adults")
        case ..<27.5: return ("🌤️", "A little above the typical range")
        default: return ("🌳", "Above the typical range")
        }
    }

    private var activityPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle("🏃", "How active are you?", "Not sure? Pick the lower one. It's usually closer to the truth.")
            EmojiChoiceGrid(
                options: ActivityLevel.allCases.map {
                    EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName, subtitle: $0.detail)
                },
                selection: $vm.activity,
                columns: 1
            )
        }
    }

    private var goalPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle("🎯", "What's your goal?")
            EmojiChoiceGrid(
                options: FitnessGoal.allCases.map {
                    EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName, subtitle: $0.tagline)
                },
                selection: $vm.goal,
                columns: 1
            )
            if vm.goal.usesPace {
                sectionLabel("How fast?")
                EmojiChoiceGrid(
                    options: Pace.allCases.map {
                        EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName, subtitle: $0.blurb(for: vm.goal))
                    },
                    selection: $vm.pace,
                    columns: 3
                )
                if let summary = vm.paceSummary {
                    Text(summary)
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.goal)
    }

    private var dietPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle("🍽️", "What do you eat?", "Plant protein needs a little extra, so this helps us tune your protein.")
            EmojiChoiceGrid(
                options: DietPreference.allCases.map {
                    EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName, subtitle: $0.blurb)
                },
                selection: $vm.dietPref,
                columns: 2
            )
        }
    }

    private var fineTunePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle("🎯", "Fine-tune your plan", "Totally optional. Skip it if you're not sure. You can add it later in Settings.")

            sectionLabel("Roughly how much body fat do you carry?")
            Text("A guess is fine. It helps us use a more personal formula.")
                .font(.rounded(.footnote))
                .foregroundStyle(.secondary)
            EmojiChoiceGrid(
                options: vm.bodyFatChoices.map {
                    EmojiOption(value: $0.value, emoji: $0.emoji, title: $0.title, subtitle: $0.subtitle)
                },
                selection: $vm.bodyFatInput,
                columns: 2
            )

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledNumberField("Body fat", value: $vm.bodyFatInput, unit: "%", emoji: "📊")
                    LabeledNumberField("Lean mass", value: $vm.leanMassInput, unit: "kg", emoji: "💪")
                    Text("From a smart scale or a DEXA scan. Leave at 0 to skip. If you enter lean mass, we'll use it first.")
                        .font(.rounded(.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            } label: {
                Text("🔬 I know my exact numbers")
                    .font(.rounded(.headline, weight: .semibold))
            }
            .tint(Theme.saffron)
            .appCard()
        }
    }

    @ViewBuilder
    private var resultsPage: some View {
        if let r = vm.result {
            pageTitle("🎉", "Your plan is ready!", "Built from your body, your activity and your goal.")

            VStack(spacing: 18) {
                ProgressRing(progress: 1, lineWidth: 18) {
                    VStack(spacing: 0) {
                        Text("\(Int(vm.overrideCalories))")
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("kcal a day")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 190, height: 190)
                .padding(.top, 6)
                MacroSplitBar(proteinG: vm.overrideProtein, carbG: vm.overrideCarbs, fatG: vm.overrideFat)
            }
            .frame(maxWidth: .infinity)
            .appCard()

            HStack(spacing: 10) {
                statTile("🥚", "\(Int(vm.overrideProtein)) g", "Protein", Theme.protein)
                statTile("🍚", "\(Int(vm.overrideCarbs)) g", "Carbs", Theme.carbs)
                statTile("🥑", "\(Int(vm.overrideFat)) g", "Fat", Theme.fat)
            }
            HStack(spacing: 10) {
                statTile("🌾", "\(Int(r.fiberGrams)) g", "Fiber", Theme.fiber)
                statTile("💧", "\(Int(r.waterMl / 250)) glasses", "Water", Theme.water)
            }

            ForEach(r.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 10) {
                    Text("💛").accessibilityHidden(true)
                    Text(note).font(.rounded(.subheadline))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.saffron.opacity(0.16), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
            }

            accuracyCard(r)

            TargetExplainerCard(input: vm.goalInput, result: r)

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(r.breakdown) { row in
                        HStack(alignment: .top, spacing: 12) {
                            Text(row.emoji).font(.title3).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(row.title).font(.rounded(.subheadline, weight: .bold))
                                    Spacer()
                                    Text(row.value).font(.rounded(.subheadline, weight: .semibold))
                                }
                                Text(row.detail)
                                    .font(.rounded(.caption))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("These are estimates for everyday use, not medical advice.")
                        .font(.rounded(.caption2))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 12)
            } label: {
                Text("🤔 Why these numbers?")
                    .font(.rounded(.headline, weight: .semibold))
            }
            .tint(Theme.saffron)
            .appCard()

            DisclosureGroup {
                VStack(spacing: 12) {
                    LabeledNumberField("Calories", value: $vm.overrideCalories, unit: "kcal", emoji: "🔥")
                    LabeledNumberField("Protein", value: $vm.overrideProtein, unit: "g", emoji: "🥚")
                    LabeledNumberField("Carbs", value: $vm.overrideCarbs, unit: "g", emoji: "🍚")
                    LabeledNumberField("Fat", value: $vm.overrideFat, unit: "g", emoji: "🥑")
                }
                .padding(.top, 12)
            } label: {
                Text("✏️ Adjust my targets")
                    .font(.rounded(.headline, weight: .semibold))
            }
            .tint(Theme.saffron)
            .appCard()
        } else {
            FriendlyEmptyState(
                emoji: "🤔",
                title: "We couldn't build your plan",
                message: vm.errorMessage ?? "Go back and check your details.",
                actionTitle: "Go back",
                action: { move(forward: false) }
            )
        }
    }

    private func statTile(_ emoji: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title2).accessibilityHidden(true)
            Text(value)
                .font(.rounded(.headline, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.rounded(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func accuracyCard(_ r: GoalCalculationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Accuracy \(r.accuracy.emoji)")
                    .font(.rounded(.headline, weight: .semibold))
                Spacer()
                Text(r.accuracy.displayName)
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.leaf)
            }
            if r.accuracy < .sharp {
                Text(r.accuracy == .basic
                     ? "Add your body fat or lean mass to sharpen these numbers."
                     : "Add your lean mass if you know it to sharpen these numbers.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                Button("Add body details 🎯") {
                    withAnimation { vm.goBackToFineTune() }
                }
                .buttonStyle(.soft)
            } else {
                Text("Nice! Your plan uses your own body composition.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
    }

    private var healthPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle("❤️", "Connect Apple Health?", "Optional. We can read steps, active energy and body weight so you don't have to type them.")
            VStack(alignment: .leading, spacing: 14) {
                featureRow("👟", "Steps and activity", "See your daily movement on the Today screen.")
                featureRow("⚖️", "Body weight", "Keep your progress chart up to date.")
                featureRow("🔒", "Stays on your phone", "The app works fully if you skip or say no.")
            }
            .appCard()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.rounded(.headline, weight: .bold))
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Saving

    private func finish() {
        let profile = UserProfile(
            age: vm.age,
            sex: vm.sex,
            heightCm: vm.heightCm,
            weightKg: vm.weightKg,
            activity: vm.activity,
            goal: vm.goal,
            dietPref: vm.dietPref
        )
        profile.pace = vm.pace
        profile.bodyFatPercent = vm.goalInput.bodyFatPercent
        profile.leanMassKg = vm.goalInput.leanMassKg
        profile.targets = MacroTargets(
            calories: vm.overrideCalories,
            proteinGrams: vm.overrideProtein,
            fatGrams: vm.overrideFat,
            carbGrams: vm.overrideCarbs
        )
        if let result = vm.result {
            profile.fiberTargetG = result.fiberGrams
            profile.waterTargetMl = result.waterMl
        }
        profile.onboardingComplete = true
        modelContext.insert(profile)
        modelContext.insert(BodyWeightSample(weightKg: vm.weightKg))
        try? modelContext.save()
    }
}

// MARK: - View model

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome, about, body, activity, goal, diet, fineTune, results, health
    }

    struct BodyFatChoice {
        let value: Double
        let emoji: String
        let title: String
        let subtitle: String
    }

    @Published var step: Step = .welcome
    @Published var goingForward = true
    @Published var age = 28
    /// Body-fat choices store sex-specific percentages, so a stale pick is cleared when sex changes.
    @Published var sex: BiologicalSex = .female {
        didSet { if sex != oldValue { bodyFatInput = 0 } }
    }
    @Published var heightCm = 160.0
    @Published var weightKg = 62.0
    @Published var activity: ActivityLevel = .light
    @Published var goal: FitnessGoal = .lose
    @Published var pace: Pace = .steady
    @Published var dietPref: DietPreference = .veg
    /// 0 means "not provided".
    @Published var bodyFatInput = 0.0
    @Published var leanMassInput = 0.0
    @Published var result: GoalCalculationResult?
    @Published var errorMessage: String?
    @Published var overrideCalories = 0.0
    @Published var overrideProtein = 0.0
    @Published var overrideFat = 0.0
    @Published var overrideCarbs = 0.0

    var goalInput: GoalInput {
        GoalInput(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            sex: sex,
            activity: activity,
            goal: goal,
            pace: pace,
            diet: dietPref,
            bodyFatPercent: bodyFatInput > 0 ? bodyFatInput : nil,
            leanMassKg: leanMassInput > 0 ? leanMassInput : nil
        )
    }

    var hasBodyDetails: Bool { bodyFatInput > 0 || leanMassInput > 0 }

    /// 0...1 across the question steps (welcome counts as 0).
    var progress: Double {
        Double(step.rawValue) / Double(Step.health.rawValue)
    }

    /// Estimated weekly weight change at the chosen pace, for the pace picker caption.
    var paceSummary: String? {
        guard let r = try? GoalEngine.calculate(goalInput) else { return nil }
        let weeklyKg = (r.targets.calories - r.tdee) * 7 / 7700
        if abs(weeklyKg) < 0.05 { return "You'd eat about what you burn." }
        let amount = abs(weeklyKg).formatted(.number.precision(.fractionLength(1)))
        return weeklyKg < 0 ? "About \(amount) kg lost a week" : "About \(amount) kg gained a week"
    }

    /// Body-fat guesses with sex-appropriate midpoints. Women naturally carry more essential fat.
    var bodyFatChoices: [BodyFatChoice] {
        let male: [Double] = [12, 17, 22, 28, 35]
        let female: [Double] = [20, 24, 30, 36, 42]
        let values: [Double]
        switch sex {
        case .male: values = male
        case .female: values = female
        case .other: values = zip(male, female).map { ($0 + $1) / 2 }
        }
        let labels: [(String, String)] = [
            ("🏃", "Very lean"), ("💪", "Lean"), ("🙂", "Average"), ("🤗", "Above average"), ("🫂", "High"),
        ]
        var choices = [BodyFatChoice(value: 0, emoji: "🤷", title: "Not sure", subtitle: "Skip this")]
        for (value, label) in zip(values, labels) {
            choices.append(BodyFatChoice(value: value, emoji: label.0, title: label.1, subtitle: "about \(Int(value.rounded()))%"))
        }
        return choices
    }

    /// Moves to the next step. Returns false if validation blocked it.
    @discardableResult
    func goNext() -> Bool {
        errorMessage = nil
        if step == .body || step == .fineTune {
            do {
                try GoalEngine.validate(goalInput)
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
        guard let next = Step(rawValue: step.rawValue + 1) else { return false }
        if next == .results {
            guard calculate() else { return false }
        }
        goingForward = true
        step = next
        return true
    }

    func goBack() {
        errorMessage = nil
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        goingForward = false
        step = previous
    }

    func goBackToFineTune() {
        goingForward = false
        step = .fineTune
    }

    /// Runs the engine and fills the editable targets. Returns false (and sets an error) on bad input.
    func calculate() -> Bool {
        do {
            let r = try GoalEngine.calculate(goalInput)
            result = r
            overrideCalories = r.targets.calories
            overrideProtein = r.targets.proteinGrams
            overrideFat = r.targets.fatGrams
            overrideCarbs = r.targets.carbGrams
            return true
        } catch {
            result = nil
            errorMessage = error.localizedDescription
            return false
        }
    }
}
