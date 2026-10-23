import Foundation
import UIKit

struct PhotoNutritionEstimate: Equatable, Sendable {
    var name: String
    var quantity: Double
    var servingUnit: ServingUnit
    var quantityLabel: String
    var calories: Double
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var confidence: String
    var notes: String
    var matchedFoodSeedId: String?

    var snapshot: MacroSnapshot {
        MacroSnapshot(
            calories: calories,
            proteinGrams: proteinGrams,
            carbGrams: carbGrams,
            fatGrams: fatGrams
        )
    }
}

struct PhotoNutritionRequest: Sendable {
    var imageJPEGData: Data
    var foodNameHint: String?
    var quantityHint: String?
}

enum PhotoNutritionError: LocalizedError, Equatable {
    case unavailable
    case invalidImage
    case modelFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "On-device photo estimates need Apple Intelligence / Foundation Models on a supported device. Manual logging still works."
        case .invalidImage:
            return "Could not read that photo. Try another image."
        case .modelFailed(let message):
            return message
        case .cancelled:
            return "Estimate cancelled."
        }
    }
}

protocol PhotoNutritionEstimating: Sendable {
    var isAvailable: Bool { get }
    func estimate(_ request: PhotoNutritionRequest) async throws -> PhotoNutritionEstimate
}

enum PhotoNutritionEstimatorFactory {
    static func make() -> any PhotoNutritionEstimating {
        FoundationModelsPhotoNutritionEstimator()
    }
}
