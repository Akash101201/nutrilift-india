import SwiftUI
import SwiftData

/// Lists saved Coach chat sessions. Opens a thread or starts a new one.
struct CoachHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CoachChatSession.updatedAt, order: .reverse) private var sessions: [CoachChatSession]

    @State private var pendingDelete: CoachChatSession?
    @State private var showDeleteConfirm = false
    @State private var newSession: CoachChatSession?
    @State private var showNewSession = false

    private var fmAvailable: Bool { OnDeviceWriter.isAvailable }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .appBackground()
            .navigationTitle("Coach")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New chat")
                }
            }
            .navigationDestination(isPresented: $showNewSession) {
                if let newSession {
                    CoachSessionView(session: newSession)
                }
            }
            .confirmationDialog(
                "Delete this chat?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete chat", role: .destructive) {
                    if let pendingDelete {
                        CoachChatService.deleteSession(pendingDelete, in: modelContext)
                        self.pendingDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Messages in this chat will be removed from your phone.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("🤖")
                .font(.system(size: 56))
            Text("Your private coach")
                .font(.rounded(.title2, weight: .bold))
            Text(
                fmAvailable
                    ? "Chat with on-device Apple Intelligence about your food, macros, and workouts. Nothing leaves your iPhone."
                    : "Ask about calories, protein, volume, and meal ideas. Answers use your on-device logs (Apple Intelligence unlocks richer chat on supported devices)."
            )
            .font(.rounded(.body))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)

            Button("Start a chat") { startNewChat() }
                .buttonStyle(.gradient)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            availabilityBadge
            Spacer()
        }
        .padding(.bottom, 40)
    }

    private var sessionList: some View {
        List {
            Section {
                availabilityRow
            }
            .listRowBackground(Theme.card)

            Section {
                ForEach(sessions, id: \.id) { session in
                    NavigationLink {
                        CoachSessionView(session: session)
                    } label: {
                        sessionRow(session)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            pendingDelete = session
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingDelete = session
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete chat", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Chats")
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
    }

    private func sessionRow(_ session: CoachChatSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(.rounded(.headline, weight: .semibold))
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.rounded(.caption))
                    .foregroundStyle(.secondary)
                if session.messages.contains(where: \.usedOnDevice) {
                    Text("🔒 On-device")
                        .font(.rounded(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.leaf)
                }
            }
            if let preview = session.sortedMessages.last(where: { !$0.isUser })?.text {
                Text(preview)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.title), \(session.updatedAt.formatted())")
    }

    private var availabilityRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(fmAvailable ? "🔒" : "💬")
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(fmAvailable ? "On-device Apple Intelligence" : "Basic answers")
                    .font(.rounded(.subheadline, weight: .semibold))
                Text(
                    fmAvailable
                        ? "Replies are written on this iPhone from your logs. Chats are not uploaded."
                        : "Rule-based coaching from your logs. Richer chat needs Apple Intelligence on a supported device."
                )
                .font(.rounded(.caption))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var availabilityBadge: some View {
        Text(fmAvailable ? "🔒 On-device ready" : "💬 Basic answers")
            .font(.rounded(.caption, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                (fmAvailable ? Theme.leaf : Color.secondary).opacity(0.18),
                in: Capsule()
            )
    }

    private func startNewChat() {
        Haptics.tap()
        let session = CoachChatService.createSession(in: modelContext)
        newSession = session
        showNewSession = true
    }
}
