import Foundation

/// Parses free-form / JSON model text into a diary estimate.
/// Used as a fallback when guided generation is unavailable, and for unit tests.
enum PhotoNutritionResponseParser {
    static func parse(from text: String, nameHint: String? = nil) throws -> PhotoNutritionEstimate {
        let jsonSlice: String
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            jsonSlice = String(text[start...end])
        } else {
            jsonSlice = text
        }
        guard let data = jsonSlice.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PhotoNutritionError.modelFailed("Could not parse on-device model response.")
        }
        return try makeEstimate(
            name: stringValue(obj, keys: ["name", "foodName", "title", "food", "item", "product"]),
            quantity: doubleValue(obj["quantity"]),
            servingUnitRaw: stringValue(obj, keys: ["servingUnit", "unit"]),
            quantityLabel: stringValue(obj, keys: ["quantityLabel", "serving", "servingLabel"]),
            calories: doubleValue(obj["calories"]) ?? doubleValue(obj["kcal"]),
            proteinGrams: doubleValue(obj["proteinGrams"]) ?? doubleValue(obj["protein"]),
            carbGrams: doubleValue(obj["carbGrams"]) ?? doubleValue(obj["carbs"]) ?? doubleValue(obj["carbohydrates"]),
            fatGrams: doubleValue(obj["fatGrams"]) ?? doubleValue(obj["fat"]),
            confidence: stringValue(obj, keys: ["confidence"]),
            notes: stringValue(obj, keys: ["notes", "note", "comment"]),
            nameHint: nameHint
        )
    }

    static func makeEstimate(
        name: String?,
        quantity: Double?,
        servingUnitRaw: String?,
        quantityLabel: String?,
        calories: Double?,
        proteinGrams: Double?,
        carbGrams: Double?,
        fatGrams: Double?,
        confidence: String?,
        notes: String?,
        nameHint: String? = nil
    ) throws -> PhotoNutritionEstimate {
        let trimmedHint = nameHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = [name, trimmedHint]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        guard let resolvedName else {
            throw PhotoNutritionError.modelFailed("Model did not return a food name.")
        }

        let unitRaw = (servingUnitRaw ?? "plate").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let unit = ServingUnit(rawValue: unitRaw)
            ?? ServingUnit.allCases.first { $0.displayName.lowercased() == unitRaw }
            ?? .plate
        let qty = max(0.1, quantity ?? 1)
        let label = quantityLabel.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "\(qty) \(unit.displayName)"

        return PhotoNutritionEstimate(
            name: resolvedName,
            quantity: qty,
            servingUnit: unit,
            quantityLabel: label,
            calories: max(0, calories ?? 0),
            proteinGrams: max(0, proteinGrams ?? 0),
            carbGrams: max(0, carbGrams ?? 0),
            fatGrams: max(0, fatGrams ?? 0),
            confidence: (confidence?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "low",
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            matchedFoodSeedId: nil
        )
    }

    private static func stringValue(_ obj: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let s = obj[key] as? String {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
}
