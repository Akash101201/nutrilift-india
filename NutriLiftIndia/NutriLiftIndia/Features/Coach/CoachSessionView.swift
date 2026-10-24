import SwiftUI
import SwiftData

/// One Coach conversation thread with on-device Foundation Models (when available).
struct CoachSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var session: CoachChatSession

    @Query private var profiles: [UserProfile]
    @Query private var diary: [FoodDiaryEntry]
    @Query private var workoutSessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]

    @State private var question = ""
    @State private var isThinking = false
    @State private var showDeleteConfirm = false
    @State private var lastUsedOnDevice: Bool?

    private let promptEmojis = ["🔥", "🥚", "📊", "🍛"]

    private var fmAvailable: Bool { OnDeviceWriter.isAvailable }

    private var canSend: Bool {
        !isThinking && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var badgeTitle: String {
        if let lastUsedOnDevice {
            return lastUsedOnDevice ? "🔒 On-device" : "💬 Basic answers"
        }
        return fmAvailable ? "🔒 On-device ready" : "💬 Basic answers"
    }

    private var sortedMessages: [CoachChatMessage] {
        session.sortedMessages
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statusCard
                    if sortedMessages.isEmpty {
                        bubble(isUser: false, text: CoachChat.welcomeText)
                    }
                    ForEach(sortedMessages, id: \.id) { message in
                        bubble(isUser: message.isUser, text: message.text, onDevice: message.isUser ? nil : message.usedOnDevice)
                            .id(message.id)
                    }
                    if isThinking {
                        thinkingRow
                            .id("thinking")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: sortedMessages.count) { _, _ in
                scrollToEnd(proxy: proxy)
            }
            .onChange(of: isThinking) { _, thinking in
                if thinking { scrollToEnd(proxy: proxy) }
            }
        }
        .appBackground()
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Chat options")
            }
        }
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
        .confirmationDialog(
            "Delete this chat?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete chat", role: .destructive) {
                CoachChatService.deleteSession(session, in: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This conversation will be removed from your phone.")
        }
    }

    // MARK: Pieces

    private var statusCard: some View {
        HStack {
            Text("Coach")
                .font(.rounded(.subheadline, weight: .semibold))
            Spacer()
            Text(badgeTitle)
                .font(.rounded(.caption, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    ((lastUsedOnDevice ?? fmAvailable) ? Theme.leaf : Color.secondary).opacity(0.18),
                    in: Capsule()
                )
        }
        .appCard()
    }

    private var thinkingRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("🤖")
                .font(.title2)
            HStack(spacing: 10) {
                ProgressView()
                Text(fmAvailable ? "Writing on-device…" : "Thinking…")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Spacer(minLength: 32)
        }
    }

    @ViewBuilder
    private func bubble(isUser: Bool, text: String, onDevice: Bool? = nil) -> some View {
        if isUser {
            HStack {
                Spacer(minLength: 48)
                Text(text)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(text)
                        .font(.rounded(.body))
                        .textSelection(.enabled)
                    if let onDevice {
                        Text(onDevice
                             ? "🔒 Written on your device"
                             : "💬 From your on-device logs")
                            .font(.rounded(.caption2))
                            .foregroundStyle(.secondary)
                    }
                }
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
            if sortedMessages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(CoachChat.quickPrompts.enumerated()), id: \.offset) { index, prompt in
                            Button {
                                Task { await send(prompt) }
                            } label: {
                                Text("\(index < promptEmojis.count ? promptEmojis[index] : "💬") \(prompt)")
                                    .font(.rounded(.footnote, weight: .semibold))
                                    .foregroundStyle(Theme.saffron)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Theme.saffron.opacity(0.14), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isThinking)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            HStack(spacing: 10) {
                TextField("Ask your coach…", text: $question, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.rounded(.body))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    .disabled(isThinking)
                Button {
                    Task { await send(question) }
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

    // MARK: Actions

    private func scrollToEnd(proxy: ScrollViewProxy) {
        if isThinking {
            withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
        } else if let last = sortedMessages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    @MainActor
    private func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        Haptics.tap()
        question = ""
        isThinking = true

        let prior = session.sortedMessages
        let reply = await CoachChatService.reply(
            question: trimmed,
            profile: profiles.first,
            diary: diary,
            sessions: workoutSessions,
            templates: templates,
            priorMessages: prior
        )

        CoachChatService.appendExchange(
            session: session,
            userText: trimmed,
            reply: reply,
            context: modelContext
        )
        lastUsedOnDevice = reply.usedOnDevice
        isThinking = false
        Haptics.success()
    }
}
