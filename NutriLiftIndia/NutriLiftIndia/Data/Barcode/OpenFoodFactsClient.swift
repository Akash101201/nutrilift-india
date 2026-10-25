import Foundation

/// Optional online lookup via Open Food Facts (user-initiated). Not a NutriLift server.
enum OpenFoodFactsClient {
    enum LookupError: LocalizedError {
        case badBarcode
        case notFound
        case network(String)
        case incompleteNutrition

        var errorDescription: String? {
            switch self {
            case .badBarcode: "That barcode doesn’t look valid."
            case .notFound: "No product found online for this barcode."
            case .network(let message): message
            case .incompleteNutrition: "Found the product, but calories/macros were missing. Add it as a custom food."
            }
        }
    }

    /// Fetches product nutrition. Prefer India OFF, then world.
    static func lookup(barcode: String) async throws -> BarcodeProduct {
        let code = BarcodeCatalog.normalize(barcode)
        guard code.count >= 8 else { throw LookupError.badBarcode }

        let hosts = ["https://in.openfoodfacts.org", "https://world.openfoodfacts.org"]
        var lastError: Error = LookupError.notFound
        for host in hosts {
            do {
                return try await fetch(host: host, code: code)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func fetch(host: String, code: String) async throws -> BarcodeProduct {
        guard let url = URL(string: "\(host)/api/v2/product/\(code).json?fields=code,product_name,brands,serving_size,serving_quantity,nutriments") else {
            throw LookupError.badBarcode
        }
        var request = URLRequest(url: url)
        request.setValue("NutriLiftIndia/1.0 (privacy-first fitness app; barcode lookup)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LookupError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LookupError.network("Open Food Facts returned an error.")
        }

        let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
        guard decoded.status == 1, let product = decoded.product else {
            throw LookupError.notFound
        }
        return try map(product, code: code)
    }

    private static func map(_ product: OFFProduct, code: String) throws -> BarcodeProduct {
        let n = product.nutriments ?? OFFNutriments()
        let brand = (product.brands ?? "").split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = (product.productName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty || !brand.isEmpty else { throw LookupError.notFound }

        // Prefer per-serving; else scale 100 g to a sensible scoop/bar.
        let servingGrams = parseGrams(product.servingSize) ?? product.servingQuantity ?? defaultServingGrams(for: name)
        let useServing = n.energyKcalServing != nil || n.proteinsServing != nil

        let calories: Double
        let protein: Double
        let carb: Double
        let fat: Double
        let grams: Double
        let unit: ServingUnit
        let amount: Double

        if useServing, let kcal = n.energyKcalServing {
            calories = kcal
            protein = n.proteinsServing ?? 0
            carb = n.carbohydratesServing ?? 0
            fat = n.fatServing ?? 0
            grams = servingGrams
            if grams >= 150 { unit = .glass; amount = 1 }
            else if looksLikeBar(name) { unit = .piece; amount = 1 }
            else { unit = .gram; amount = grams }
        } else if let kcal100 = n.energyKcal100g {
            let scale = servingGrams / 100.0
            calories = kcal100 * scale
            protein = (n.proteins100g ?? 0) * scale
            carb = (n.carbohydrates100g ?? 0) * scale
            fat = (n.fat100g ?? 0) * scale
            grams = servingGrams
            unit = looksLikeBar(name) ? .piece : .gram
            amount = unit == .piece ? 1 : grams
        } else {
            throw LookupError.incompleteNutrition
        }

        guard calories > 0 || protein > 0 else { throw LookupError.incompleteNutrition }

        return BarcodeProduct(
            barcode: code,
            brand: brand,
            name: name.isEmpty ? "Packaged food" : name,
            category: "packaged",
            servingUnit: unit,
            servingAmount: amount,
            gramsPerServing: grams,
            calories: calories,
            proteinG: protein,
            carbG: carb,
            fatG: fat,
            source: "openfoodfacts",
            lookupOrigin: .openFoodFacts
        )
    }

    private static func looksLikeBar(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("bar") || n.contains("cookie") || n.contains("biscuit")
    }

    private static func defaultServingGrams(for name: String) -> Double {
        let n = name.lowercased()
        if n.contains("whey") || n.contains("protein powder") || n.contains("isolate") { return 33 }
        if looksLikeBar(name) { return 50 }
        if n.contains("lassi") || n.contains("shake") || n.contains("buttermilk") { return 200 }
        return 100
    }

    private static func parseGrams(_ servingSize: String?) -> Double? {
        guard let servingSize else { return nil }
        // "1 scoop (36 g)", "50 g", "200 ml"
        if let match = servingSize.range(of: #"(\d+(?:\.\d+)?)\s*(g|ml)"#, options: [.regularExpression, .caseInsensitive]) {
            let token = String(servingSize[match])
            let number = token.filter { $0.isNumber || $0 == "." }
            return Double(number)
        }
        return nil
    }
}

// MARK: - OFF JSON

private struct OFFResponse: Decodable {
    var status: Int
    var product: OFFProduct?
}

private struct OFFProduct: Decodable {
    var productName: String?
    var brands: String?
    var servingSize: String?
    var servingQuantity: Double?
    var nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case nutriments
    }
}

private struct OFFNutriments: Decodable {
    var energyKcalServing: Double?
    var proteinsServing: Double?
    var carbohydratesServing: Double?
    var fatServing: Double?
    var energyKcal100g: Double?
    var proteins100g: Double?
    var carbohydrates100g: Double?
    var fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcalServing = "energy-kcal_serving"
        case proteinsServing = "proteins_serving"
        case carbohydratesServing = "carbohydrates_serving"
        case fatServing = "fat_serving"
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}
