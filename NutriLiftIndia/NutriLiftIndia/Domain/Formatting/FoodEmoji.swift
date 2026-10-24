import Foundation

/// Picks a fitting emoji for a food from its name. Purely cosmetic.
enum FoodEmoji {
    /// Checked in order, so more specific words come first.
    private static let rules: [(keywords: [String], emoji: String)] = [
        (["biryani", "pulao", "pulav", "khichdi", "rice", "poha", "upma"], "🍚"),
        (["roti", "chapati", "chapathi", "phulka", "paratha", "naan", "kulcha", "puri", "bhakri", "thepla"], "🫓"),
        (["dosa", "uttapam", "chilla", "pancake", "cheela"], "🥞"),
        (["idli", "dhokla", "vada", "medu"], "🍘"),
        (["samosa", "momo", "kachori", "pakora", "bhajia", "bhaji"], "🥟"),
        (["dal", "sambar", "rasam", "rajma", "chole", "chana", "curry", "kadhi", "soup", "stew"], "🍲"),
        (["paneer", "cheese"], "🧀"),
        (["egg", "omelette", "omelet", "bhurji"], "🥚"),
        (["chicken", "tandoori", "tikka", "kebab", "kabab"], "🍗"),
        (["fish", "prawn", "shrimp", "salmon", "rohu", "hilsa"], "🐟"),
        (["mutton", "lamb", "keema", "beef", "pork"], "🍖"),
        (["milk", "lassi", "buttermilk", "chaas", "curd", "dahi", "yogurt", "yoghurt", "raita"], "🥛"),
        (["tea", "chai", "coffee"], "🍵"),
        (["banana"], "🍌"),
        (["apple"], "🍎"),
        (["mango"], "🥭"),
        (["orange", "mosambi", "citrus"], "🍊"),
        (["grape"], "🍇"),
        (["papaya", "guava", "pomegranate", "melon", "fruit"], "🍉"),
        (["almond", "cashew", "peanut", "walnut", "pista", "nuts", "seeds"], "🥜"),
        (["potato", "aloo"], "🥔"),
        (["tomato"], "🍅"),
        (["salad", "cucumber", "palak", "spinach", "methi", "sabzi", "veg", "gobi", "cauliflower", "bhindi", "okra", "brinjal", "baingan"], "🥗"),
        (["gulab", "jalebi", "ladoo", "laddu", "halwa", "kheer", "barfi", "sweet", "payasam", "rasgulla", "chocolate", "ice cream"], "🍮"),
        (["biscuit", "cookie", "cake", "bread", "toast"], "🍞"),
        (["oil", "ghee", "butter"], "🧈"),
    ]

    static func emoji(for name: String) -> String {
        let lower = name.lowercased()
        for rule in rules where rule.keywords.contains(where: { lower.contains($0) }) {
            return rule.emoji
        }
        return "🍽️"
    }
}
