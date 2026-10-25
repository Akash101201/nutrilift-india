import XCTest
@testable import NutriLiftIndia

final class BarcodeCatalogTests: XCTestCase {
    func testNormalizeStripsNonDigits() {
        XCTAssertEqual(BarcodeCatalog.normalize("8906-1169-58995"), "8906116958995")
        XCTAssertEqual(BarcodeCatalog.normalize(" 8906009532363 "), "8906009532363")
    }

    func testDTOMapsServingUnit() throws {
        let dto = BarcodeProductDTO(
            barcode: "8906009532363",
            brand: "RiteBite",
            name: "Max Protein Bar",
            category: "protein_bar",
            servingUnit: "piece",
            servingAmount: 1,
            gramsPerServing: 50,
            calories: 173,
            proteinG: 10,
            carbG: 27.8,
            fatG: 5.8,
            source: "label-OFF"
        )
        let product = dto.asProduct(origin: .local)
        XCTAssertEqual(product.servingUnit, .piece)
        XCTAssertEqual(product.foodSeedId, "barcode_8906009532363")
        XCTAssertEqual(product.displayName, "RiteBite Max Protein Bar")
        XCTAssertEqual(product.perServingSnapshot.proteinGrams, 10, accuracy: 0.01)
    }
}
