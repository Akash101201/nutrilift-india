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
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
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
        case .sedentary: "Desk work, little exercise"
        case .light: "Walks or light exercise 1–3 days/week"
        case .moderate: "Exercise 3–5 days/week"
        case .active: "Hard exercise 6–7 days/week"
        case .veryActive: "Physical job or two-a-days"
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

    /// Protein grams per kg body weight.
    var proteinGramsPerKg: Double {
        switch self {
        case .lose: 2.0
        case .maintain: 1.6
        case .gain: 1.8
        }
    }

    /// Calorie adjustment from TDEE.
    var calorieDelta: Double {
        switch self {
        case .lose: -500
        case .maintain: 0
        case .gain: 300
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
