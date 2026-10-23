import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var settingsList: [AppSettings]
    @State private var exportURL: URL?
    @State private var showExport = false
    @State private var showDeleteConfirm = false
    @State private var weightInput = ""

    private var profile: UserProfile? { profiles.first }
    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                if let profile {
                    Section("Profile & targets") {
                        Stepper("Age: \(profile.age)", value: Binding(
                            get: { profile.age },
                            set: { profile.age = $0; profile.updatedAt = Date() }
                        ), in: 15...80)
                        Picker("Sex", selection: Binding(
                            get: { profile.sex },
                            set: { profile.sex = $0 }
                        )) {
                            ForEach(BiologicalSex.allCases) { Text($0.displayName).tag($0) }
                        }
                        numberRow("Height cm", value: Binding(get: { profile.heightCm }, set: { profile.heightCm = $0 }))
                        numberRow("Weight kg", value: Binding(get: { profile.weightKg }, set: { profile.weightKg = $0 }))
                        Picker("Activity", selection: Binding(get: { profile.activity }, set: { profile.activity = $0 })) {
                            ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0) }
                        }
                        Picker("Goal", selection: Binding(get: { profile.goal }, set: { profile.goal = $0 })) {
                            ForEach(FitnessGoal.allCases) { Text($0.displayName).tag($0) }
                        }
                        Picker("Diet", selection: Binding(get: { profile.dietPref }, set: { profile.dietPref = $0 })) {
                            ForEach(DietPreference.allCases) { Text($0.displayName).tag($0) }
                        }
                        numberRow("Calorie target", value: Binding(get: { profile.calorieTarget }, set: { profile.calorieTarget = $0 }))
                        numberRow("Protein g", value: Binding(get: { profile.proteinTargetG }, set: { profile.proteinTargetG = $0 }))
                        numberRow("Fat g", value: Binding(get: { profile.fatTargetG }, set: { profile.fatTargetG = $0 }))
                        numberRow("Carb g", value: Binding(get: { profile.carbTargetG }, set: { profile.carbTargetG = $0 }))
                        Stepper("Step target: \(profile.stepTarget)", value: Binding(
                            get: { profile.stepTarget },
                            set: { profile.stepTarget = $0 }
                        ), in: 2000...30000, step: 500)
                        Button("Recalculate from profile") {
                            let r = GoalEngine.calculate(
                                weightKg: profile.weightKg,
                                heightCm: profile.heightCm,
                                age: profile.age,
                                sex: profile.sex,
                                activity: profile.activity,
                                goal: profile.goal
                            )
                            profile.targets = r.targets
                        }
                    }
                }

                Section("Log weight") {
                    HStack {
                        TextField("kg", text: $weightInput)
                            .keyboardType(.decimalPad)
                        Button("Save") {
                            if let kg = Double(weightInput.replacingOccurrences(of: ",", with: ".")) {
                                modelContext.insert(BodyWeightSample(weightKg: kg))
                                profile?.weightKg = kg
                                weightInput = ""
                                try? modelContext.save()
                            }
                        }
                    }
                    Button("Import latest from Health") {
                        Task {
                            if let kg = await HealthKitService.shared.latestBodyMassKg() {
                                modelContext.insert(BodyWeightSample(weightKg: kg, fromHealthKit: true))
                                profile?.weightKg = kg
                                try? modelContext.save()
                            }
                        }
                    }
                }

                if let settings {
                    Section("Notifications") {
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
                        Stepper("Reminder hour: \(settings.mealReminderHour):00", value: Binding(
                            get: { settings.mealReminderHour },
                            set: { settings.mealReminderHour = $0 }
                        ), in: 7...21)
                        .disabled(!settings.notificationsEnabled)
                    }
                }

                Section("Health") {
                    Button("Request Health access") {
                        Task { await HealthKitService.shared.requestAuthorization() }
                    }
                }

                Section("Data") {
                    Button("Export all data (JSON)") {
                        exportData()
                    }
                    Button("Delete all data", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }

                Section("About") {
                    NavigationLink("Disclaimer") { DisclaimerView() }
                    NavigationLink("About calculations") { AboutCalculationsView() }
                    Text("iCloud sync is not included in Phase 1 (planned for Phase 2).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
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
            .sheet(isPresented: $showExport) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
        }
    }

    private func numberRow(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
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

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            Text("""
            NutriLift India is a personal logging tool, not medical advice, diagnosis, or treatment.

            Calorie and macro targets, photo estimates, and coaching tips are approximate. Talk to a qualified clinician before large diet changes, especially if you are pregnant, under 18, or managing a medical condition.

            Extreme or unsafe diet advice is intentionally limited in the app.
            """)
            .padding()
        }
        .navigationTitle("Disclaimer")
    }
}

struct AboutCalculationsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("BMR").font(.headline)
                Text("Mifflin-St Jeor: (10×kg) + (6.25×cm) − (5×age) + sex offset (+5 male, −161 female, −78 other).")
                Text("TDEE").font(.headline)
                Text("BMR × activity factor (1.2–1.9).")
                Text("Targets").font(.headline)
                Text("Calories: TDEE + goal delta (−500 lose / 0 maintain / +300 gain), floored at 800 kcal. Protein by g/kg goal. Fat ~27.5% of calories. Carbs = remainder.")
                Text("Food database").font(.headline)
                Text("Seed foods use IFCT-inspired or estimated household values with confidence tags. Treat as guides.")
                Text("Photo estimates").font(.headline)
                Text("On-device Apple Foundation Models only when available. Photos are not uploaded. Values are estimates — always confirm/edit before save. Photos are discarded after logging by default.")
                Text("Strength").font(.headline)
                Text("Estimated 1RM uses Epley: weight × (1 + reps/30).")
            }
            .padding()
        }
        .navigationTitle("Calculations")
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
