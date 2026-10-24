import SwiftUI

enum DailyReviewPhase: Equatable {
    case idle
    case loading
    case ready(text: String, onDevice: Bool)
    case unavailable(String)
}

/// Shared card chrome for end-of-day recap and morning tips.
struct DailyReviewCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let phase: DailyReviewPhase
    var onRefresh: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                EmojiHeader(emoji: emoji, title: title)
                Spacer(minLength: 8)
                if case .ready(_, let onDevice) = phase {
                    Text(onDevice ? "On-device" : "Basic")
                        .font(.rounded(.caption2, weight: .semibold))
                        .foregroundStyle(onDevice ? Theme.leaf : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (onDevice ? Theme.leaf : Color.secondary).opacity(0.12),
                            in: Capsule()
                        )
                        .accessibilityLabel(onDevice ? "Written on-device" : "Basic built-in review")
                }
            }

            Text(subtitle)
                .font(.rounded(.caption))
                .foregroundStyle(.secondary)

            switch phase {
            case .idle:
                EmptyView()
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Writing on-device…")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            case .ready(let text, _):
                Text(text)
                    .font(.rounded(.body))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                if let onRefresh {
                    Button("Refresh", action: onRefresh)
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.saffron)
                }
            case .unavailable(let message):
                Text(message)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
    }
}
