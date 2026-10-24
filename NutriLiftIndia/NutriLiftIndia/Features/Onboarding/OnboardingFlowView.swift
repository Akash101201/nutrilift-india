import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch vm.step {
                case .privacy:
                    privacyPage
                case .basics:
                    basicsPage
                case .goals:
                    goalsPage
                case .results:
                    resultsPage
                case .health:
                    healthPage
                }
            }
            .animation(.easeInOut, value: vm.step)
        }
    }

    private var privacyPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
            Text("NutriLift India")
                .font(.largeTitle.bold())
            Text("Privacy-first fitness tracking")
                .font(.title3)
            Text("Your food, workouts, and health data stay on this device. No account, no ads, no selling data. Core logging is free forever.")
                .foregroundStyle(.secondary)
            Text("Not medical advice. Targets are estimates to guide everyday logging.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Continue") { vm.step = .basics }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .navigationTitle("Welcome")
    }

    private var basicsPage: some View {
        Form {
            Section("About you") {
                Stepper("Age: \(vm.age)", value: $vm.age, in: 15...80)
                Picker("Sex", selection: $vm.sex) {
                    ForEach(BiologicalSex.allCases) { Text($0.displayName).tag($0) }
                }
                HStack {
                    Text("Height (cm)")
                    Spacer()
                    TextField("cm", value: $vm.heightCm, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("kg", value: $vm.weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
            Section {
                Button("Next") { vm.step = .goals }
            }
        }
        .navigationTitle("Profile")
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { vm.step = .privacy }
            }
        }
    }

    private var goalsPage: some View {
        Form {
            Section("Activity") {
                ForEach(ActivityLevel.allCases) { level in
                    Button {
                        vm.activity = level
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.displayName)
                                    .foregroundStyle(.primary)
                                Text(level.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            if vm.activity == level {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("Goal") {
                Picker("Goal", selection: $vm.goal) {
                    ForEach(FitnessGoal.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("Diet preference") {
                Picker("Diet", selection: $vm.dietPref) {
                    ForEach(DietPreference.allCases) { Text($0.displayName).tag($0) }
                }
            }
            Section {
                Button("Calculate targets") {
                    vm.calculate()
                    vm.step = .results
                }
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { vm.step = .basics }
            }
        }
    }

    private var resultsPage: some View {
        Form {
            if let result = vm.result {
                Section("Explanation") {
                    Text(result.explanation)
                        .font(.footnote)
                }
                if result.blockedExtreme {
                    Section {
                        Text("Extreme calorie targets are blocked. We floored your target at \(Int(GoalEngine.extremeLowCalorieFloor)) kcal for safety. This is not medical advice.")
                            .foregroundStyle(.orange)
                    }
                } else if result.isVeryLowCalorie {
                    Section {
                        Text("Your target is under \(Int(GoalEngine.veryLowCalorieThreshold)) kcal. Consider a smaller deficit unless a clinician advised otherwise.")
                            .foregroundStyle(.orange)
                    }
                }
                Section("Targets (editable)") {
                    targetField("Calories", value: $vm.overrideCalories)
                    targetField("Protein (g)", value: $vm.overrideProtein)
                    targetField("Fat (g)", value: $vm.overrideFat)
                    targetField("Carbs (g)", value: $vm.overrideCarbs)
                }
            }
            Section {
                Button("Continue") { vm.step = .health }
            }
        }
        .navigationTitle("Your targets")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { vm.step = .goals }
            }
        }
    }

    private var healthPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apple Health (optional)")
                .font(.title2.bold())
            Text("Connect to read steps, active energy, workouts, and body mass. The app works fully if you skip or deny.")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Connect Health") {
                Task {
                    await HealthKitService.shared.requestAuthorization()
                    finish()
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            Button("Not now") { finish() }
                .frame(maxWidth: .infinity)
        }
        .padding()
        .navigationTitle("Health")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { vm.step = .results }
            }
        }
    }

    private func targetField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }

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
        profile.targets = MacroTargets(
            calories: vm.overrideCalories,
            proteinGrams: vm.overrideProtein,
            fatGrams: vm.overrideFat,
            carbGrams: vm.overrideCarbs
        )
        profile.onboardingComplete = true
        modelContext.insert(profile)
        modelContext.insert(BodyWeightSample(weightKg: vm.weightKg))
        try? modelContext.save()
    }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step {
        case privacy, basics, goals, results, health
    }

    @Published var step: Step = .privacy
    @Published var age = 28
    @Published var sex: BiologicalSex = .female
    @Published var heightCm = 160.0
    @Published var weightKg = 62.0
    @Published var activity: ActivityLevel = .moderate
    @Published var goal: FitnessGoal = .lose
    @Published var dietPref: DietPreference = .veg
    @Published var result: GoalCalculationResult?
    @Published var overrideCalories = 1800.0
    @Published var overrideProtein = 120.0
    @Published var overrideFat = 55.0
    @Published var overrideCarbs = 180.0

    func calculate() {
        let r = GoalEngine.calculate(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            sex: sex,
            activity: activity,
            goal: goal
        )
        result = r
        overrideCalories = r.targets.calories
        overrideProtein = r.targets.proteinGrams
        overrideFat = r.targets.fatGrams
        overrideCarbs = r.targets.carbGrams
    }
}
