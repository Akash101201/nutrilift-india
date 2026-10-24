import Foundation

/// Streaks and daily water totals for the Today screen.
enum HabitStats {
    /// Consecutive logged days ending today. If nothing is logged yet today, the streak
    /// still counts through yesterday, so it only breaks once a whole day is missed.
    static func currentStreak(loggedDates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(loggedDates.map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func loggedToday(loggedDates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        loggedDates.contains { calendar.isDate($0, inSameDayAs: now) }
    }

    static func waterTotalMl(entries: [WaterLogEntry], on day: Date = Date(), calendar: Calendar = .current) -> Double {
        entries
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.amountMl }
    }
}
