import Foundation

/// Bundled Indian packaged products (whey, bars, protein drinks) keyed by barcode.
enum BarcodeCatalog {
    private static let cache: [String: BarcodeProduct] = {
        guard let url = Bundle.main.url(forResource: "barcode_products", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([BarcodeProductDTO].self, from: data) else {
            return [:]
        }
        var map: [String: BarcodeProduct] = [:]
        for row in rows {
            let product = row.asProduct(origin: .local)
            map[normalize(product.barcode)] = product
        }
        return map
    }()

    static var all: [BarcodeProduct] {
        cache.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    static func lookup(_ rawBarcode: String) -> BarcodeProduct? {
        cache[normalize(rawBarcode)]
    }

    static func normalize(_ barcode: String) -> String {
        barcode.filter(\.isNumber)
    }
}
