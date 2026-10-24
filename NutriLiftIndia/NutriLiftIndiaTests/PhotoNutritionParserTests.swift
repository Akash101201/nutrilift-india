import XCTest
@testable import NutriLiftIndia

final class PhotoNutritionParserTests: XCTestCase {
    func testParsesStandardJSON() throws {
        let text = """
        {"name":"Coke Zero","quantity":1,"servingUnit":"piece","quantityLabel":"1 can (330 ml)",
         "calories":1,"proteinGrams":0,"carbGrams":0,"fatGrams":0,"confidence":"high","notes":"diet soda"}
        """
        let estimate = try PhotoNutritionResponseParser.parse(from: text)
        XCTAssertEqual(estimate.name, "Coke Zero")
        XCTAssertEqual(estimate.servingUnit, .piece)
        XCTAssertEqual(estimate.calories, 1, accuracy: 0.01)
        XCTAssertEqual(estimate.confidence, "high")
    }

    func testAcceptsAlternateKeys() throws {
        let text = """
        Some preamble {"foodName":"Thums Up","unit":"glass","kcal":139,"protein":0,"carbs":35,"fat":0} trailing
        """
        let estimate = try PhotoNutritionResponseParser.parse(from: text)
        XCTAssertEqual(estimate.name, "Thums Up")
        XCTAssertEqual(estimate.servingUnit, .glass)
        XCTAssertEqual(estimate.calories, 139, accuracy: 0.01)
        XCTAssertEqual(estimate.carbGrams, 35, accuracy: 0.01)
    }

    func testUsesNameHintWhenModelOmitsName() throws {
        let text = #"{"quantity":1,"servingUnit":"piece","calories":1,"proteinGrams":0,"carbGrams":0,"fatGrams":0}"#
        let estimate = try PhotoNutritionResponseParser.parse(from: text, nameHint: "Coke Zero")
        XCTAssertEqual(estimate.name, "Coke Zero")
    }

    func testThrowsWhenNameAndHintMissing() {
        let text = #"{"calories":100,"proteinGrams":1,"carbGrams":10,"fatGrams":1}"#
        XCTAssertThrowsError(try PhotoNutritionResponseParser.parse(from: text)) { error in
            guard let photoError = error as? PhotoNutritionError,
                  case .modelFailed(let message) = photoError else {
                return XCTFail("Expected PhotoNutritionError.modelFailed")
            }
            XCTAssertTrue(message.lowercased().contains("food name"))
        }
    }
}
