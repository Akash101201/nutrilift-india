import Foundation

/// Maps free-text food names (e.g. photo estimates) onto local `FoodItem` seed rows.
enum FoodCatalogMatcher {
    struct Match {
        var food: FoodItem
        var score: Double
    }

    /// Best local match for a display name, or nil if nothing is close enough.
    static func bestMatch(for name: String, in foods: [FoodItem], minimumScore: Double = 0.55) -> FoodItem? {
        rankedMatches(for: name, in: foods, limit: 1, minimumScore: minimumScore).first?.food
    }

    static func rankedMatches(
        for name: String,
        in foods: [FoodItem],
        limit: Int = 5,
        minimumScore: Double = 0.55
    ) -> [Match] {
        let needle = normalize(name)
        guard !needle.isEmpty else { return [] }

        var scored: [Match] = []
        scored.reserveCapacity(min(foods.count, 64))

        for food in foods {
            let score = score(needle: needle, food: food)
            if score >= minimumScore {
                scored.append(Match(food: food, score: score))
            }
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Scoring

    private static func score(needle: String, food: FoodItem) -> Double {
        let candidates = [food.name] + food.transliterations
        var best = 0.0
        for raw in candidates {
            let candidate = normalize(raw)
            guard !candidate.isEmpty else { continue }
            if candidate == needle { return 1.0 }
            if candidate.contains(needle) || needle.contains(candidate) {
                let overlap = Double(min(candidate.count, needle.count)) / Double(max(candidate.count, needle.count))
                best = max(best, 0.72 + 0.2 * overlap)
            }
            let tokenScore = tokenOverlap(needle, candidate)
            if tokenScore >= 0.5 {
                best = max(best, 0.55 + 0.35 * tokenScore)
            }
        }
        // Prefer higher-confidence catalog rows when scores are close (tie-break via tiny bump).
        if food.confidence.lowercased() == "high" { best = min(1.0, best + 0.02) }
        if food.confidence.lowercased() == "low" { best = max(0, best - 0.05) }
        return best
    }

    private static func tokenOverlap(_ a: String, _ b: String) -> Double {
        let ta = Set(a.split(separator: " ").map(String.init).filter { $0.count > 1 })
        let tb = Set(b.split(separator: " ").map(String.init).filter { $0.count > 1 })
        guard !ta.isEmpty, !tb.isEmpty else { return 0 }
        let inter = ta.intersection(tb).count
        let union = ta.union(tb).count
        return union == 0 ? 0 : Double(inter) / Double(union)
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
