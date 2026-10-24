import XCTest
@testable import NutriLiftIndia

final class FoodTabEnhancementTests: XCTestCase {
    func testDietFilterHidesChickenForVeg() {
        XCTAssertFalse(FoodDietFilter.isAllowed(
            name: "Chicken curry",
            searchBlob: "chicken curry",
            diet: .veg
        ))
        XCTAssertTrue(FoodDietFilter.isAllowed(
            name: "Dal tadka",
            searchBlob: "dal tadka",
            diet: .veg
        ))
        XCTAssertTrue(FoodDietFilter.isAllowed(
            name: "Baingan bharta",
            searchBlob: "baingan bharta eggplant",
            diet: .veg
        ))
    }

    func testDietFilterAllowsEggsForEggetarian() {
        XCTAssertTrue(FoodDietFilter.isAllowed(
            name: "Egg bhurji",
            searchBlob: "egg bhurji anda",
            diet: .eggetarian
        ))
        XCTAssertFalse(FoodDietFilter.isAllowed(
            name: "Chicken curry",
            searchBlob: "chicken curry",
            diet: .eggetarian
        ))
    }

    func testDietFilterJainRejectsPotato() {
        XCTAssertFalse(FoodDietFilter.isAllowed(
            name: "Aloo sabzi",
            searchBlob: "aloo sabzi potato",
            diet: .jain
        ))
        XCTAssertTrue(FoodDietFilter.isAllowed(
            name: "Dal tadka",
            searchBlob: "dal tadka",
            diet: .jain
        ))
    }

    func testLogPortionGheeAddsFat() {
        let base = MacroSnapshot(calories: 200, proteinGrams: 10, carbGrams: 20, fatGrams: 8)
        let withGhee = LogPortionAdjustments.apply(base: base, fatAddOn: .oneTspGhee)
        XCTAssertEqual(withGhee.calories, 245, accuracy: 0.1)
        XCTAssertEqual(withGhee.fatGrams, 13, accuracy: 0.1)
        XCTAssertEqual(withGhee.proteinGrams, 10, accuracy: 0.1)
    }

    func testRestaurantMultiplier() {
        let base = MacroSnapshot(calories: 200, proteinGrams: 10, carbGrams: 20, fatGrams: 8)
        let restaurant = LogPortionAdjustments.apply(base: base, portionStyle: .restaurant)
        XCTAssertEqual(restaurant.calories, 250, accuracy: 0.1)
        XCTAssertEqual(restaurant.proteinGrams, 12.5, accuracy: 0.1)
    }

    func testCatalogMatcherExactAndFuzzy() {
        let roti = FoodItem(
            seedId: "roti_whole_wheat",
            name: "Roti (whole wheat)",
            transliterations: ["chapati", "phulka"],
            servingUnit: .piece,
            servingAmount: 1,
            gramsPerServing: 40,
            calories: 120,
            proteinG: 3.5,
            carbG: 18,
            fatG: 3.5,
            sourceTag: "IFCT-inspired",
            confidence: "medium"
        )
        let dal = FoodItem(
            seedId: "dal_tadka",
            name: "Dal tadka",
            servingUnit: .katori,
            servingAmount: 1,
            gramsPerServing: 150,
            calories: 180,
            proteinG: 10,
            carbG: 22,
            fatG: 6,
            sourceTag: "estimated",
            confidence: "medium"
        )
        let foods = [roti, dal]
        XCTAssertEqual(FoodCatalogMatcher.bestMatch(for: "chapati", in: foods)?.seedId, "roti_whole_wheat")
        XCTAssertEqual(FoodCatalogMatcher.bestMatch(for: "Dal Tadka", in: foods)?.seedId, "dal_tadka")
        XCTAssertNil(FoodCatalogMatcher.bestMatch(for: "zzzz unrelated", in: foods, minimumScore: 0.55))
    }
}
