import Foundation

/// Guards on-device model text: it may only quote numbers that appear in the facts we gave it.
enum Grounding {
    /// Numbers as written in `text`: "1,682" -> 1682, "1.65" -> 1.65.
    static func numbers(in text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: #"\d+(?:,\d{3})*(?:\.\d+)?"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return Double(text[r].replacingOccurrences(of: ",", with: ""))
        }
    }

    /// True when every number in `text` also appears in `facts` (or is a tiny count like 1-3).
    static func isGrounded(_ text: String, facts: [String]) -> Bool {
        var allowed: [Double] = [0, 1, 2, 3]
        for line in facts { allowed.append(contentsOf: numbers(in: line)) }
        for value in numbers(in: text) {
            guard allowed.contains(where: { abs($0 - value) < 0.06 }) else { return false }
        }
        return true
    }

    /// Cleans a model answer and returns it only if it is a sensible length and grounded.
    static func validated(_ text: String, facts: [String], minLength: Int = 40, maxLength: Int = 1500) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minLength, trimmed.count <= maxLength else { return nil }
        guard isGrounded(trimmed, facts: facts) else { return nil }
        return trimmed
    }
}
