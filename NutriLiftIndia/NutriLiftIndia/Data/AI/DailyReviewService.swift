import Foundation
import SwiftData

/// Generates and caches end-of-day recaps / next-day tips via Apple Foundation Models (grounded).
enum DailyReviewService {
    @MainActor
    static func record(
        for day: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) -> DailyReviewRecord {
        let key = DailyReview.dayKey(day, calendar: calendar)
        var descriptor = FetchDescriptor<DailyReviewRecord>(
            predicate: #Predicate { $0.dayKey == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = DailyReviewRecord(
            dayKey: key,
            dayStart: calendar.startOfDay(for: day)
        )
        context.insert(created)
        try? context.save()
        return created
    }

    /// End-of-day review for `snapshot`'s day. Uses cache when present unless `force`.
    @MainActor
    static func ensureRecap(
        snapshot: DaySnapshot,
        context: ModelContext,
        force: Bool = false
    ) async -> (text: String, onDevice: Bool) {
        let record = record(for: snapshot.dayStart, context: context)
        if !force, let saved = record.recapText, !saved.isEmpty {
            return (saved, record.recapOnDevice)
        }

        let facts = DailyReview.facts(snapshot)
        if OnDeviceWriter.isAvailable {
            do {
                let text = try await OnDeviceWriter.write(
                    instructions: DailyReview.recapInstructions,
                    prompt: DailyReview.recapPrompt(snapshot),
                    facts: facts
                )
                record.recapText = text
                record.recapOnDevice = true
                record.updatedAt = Date()
                try? context.save()
                return (text, true)
            } catch {
                // Fall through to built-in text.
            }
        }

        let fallback = DailyReview.recapFallback(snapshot)
        record.recapText = fallback
        record.recapOnDevice = false
        record.updatedAt = Date()
        try? context.save()
        return (fallback, false)
    }

    /// Tips for *today*, generated from yesterday's snapshot. Cached on yesterday's record.
    @MainActor
    static func ensureTips(
        yesterday: DaySnapshot,
        context: ModelContext,
        force: Bool = false
    ) async -> (text: String, onDevice: Bool) {
        let record = record(for: yesterday.dayStart, context: context)
        if !force, let saved = record.tipsText, !saved.isEmpty {
            return (saved, record.tipsOnDevice)
        }

        let facts = DailyReview.facts(yesterday)
        if OnDeviceWriter.isAvailable {
            do {
                let text = try await OnDeviceWriter.write(
                    instructions: DailyReview.tipsInstructions,
                    prompt: DailyReview.tipsPrompt(yesterday),
                    facts: facts
                )
                record.tipsText = text
                record.tipsOnDevice = true
                record.updatedAt = Date()
                try? context.save()
                return (text, true)
            } catch {
                // Fall through.
            }
        }

        let fallback = DailyReview.tipsFallback(yesterday)
        record.tipsText = fallback
        record.tipsOnDevice = false
        record.updatedAt = Date()
        try? context.save()
        return (fallback, false)
    }
}
