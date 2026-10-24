import XCTest
@testable import NutriLiftIndia

final class FoodEmojiTests: XCTestCase {
    func testKnownFoods() {
        XCTAssertEqual(FoodEmoji.emoji(for: "Paneer Tikka"), "🧀")
        XCTAssertEqual(FoodEmoji.emoji(for: "Chicken Biryani"), "🍚")
        XCTAssertEqual(FoodEmoji.emoji(for: "Roti (phulka)"), "🫓")
        XCTAssertEqual(FoodEmoji.emoji(for: "Masala Dosa"), "🥞")
        XCTAssertEqual(FoodEmoji.emoji(for: "Moong Dal"), "🍲")
    }

    func testUnknownFoodFallsBackToPlate() {
        XCTAssertEqual(FoodEmoji.emoji(for: "Zzyzx"), "🍽️")
    }
}
