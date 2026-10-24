import Foundation

/// Picks the next day in a leveled training plan from the last finished template.
enum PlanScheduler {
    struct PlanDayRef: Equatable, Sendable {
        var name: String
        var templateSeedId: String
    }

    struct NextDay: Equatable, Sendable {
        var dayIndex: Int
        var name: String
        var templateSeedId: String
    }

    /// Advances one day after the last finished plan template. If the last session
    /// wasn't from this plan (or there is no history), returns day 0.
    static func nextDay(
        days: [PlanDayRef],
        lastFinishedTemplateSeedId: String?
    ) -> NextDay? {
        guard !days.isEmpty else { return nil }
        guard let last = lastFinishedTemplateSeedId,
              let idx = days.lastIndex(where: { $0.templateSeedId == last }) else {
            let first = days[0]
            return NextDay(dayIndex: 0, name: first.name, templateSeedId: first.templateSeedId)
        }
        let nextIndex = (idx + 1) % days.count
        let day = days[nextIndex]
        return NextDay(dayIndex: nextIndex, name: day.name, templateSeedId: day.templateSeedId)
    }

    static func dayRefs(from plan: TrainingPlan) -> [PlanDayRef] {
        plan.orderedDays.map { PlanDayRef(name: $0.name, templateSeedId: $0.templateSeedId) }
    }
}
