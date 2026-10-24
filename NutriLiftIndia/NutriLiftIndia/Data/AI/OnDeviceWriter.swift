import Foundation

/// Gets short, friendly text from Apple Foundation Models, entirely on-device.
///
/// The model never computes anything. Callers pass the facts it may use, and its answer is only
/// accepted if every number in it also appears in those facts (see `Grounding`). Callers should
/// always have their own built-in text ready for when this throws.
enum OnDeviceWriter {
    enum WriteError: LocalizedError, Equatable {
        case unavailable
        case notGrounded
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable: "On-device writing needs Apple Intelligence on a supported device."
            case .notGrounded: "The on-device answer didn't match the real numbers, so we're showing the standard version instead."
            case .failed(let message): message
            }
        }
    }

    /// True only when the system language model is installed and ready right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return OnDeviceModelBridge.isAvailable
        }
        #endif
        return false
    }

    /// Returns grounded model text, or throws. Retries once with a firmer reminder if the first answer strays.
    static func write(
        instructions: String,
        prompt: String,
        facts: [String],
        minLength: Int = 40,
        maxLength: Int = 1500
    ) async throws -> String {
        guard isAvailable else { throw WriteError.unavailable }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let reminder = "\n\nYour previous answer used numbers that were not in the facts. Use only the exact numbers listed above."
            for attempt in 0..<2 {
                let raw = try await OnDeviceModelBridge.respond(
                    instructions: instructions,
                    prompt: attempt == 0 ? prompt : prompt + reminder
                )
                if let text = Grounding.validated(raw, facts: facts, minLength: minLength, maxLength: maxLength) {
                    return text
                }
            }
            throw WriteError.notGrounded
        }
        #endif
        throw WriteError.unavailable
    }
}

#if canImport(FoundationModels)
import FoundationModels

/// Isolates Apple Foundation Models APIs so the rest of the app builds on older SDKs.
/// If Apple changes API names in your Xcode version, update only this bridge.
@available(iOS 26.0, *)
enum OnDeviceModelBridge {
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
            throw OnDeviceWriter.WriteError.failed(error.localizedDescription)
        }
    }
}
#endif
