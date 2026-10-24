import Foundation

/// Words the "why these numbers" explanation on-device. `GoalEngine` supplies every number;
/// `OnDeviceWriter` only accepts an answer that sticks to `TargetExplanation.facts`.
enum TargetExplainer {
    static var isAvailable: Bool { OnDeviceWriter.isAvailable }

    /// Returns a grounded, model-written explanation or throws.
    static func explain(input: GoalInput, result: GoalCalculationResult) async throws -> String {
        try await OnDeviceWriter.write(
            instructions: TargetExplanation.instructions,
            prompt: TargetExplanation.prompt(input: input, result: result),
            facts: TargetExplanation.facts(input: input, result: result)
        )
    }
}
