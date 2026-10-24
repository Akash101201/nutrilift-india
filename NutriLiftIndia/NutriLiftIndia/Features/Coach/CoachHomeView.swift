import SwiftUI
import SwiftData

struct CoachHomeView: View {
    @Query private var profiles: [UserProfile]
    @Query private var diary: [FoodDiaryEntry]
    @Query private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]

    private struct ChatMessage: Identifiable {
        let id = UUID()
        let isUser: Bool
        let text: String
    }

    @State private var question = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(
            isUser: false,
            text: "Hi! I'm your coach 👋 Ask me about your calories, protein, weekly volume or meal ideas."
        ),
    ]
    @State private var useFoundationModels = false

    private let promptEmojis = ["🔥", "🥚", "📊", "🍛"]

    private var fmAvailable: Bool {
        PhotoNutritionEstimatorFactory.make().isAvailable
    }

    private var badgeTitle: String {
        useFoundationModels && fmAvailable ? "🔒 On-device" : "💬 Basic answers"
    }

    private var canSend: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        modeCard
                        ForEach(messages) { message in
                            bubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .appBackground()
            .navigationTitle("Coach")
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
        }
    }

    // MARK: Pieces

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Coach mode")
                    .font(.rounded(.subheadline, weight: .semibold))
                Spacer()
                Text(badgeTitle)
                    .font(.rounded(.caption, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (fmAvailable && useFoundationModels ? Theme.leaf : Color.secondary).opacity(0.18),
                        in: Capsule()
                    )
            }
            if fmAvailable {
                Toggle("Prefer on-device Foundation Models", isOn: $useFoundationModels)
                    .font(.rounded(.subheadline))
                    .tint(Theme.saffron)
            } else {
                Text("Apple Foundation Models unavailable on this device. Rule-based answers stay on.")
                    .font(.rounded(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(.rounded(.body))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                Text("🤖")
                    .font(.title2)
                    .accessibilityLabel("Coach")
                Text(message.text)
                    .font(.rounded(.body))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                Spacer(minLength: 32)
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(CoachEngine.quickPrompts.enumerated()), id: \.offset) { index, prompt in
                        Button {
                            send(prompt)
                        } label: {
                            Text("\(index < promptEmojis.count ? promptEmojis[index] : "💬") \(prompt)")
                                .font(.rounded(.footnote, weight: .semibold))
                                .foregroundStyle(Theme.saffron)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.saffron.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            HStack(spacing: 10) {
                TextField("Ask your coach…", text: $question, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.rounded(.body))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                Button {
                    send(question)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(canSend ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Color.secondary.opacity(0.4)))
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.tap()
        messages.append(ChatMessage(isUser: true, text: trimmed))
        let reply = CoachEngine.answer(
            question: trimmed,
            profile: profiles.first,
            diary: diary,
            sessions: sessions,
            templates: templates,
            preferOnDeviceModel: useFoundationModels && fmAvailable
        )
        messages.append(ChatMessage(isUser: false, text: reply))
        question = ""
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
