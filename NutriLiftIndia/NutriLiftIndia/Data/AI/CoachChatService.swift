import Foundation
import SwiftData

/// Orchestrates Coach replies: Apple Foundation Models when available and grounded, else rule-based.
enum CoachChatService {
    struct Reply: Equatable, Sendable {
        var text: String
        var usedOnDevice: Bool
    }

    /// Builds a reply for `question` using local logs. Safe to call from the main actor.
    static func reply(
        question: String,
        profile: UserProfile?,
        diary: [FoodDiaryEntry],
        sessions: [WorkoutSession],
        templates: [WorkoutTemplate],
        priorMessages: [CoachChatMessage]
    ) async -> Reply {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Reply(text: "Ask me anything about your food, macros, or training.", usedOnDevice: false)
        }

        let history = priorMessages.map { (isUser: $0.isUser, text: $0.text) }
        let pack = CoachChat.context(
            profile: profile,
            diary: diary,
            sessions: sessions,
            templates: templates,
            history: history,
            question: trimmed
        )

        let fallback = CoachChat.ruleBasedAnswer(
            question: trimmed,
            profile: profile,
            diary: diary,
            sessions: sessions,
            templates: templates
        )

        guard OnDeviceWriter.isAvailable else {
            return Reply(text: fallback, usedOnDevice: false)
        }

        do {
            let text = try await OnDeviceWriter.write(
                instructions: CoachChat.instructions,
                prompt: pack.promptBody,
                facts: pack.facts,
                minLength: 20,
                maxLength: 2000
            )
            return Reply(text: text, usedOnDevice: true)
        } catch {
            return Reply(text: fallback, usedOnDevice: false)
        }
    }

    // MARK: Session helpers

    @MainActor
    static func createSession(in context: ModelContext) -> CoachChatSession {
        let session = CoachChatSession()
        context.insert(session)
        try? context.save()
        return session
    }

    @MainActor
    static func deleteSession(_ session: CoachChatSession, in context: ModelContext) {
        context.delete(session)
        try? context.save()
    }

    @MainActor
    static func appendExchange(
        session: CoachChatSession,
        userText: String,
        reply: Reply,
        context: ModelContext
    ) {
        let user = CoachChatMessage(role: .user, text: userText)
        let assistant = CoachChatMessage(role: .assistant, text: reply.text, usedOnDevice: reply.usedOnDevice)
        user.session = session
        assistant.session = session
        session.messages.append(user)
        session.messages.append(assistant)
        session.updatedAt = Date()
        if session.title == "New chat" || session.messages.filter(\.isUser).count == 1 {
            session.title = CoachChat.title(from: userText)
        }
        try? context.save()
    }
}
