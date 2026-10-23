import Foundation

enum DiaryTotals {
    static func totals(for entries: [FoodDiaryEntry], on day: Date = Date(), calendar: Calendar = .current) -> MacroSnapshot {
        entries
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .map(\.snapshot)
            .reduce(.zero, +)
    }

    static func remaining(targets: MacroTargets, consumed: MacroSnapshot) -> MacroTargets {
        MacroTargets(
            calories: targets.calories - consumed.calories,
            proteinGrams: targets.proteinGrams - consumed.proteinGrams,
            fatGrams: targets.fatGrams - consumed.fatGrams,
            carbGrams: targets.carbGrams - consumed.carbGrams
        )
    }

    /// Days in the last `windowDays` where protein >= target (inclusive of today going backward).
    static func proteinHitDays(
        entries: [FoodDiaryEntry],
        proteinTarget: Double,
        windowDays: Int = 7,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> (hit: Int, total: Int) {
        guard windowDays > 0 else { return (0, 0) }
        var hit = 0
        for offset in 0..<windowDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let protein = totals(for: entries, on: day, calendar: calendar).proteinGrams
            if protein >= proteinTarget { hit += 1 }
        }
        return (hit, windowDays)
    }
}
