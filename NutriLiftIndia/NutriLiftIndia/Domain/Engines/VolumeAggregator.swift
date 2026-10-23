import Foundation

struct MuscleVolume: Equatable, Identifiable, Sendable {
    var muscleGroup: MuscleGroup
    var sets: Int
    var volumeKg: Double

    var id: String { muscleGroup.rawValue }
}

enum VolumeAggregator {
    static func weeklySets(
        sessions: [WorkoutSession],
        weekOf: Date = Date(),
        calendar: Calendar = .current
    ) -> [MuscleVolume] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: weekOf)?.start ?? weekOf
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekOf

        var setCounts: [MuscleGroup: Int] = [:]
        var volumes: [MuscleGroup: Double] = [:]

        for session in sessions where session.isFinished {
            let date = session.finishedAt ?? session.startedAt
            guard date >= weekStart && date < weekEnd else { continue }
            for set in session.sets {
                setCounts[set.muscleGroup, default: 0] += 1
                volumes[set.muscleGroup, default: 0] += set.volume
            }
        }

        return MuscleGroup.allCases.compactMap { group in
            let sets = setCounts[group] ?? 0
            guard sets > 0 else { return nil }
            return MuscleVolume(muscleGroup: group, sets: sets, volumeKg: volumes[group] ?? 0)
        }
        .sorted { $0.sets > $1.sets }
    }

    static func averageWeeklySets(
        sessions: [WorkoutSession],
        weeks: Int,
        endingAt: Date = Date(),
        calendar: Calendar = .current
    ) -> [MuscleGroup: Double] {
        guard weeks > 0 else { return [:] }
        var totals: [MuscleGroup: Double] = [:]
        for offset in 0..<weeks {
            guard let weekDate = calendar.date(byAdding: .weekOfYear, value: -offset, to: endingAt) else { continue }
            for item in weeklySets(sessions: sessions, weekOf: weekDate, calendar: calendar) {
                totals[item.muscleGroup, default: 0] += Double(item.sets)
            }
        }
        return totals.mapValues { $0 / Double(weeks) }
    }
}
