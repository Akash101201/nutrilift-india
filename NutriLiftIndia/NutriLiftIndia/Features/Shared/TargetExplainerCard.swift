import SwiftUI

@MainActor
final class TargetExplainerModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case written(String)
        /// The model was unavailable or its answer was rejected. `reason` is shown if present.
        case fallback(reason: String?)
    }

    @Published private(set) var state: State = .idle

    let input: GoalInput
    let result: GoalCalculationResult
    let aiAvailable: Bool
    let fallbackText: String

    init(input: GoalInput, result: GoalCalculationResult) {
        self.input = input
        self.result = result
        self.aiAvailable = TargetExplainer.isAvailable
        self.fallbackText = TargetExplanation.fallbackText(input: input, result: result)
    }

    func generate() async {
        guard state != .loading else { return }
        state = .loading
        do {
            let text = try await TargetExplainer.explain(input: input, result: result)
            state = .written(text)
        } catch {
            state = .fallback(reason: (error as? LocalizedError)?.errorDescription)
        }
    }
}

/// "Why this is yours": explains the calculated targets in plain language.
/// With Apple Intelligence the wording is written on-device; otherwise a built-in personalised
/// explanation built from the same numbers is shown straight away.
struct TargetExplainerCard: View {
    @StateObject private var model: TargetExplainerModel

    init(input: GoalInput, result: GoalCalculationResult) {
        _model = StateObject(wrappedValue: TargetExplainerModel(input: input, result: result))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmojiHeader(emoji: "✨", title: "Why this is yours")
            content
        }
        .appCard()
        .animation(.easeInOut(duration: 0.25), value: model.state)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            if model.aiAvailable {
                Text("See how your body, activity, goal and diet shaped these numbers.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                Button("Explain it for me ✨") {
                    Task { await model.generate() }
                }
                .buttonStyle(.gradient)
            } else {
                explanation(model.fallbackText, caption: "💬 In plain words, written from your numbers.")
            }

        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text("Your coach is writing… ✍️")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)

        case .written(let text):
            explanation(text, caption: "🔒 Written on your device with Apple Intelligence. Your data never leaves your phone.")
            Button("Write it again 🔄") {
                Task { await model.generate() }
            }
            .buttonStyle(.soft)

        case .fallback(let reason):
            explanation(model.fallbackText, caption: reason ?? "💬 In plain words, written from your numbers.")
        }
    }

    private func explanation(_ text: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.rounded(.body))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Text(caption)
                .font(.rounded(.caption))
                .foregroundStyle(.secondary)
        }
    }
}
