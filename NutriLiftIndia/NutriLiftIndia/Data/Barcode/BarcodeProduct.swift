import Foundation

struct BarcodeProduct: Equatable, Sendable, Identifiable {
    var barcode: String
    var brand: String
    var name: String
    var category: String
    var servingUnit: ServingUnit
    var servingAmount: Double
    var gramsPerServing: Double
    var calories: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double
    var source: String
    /// local catalog, Open Food Facts network, or user-entered.
    var lookupOrigin: LookupOrigin

    enum LookupOrigin: String, Equatable, Sendable {
        case local
        case openFoodFacts
        case manual
    }

    var id: String { barcode }

    var displayName: String {
        if brand.isEmpty { return name }
        return "\(brand) \(name)"
    }

    var perServingSnapshot: MacroSnapshot {
        MacroSnapshot(
            calories: calories,
            proteinGrams: proteinG,
            carbGrams: carbG,
            fatGrams: fatG
        )
    }

    var foodSeedId: String { "barcode_\(barcode)" }
}

struct BarcodeProductDTO: Codable, Sendable {
    var barcode: String
    var brand: String
    var name: String
    var category: String
    var servingUnit: String
    var servingAmount: Double
    var gramsPerServing: Double
    var calories: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double
    var source: String

    func asProduct(origin: BarcodeProduct.LookupOrigin = .local) -> BarcodeProduct {
        BarcodeProduct(
            barcode: barcode.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand,
            name: name,
            category: category,
            servingUnit: ServingUnit(rawValue: servingUnit) ?? .piece,
            servingAmount: servingAmount,
            gramsPerServing: gramsPerServing,
            calories: calories,
            proteinG: proteinG,
            carbG: carbG,
            fatG: fatG,
            source: source,
            lookupOrigin: origin
        )
    }
}
