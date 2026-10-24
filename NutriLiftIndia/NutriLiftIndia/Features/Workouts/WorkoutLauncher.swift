import SwiftUI
import SwiftData

/// Starts, resumes and presents the full-screen workout from anywhere in the app.
/// Only one workout can be in progress at a time.
@MainActor
final class WorkoutLauncher: ObservableObject {
    struct Route: Identifiable, Equatable {
        /// The workout session's id.
        let id: UUID
    }

    enum PendingStart {
        case empty
        case template(WorkoutTemplate)
        case repeating(WorkoutSession)
    }

    @Published var route: Route?
    /// Set when the user tries to start a workout while another is in progress.
    @Published var pendingStart: PendingStart?

    func startEmpty(context: ModelContext) {
        request(.empty, context: context)
    }

    func start(_ template: WorkoutTemplate, context: ModelContext) {
        request(.template(template), context: context)
    }

    func repeatWorkout(_ session: WorkoutSession, context: ModelContext) {
        request(.repeating(session), context: context)
    }

    func resumeActive(context: ModelContext) {
        if let active = WorkoutService.activeSession(in: context) {
            route = Route(id: active.id)
        }
        pendingStart = nil
    }

    func discardActiveAndStart(_ pending: PendingStart, context: ModelContext) {
        if let active = WorkoutService.activeSession(in: context) {
            WorkoutService.discard(session: active, context: context)
        }
        begin(pending, context: context)
    }

    func dismiss() {
        route = nil
    }

    private func request(_ start: PendingStart, context: ModelContext) {
        if WorkoutService.activeSession(in: context) != nil {
            pendingStart = start
        } else {
            begin(start, context: context)
        }
    }

    private func begin(_ start: PendingStart, context: ModelContext) {
        let session: WorkoutSession
        switch start {
        case .empty: session = WorkoutService.startEmpty(context: context)
        case .template(let template): session = WorkoutService.start(template: template, context: context)
        case .repeating(let old): session = WorkoutService.startRepeating(old, context: context)
        }
        pendingStart = nil
        route = Route(id: session.id)
    }
}

/// Decides what the full-screen workout shows: the live workout, or the summary once it's finished.
struct WorkoutFlowView: View {
    let sessionID: UUID
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [WorkoutSession]

    private var session: WorkoutSession? {
        sessions.first { $0.id == sessionID }
    }

    var body: some View {
        if let session {
            if session.isFinished {
                WorkoutSummaryView(session: session)
            } else {
                ActiveWorkoutView(session: session)
            }
        } else {
            // The workout was discarded.
            Color.clear.task {
                await Task.yield()
                dismiss()
            }
        }
    }
}
