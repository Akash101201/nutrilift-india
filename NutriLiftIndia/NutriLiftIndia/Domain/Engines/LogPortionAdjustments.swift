import Foundation

/// Quick confirm-sheet tweaks for Indian home cooking (oil/ghee tadka, restaurant portions).
enum LogPortionAdjustments {
    enum FatAddOn: String, CaseIterable, Identifiable, Hashable {
        case none
        case halfTspGhee
        case oneTspGhee
        case oneTspOil

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none: "None"
            case .halfTspGhee: "+½ tsp ghee"
            case .oneTspGhee: "+1 tsp ghee"
            case .oneTspOil: "+1 tsp oil"
            }
        }

        var emoji: String {
            switch self {
            case .none: "➖"
            case .halfTspGhee, .oneTspGhee: "🧈"
            case .oneTspOil: "🫒"
            }
        }

        /// Approximate kcal / fat for the add-on (protein and carbs stay 0).
        var delta: MacroSnapshot {
            switch self {
            case .none:
                return .zero
            case .halfTspGhee:
                return MacroSnapshot(calories: 22, proteinGrams: 0, carbGrams: 0, fatGrams: 2.5)
            case .oneTspGhee:
                return MacroSnapshot(calories: 45, proteinGrams: 0, carbGrams: 0, fatGrams: 5)
            case .oneTspOil:
                return MacroSnapshot(calories: 40, proteinGrams: 0, carbGrams: 0, fatGrams: 4.5)
            }
        }
    }

    enum PortionStyle: String, CaseIterable, Identifiable, Hashable {
        case homemade
        case restaurant

        var id: String { rawValue }

        var label: String {
            switch self {
            case .homemade: "Homemade"
            case .restaurant: "Restaurant"
            }
        }

        var emoji: String {
            switch self {
            case .homemade: "🏠"
            case .restaurant: "🏪"
            }
        }

        /// Restaurant plates are often denser / oilier than a home katori.
        var multiplier: Double {
            switch self {
            case .homemade: 1.0
            case .restaurant: 1.25
            }
        }
    }

    static func apply(
        base: MacroSnapshot,
        fatAddOn: FatAddOn = .none,
        portionStyle: PortionStyle = .homemade
    ) -> MacroSnapshot {
        (base + fatAddOn.delta).scaled(by: portionStyle.multiplier)
    }
}
