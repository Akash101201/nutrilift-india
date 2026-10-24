import Foundation

/// Words the "why these numbers" explanation with Apple Foundation Models, entirely on-device.
/// The model never computes anything: `GoalEngine` supplies every number, and the answer is
/// rejected unless it only uses numbers from `TargetExplanation.facts`.
enum TargetExplainer {
    enum ExplainError: LocalizedError, Equatable {
        case unavailable
        case notGrounded
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable: "On-device explanations need Apple Intelligence on a supported device."
            case .notGrounded: "The on-device answer didn't match your numbers, so we're showing the standard explanation."
            case .failed(let message): message
            }
        }
    }

    /// True only when the system language model is installed and ready right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return TargetExplainerBridge.isAvailable
        }
        #endif
        return false
    }

    /// Returns a grounded, model-written explanation or throws.
    static func explain(input: GoalInput, result: GoalCalculationResult) async throws -> String {
        guard isAvailable else { throw ExplainError.unavailable }

        let facts = TargetExplanation.facts(input: input, result: result)
        let basePrompt = TargetExplanation.prompt(input: input, result: result)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // One retry with a firmer reminder if the first answer strays from the facts.
            let reminder = "\n\nYour previous answer used numbers that were not in the facts. Use only the exact numbers listed above."
            for attempt in 0..<2 {
                let prompt = attempt == 0 ? basePrompt : basePrompt + reminder
                let raw = try await TargetExplainerBridge.respond(
                    instructions: TargetExplanation.instructions,
                    prompt: prompt
                )
                if let text = TargetExplanation.validated(raw, facts: facts) {
                    return text
                }
            }
            throw ExplainError.notGrounded
        }
        #endif
        throw ExplainError.unavailable
    }
}

#if canImport(FoundationModels)
import FoundationModels

/// Isolates Apple Foundation Models APIs so the rest of the app builds on older SDKs.
/// If Apple changes API names in your Xcode version, update only this bridge.
@available(iOS 26.0, *)
enum TargetExplainerBridge {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    static func respond(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: prompt)
            return String(describing: response.content)
        } catch {
            throw TargetExplainer.ExplainError.failed(error.localizedDescription)
        }
    }
}
#endif
