import Foundation

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case female
    case male
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .other: "Other"
        }
    }

    var emoji: String {
        switch self {
        case .female: "♀️"
        case .male: "♂️"
        case .other: "🌈"
        }
    }

    /// Lowest daily calorie target the engine will set automatically.
    /// Conventional general-population minimums; not medical advice.
    var calorieFloor: Double {
        switch self {
        case .female: 1200
        case .male: 1500
        case .other: 1350
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String { rawValue }

    /// TDEE multiplier. The upper levels are deliberately a little lower than the
    /// classic Harris-Benedict factors (1.55 / 1.725 / 1.9) because people tend to
    /// over-report exercise. This is a judgment call, not a sourced constant.
    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.5
        case .active: 1.65
        case .veryActive: 1.8
        }
    }

    var emoji: String {
        switch self {
        case .sedentary: "🛋️"
        case .light: "🚶"
        case .moderate: "🏃"
        case .active: "🏋️"
        case .veryActive: "🔥"
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Lightly active"
        case .moderate: "Moderately active"
        case .active: "Active"
        case .veryActive: "Very active"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: "Mostly sitting. Desk job, little exercise"
        case .light: "Light walks or a workout 1–2 days a week"
        case .moderate: "Workouts about 3–4 days a week"
        case .active: "Hard training 5–6 days a week"
        case .veryActive: "Physical job plus daily training"
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case lose
    case maintain
    case gain

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lose: "Lose weight"
        case .maintain: "Maintain"
        case .gain: "Gain weight"
        }
    }

    var emoji: String {
        switch self {
        case .lose: "📉"
        case .maintain: "⚖️"
        case .gain: "💪"
        }
    }

    /// Short, friendly one-liner for the goal cards.
    var tagline: String {
        switch self {
        case .lose: "Shed fat steadily"
        case .maintain: "Stay where I am"
        case .gain: "Build size and strength"
        }
    }

    /// Whether the user chooses a pace for this goal.
    var usesPace: Bool { self != .maintain }
}

/// How quickly to move toward the goal, as a share of daily energy expenditure.
enum Pace: String, Codable, CaseIterable, Identifiable {
    case gentle
    case steady
    case ambitious

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentle: "Gentle"
        case .steady: "Steady"
        case .ambitious: "Ambitious"
        }
    }

    var emoji: String {
        switch self {
        case .gentle: "🐢"
        case .steady: "🚶"
        case .ambitious: "🐇"
        }
    }

    /// Fraction of TDEE to remove (lose) or add (gain). Zero for maintain.
    func fraction(for goal: FitnessGoal) -> Double {
        switch (goal, self) {
        case (.maintain, _): 0
        case (.lose, .gentle): 0.10
        case (.lose, .steady): 0.15
        case (.lose, .ambitious): 0.20
        case (.gain, .gentle): 0.05
        case (.gain, .steady): 0.10
        case (.gain, .ambitious): 0.15
        }
    }

    func blurb(for goal: FitnessGoal) -> String {
        switch (goal, self) {
        case (.maintain, _): "Eat to stay put"
        case (.lose, .gentle): "Easiest to stick with"
        case (.lose, .steady): "A good balance"
        case (.lose, .ambitious): "Faster, but harder"
        case (.gain, .gentle): "Lean gains, minimal fat"
        case (.gain, .steady): "A solid, steady build"
        case (.gain, .ambitious): "Fastest, some fat gain"
        }
    }
}

enum DietPreference: String, Codable, CaseIterable, Identifiable {
    case veg
    case eggetarian
    case nonVeg
    case jain
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .veg: "Vegetarian"
        case .eggetarian: "Eggetarian"
        case .nonVeg: "Non-vegetarian"
        case .jain: "Jain"
        case .custom: "Custom"
        }
    }

    var emoji: String {
        switch self {
        case .veg: "🥦"
        case .eggetarian: "🥚"
        case .nonVeg: "🍗"
        case .jain: "🙏"
        case .custom: "✏️"
        }
    }

    var blurb: String {
        switch self {
        case .veg: "No meat, fish or eggs"
        case .eggetarian: "Veg plus eggs"
        case .nonVeg: "I eat everything"
        case .jain: "No root vegetables"
        case .custom: "I'll mix it up"
        }
    }

    /// Plant proteins are somewhat less digestible and lower in lysine/leucine, so
    /// vegetarian diets get a small bump. Judgment call, within published ranges.
    var proteinMultiplier: Double {
        switch self {
        case .veg, .jain: 1.10
        case .eggetarian: 1.05
        case .nonVeg, .custom: 1.0
        }
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case snacks
    case dinner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .snacks: "Snacks"
        case .dinner: "Dinner"
        }
    }

    var emoji: String {
        switch self {
        case .breakfast: "🍳"
        case .lunch: "🍛"
        case .snacks: "🍪"
        case .dinner: "🍽️"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .snacks: 2
        case .dinner: 3
        }
    }
}

enum ServingUnit: String, Codable, CaseIterable, Identifiable {
    case gram
    case piece
    case katori
    case plate
    case glass
    case tablespoon
    case cup

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gram: "g"
        case .piece: "piece"
        case .katori: "katori"
        case .plate: "plate"
        case .glass: "glass"
        case .tablespoon: "tbsp"
        case .cup: "cup"
        }
    }

    var emoji: String {
        switch self {
        case .gram: "⚖️"
        case .piece: "🧩"
        case .katori: "🥣"
        case .plate: "🍽️"
        case .glass: "🥛"
        case .tablespoon: "🥄"
        case .cup: "☕️"
        }
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case legs
    case glutes
    case core
    case fullBody
    case cardio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .legs: "Legs"
        case .glutes: "Glutes"
        case .core: "Core"
        case .fullBody: "Full body"
        case .cardio: "Cardio"
        }
    }

    var emoji: String {
        switch self {
        case .chest: "🛡️"
        case .back: "🧗"
        case .shoulders: "🏔️"
        case .biceps: "💪"
        case .triceps: "🦾"
        case .legs: "🦵"
        case .glutes: "🍑"
        case .core: "🎯"
        case .fullBody: "🧍"
        case .cardio: "🏃"
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case bodyweight
    case dumbbell
    case barbell
    case machine
    case cable
    case kettlebell
    case band
    case other

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var emoji: String {
        switch self {
        case .bodyweight: "🤸"
        case .dumbbell: "🏋️"
        case .barbell: "🏋️‍♂️"
        case .machine: "⚙️"
        case .cable: "🔗"
        case .kettlebell: "🔔"
        case .band: "🎗️"
        case .other: "✨"
        }
    }
}

enum DiaryEntrySource: String, Codable {
    case manual
    case photoEstimate
}

enum WeightChartRange: String, CaseIterable, Identifiable {
    case days7 = "7D"
    case weeks4 = "4W"
    case months3 = "3M"
    case months6 = "6M"
    case year1 = "1Y"

    var id: String { rawValue }

    var startDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .days7: return cal.date(byAdding: .day, value: -7, to: now) ?? now
        case .weeks4: return cal.date(byAdding: .day, value: -28, to: now) ?? now
        case .months3: return cal.date(byAdding: .month, value: -3, to: now) ?? now
        case .months6: return cal.date(byAdding: .month, value: -6, to: now) ?? now
        case .year1: return cal.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }
}
