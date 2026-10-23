import SwiftUI
import SwiftData

struct CoachHomeView: View {
    @Query private var profiles: [UserProfile]
    @Query private var diary: [FoodDiaryEntry]
    @Query private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]

    @State private var question = ""
    @State private var answer = ""
    @State private var useFoundationModels = false

    private var fmAvailable: Bool {
        PhotoNutritionEstimatorFactory.make().isAvailable
    }

    private var badgeTitle: String {
        useFoundationModels && fmAvailable ? "On-device" : "Basic answers (AI unavailable)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Coach mode")
                        Spacer()
                        Text(badgeTitle)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(fmAvailable && useFoundationModels ? Color.green.opacity(0.2) : Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if fmAvailable {
                        Toggle("Prefer on-device Foundation Models", isOn: $useFoundationModels)
                    } else {
                        Text("Apple Foundation Models unavailable on this device. Rule-based answers stay on.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Ask") {
                    TextField("e.g. remaining protein, meal ideas…", text: $question, axis: .vertical)
                    Button("Get answer") {
                        answer = CoachEngine.answer(
                            question: question,
                            profile: profiles.first,
                            diary: diary,
                            sessions: sessions,
                            templates: templates,
                            preferOnDeviceModel: useFoundationModels && fmAvailable
                        )
                    }
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !answer.isEmpty {
                    Section("Answer") {
                        Text(answer)
                    }
                }

                Section("Quick questions") {
                    ForEach(CoachEngine.quickPrompts, id: \.self) { prompt in
                        Button(prompt) {
                            question = prompt
                            answer = CoachEngine.answer(
                                question: prompt,
                                profile: profiles.first,
                                diary: diary,
                                sessions: sessions,
                                templates: templates,
                                preferOnDeviceModel: useFoundationModels && fmAvailable
                            )
                        }
                    }
                }
            }
            .navigationTitle("Coach")
        }
    }
}

enum CoachEngine {
    static let quickPrompts = [
        "How many calories remaining today?",
        "How much protein remaining?",
        "How is my weekly volume?",
        "Suggest a high-protein meal",
    ]

    static func answer(
        question: String,
        profile: UserProfile?,
        diary: [FoodDiaryEntry],
        sessions: [WorkoutSession],
        templates: [WorkoutTemplate],
        preferOnDeviceModel: Bool
    ) -> String {
        // Phase 1: rule-based path is the working coach. FM chat is stubbed behind availability.
        if preferOnDeviceModel {
            return """
            On-device chat stub: Foundation Models is available, but Phase 1 uses grounded rule-based answers for reliability.
            \(ruleBased(question: question, profile: profile, diary: diary, sessions: sessions, templates: templates))
            """
        }
        return ruleBased(question: question, profile: profile, diary: diary, sessions: sessions, templates: templates)
    }

    private static func ruleBased(
        question: String,
        profile: UserProfile?,
        diary: [FoodDiaryEntry],
        sessions: [WorkoutSession],
        templates: [WorkoutTemplate]
    ) -> String {
        let q = question.lowercased()
        guard let profile else {
            return "Finish onboarding so I can use your targets."
        }
        let consumed = DiaryTotals.totals(for: diary)
        let remaining = DiaryTotals.remaining(targets: profile.targets, consumed: consumed)

        if q.contains("calorie") || q.contains("kcal") {
            return "You have about \(Int(remaining.calories.rounded())) kcal remaining today (target \(Int(profile.calorieTarget)), eaten \(Int(consumed.calories.rounded()))). Estimates only — not medical advice."
        }
        if q.contains("protein") {
            return "Protein remaining: about \(Int(remaining.proteinGrams.rounded())) g (target \(Int(profile.proteinTargetG)) g). Ideas for \(profile.dietPref.displayName): \(InsightsEngine.highProteinSuggestions(for: profile.dietPref))."
        }
        if q.contains("volume") || q.contains("muscle") {
            let vol = VolumeAggregator.weeklySets(sessions: sessions.filter(\.isFinished))
            if vol.isEmpty {
                return "No finished sets this week yet. Try a template like \(templates.first?.name ?? "Full Body A")."
            }
            let summary = vol.prefix(5).map { "\($0.muscleGroup.displayName): \($0.sets)" }.joined(separator: ", ")
            return "This week’s sets — \(summary)."
        }
        if q.contains("meal") || q.contains("eat") || q.contains("food") {
            return "Simple \(profile.dietPref.displayName) ideas: \(InsightsEngine.highProteinSuggestions(for: profile.dietPref)). Log with favorites or a meal template for speed."
        }
        if q.contains("workout") || q.contains("train") {
            return "Next idea: \(templates.first?.name ?? "any template") in the Workouts tab. Keep rest times honest and chase small PRs."
        }
        return "I can help with remaining calories/protein, weekly volume, and meal ideas. Try one of the quick questions. Not medical advice."
    }
}
