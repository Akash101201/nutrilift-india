import Foundation

/// Keyword-based diet compatibility for the Indian food catalog (no diet tags in seed JSON).
enum FoodDietFilter {
    private static let nonVegTokens = [
        "chicken", "mutton", "lamb", "goat", "beef", "pork", "fish", "prawn", "shrimp",
        "crab", "meat", "keema", "kebab", "tikka", "seekh", "rogan josh", "nihari",
        "biryani (chicken", "chicken curry", "fish curry", "egg curry", "omelette",
        "omelet", "bhurji (egg", "egg bhurji", "boiled egg", "scrambled egg", "egg white",
        "bacon", "ham", "sausage", "tuna", "salmon",
    ]

    private static let eggTokens = [
        "egg", "omelette", "omelet", "bhurji", "anda",
    ]

    private static let jainRootTokens = [
        "onion", "garlic", "potato", "aloo", "ginger", "carrot", "beet", "radish",
        "mooli", "yam", "arbi", "suran", "shalot", "leek",
    ]

    /// Returns true when the food is acceptable for the user's diet preference.
    static func isAllowed(_ food: FoodItem, for diet: DietPreference) -> Bool {
        isAllowed(name: food.name, searchBlob: food.searchBlob, diet: diet)
    }

    static func isAllowed(name: String, searchBlob: String, diet: DietPreference) -> Bool {
        switch diet {
        case .nonVeg, .custom:
            return true
        case .veg:
            return !containsAny(searchBlob, of: nonVegTokens) && !isClearlyEggDish(name: name, blob: searchBlob)
        case .eggetarian:
            let meatTokens = nonVegTokens.filter { !$0.contains("egg") && !eggTokens.contains($0) }
            return !containsAny(searchBlob, of: meatTokens)
        case .jain:
            if containsAny(searchBlob, of: nonVegTokens) { return false }
            if isClearlyEggDish(name: name, blob: searchBlob) { return false }
            return !containsAny(searchBlob, of: jainRootTokens)
        }
    }

    /// Filters a list; when `showAll` is true, returns the input unchanged.
    static func filter(_ foods: [FoodItem], diet: DietPreference, showAll: Bool) -> [FoodItem] {
        if showAll || diet == .nonVeg || diet == .custom { return foods }
        return foods.filter { isAllowed($0, for: diet) }
    }

    private static func isClearlyEggDish(name: String, blob: String) -> Bool {
        let n = name.lowercased()
        // Avoid "egg" substring hits inside eggplant / baingan / brinjal.
        if n.contains("eggplant") || n.contains("baingan") || n.contains("brinjal") { return false }
        let blobWithoutPlant = blob
            .lowercased()
            .replacingOccurrences(of: "eggplant", with: "")
            .replacingOccurrences(of: "baingan", with: "")
            .replacingOccurrences(of: "brinjal", with: "")
        return containsAny(blobWithoutPlant, of: eggTokens) && (
            n.contains("egg") || n.contains("anda") || n.contains("omelet") || n.contains("omelette")
            || (n.contains("bhurji") && !n.contains("paneer"))
        )
    }

    private static func containsAny(_ blob: String, of tokens: [String]) -> Bool {
        let lower = blob.lowercased()
        return tokens.contains { lower.contains($0) }
    }
}
