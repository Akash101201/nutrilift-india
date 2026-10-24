import Foundation
import UIKit

/// Sole photo estimator: Apple Foundation Models when available.
/// Never falls back to cloud or non-Apple ML. When the FoundationModels
/// framework is missing from the SDK, `isAvailable` is false and the UI disables photo estimate.
struct FoundationModelsPhotoNutritionEstimator: PhotoNutritionEstimating {
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            #if targetEnvironment(simulator)
            // Apple Intelligence is typically unavailable in Simulator; keep manual logging as the path.
            return false
            #else
            return FoundationModelsBridge.isAvailable
            #endif
        }
        #endif
        return false
    }

    func estimate(_ request: PhotoNutritionRequest) async throws -> PhotoNutritionEstimate {
        guard isAvailable else { throw PhotoNutritionError.unavailable }
        guard UIImage(data: request.imageJPEGData) != nil else { throw PhotoNutritionError.invalidImage }

        #if canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            return try await FoundationModelsBridge.estimate(request)
        }
        #endif
        throw PhotoNutritionError.unavailable
    }
}

#if canImport(FoundationModels)
import FoundationModels
import ImageIO

/// Isolates Apple Foundation Models APIs so the rest of the app builds on older SDKs.
/// If Apple adjusts API names in your Xcode version, update only this bridge.
@available(iOS 26.0, *)
enum FoundationModelsBridge {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    private static let instructions = """
    You estimate nutrition from a photo for a fitness diary in India.
    Identify homemade Indian meals, restaurant dishes, AND packaged drinks or foods \
    (soda cans, bottles, packets). Read visible brand and product labels when present.
    Diet sodas such as Coke Zero / Diet Coke are about 0–5 kcal per can with ~0 g protein/fat/carbs.
    Prefer household units (roti, katori, plate, glass). For cans/bottles use piece or glass.
    Values are estimates only — never invent a medical claim.
    """

    @available(iOS 27.0, *)
    static func estimate(_ request: PhotoNutritionRequest) async throws -> PhotoNutritionEstimate {
        guard let uiImage = UIImage(data: request.imageJPEGData),
              let cgImage = Self.cgImage(from: uiImage) else {
            throw PhotoNutritionError.invalidImage
        }

        let orientation = CGImagePropertyOrientation(uiImage.imageOrientation)
        let promptBits = Self.promptBits(for: request)

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(generating: PhotoFoodNutritionDraft.self) {
                promptBits
                Attachment<ImageAttachmentContent>(cgImage, orientation: orientation)
            }
            return try Self.mapDraft(response.content, nameHint: request.foodNameHint)
        } catch let error as PhotoNutritionError {
            throw error
        } catch {
            // Fallback: free-form text with the same image still attached.
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond {
                    """
                    \(promptBits)
                    Respond as JSON keys: name, quantity, servingUnit, quantityLabel, \
                    calories, proteinGrams, carbGrams, fatGrams, confidence, notes.
                    servingUnit must be one of: gram, piece, katori, plate, glass, tablespoon, cup.
                    """
                    Attachment<ImageAttachmentContent>(cgImage, orientation: orientation)
                }
                let text = String(describing: response.content)
                return try PhotoNutritionResponseParser.parse(from: text, nameHint: request.foodNameHint)
            } catch let error as PhotoNutritionError {
                throw error
            } catch {
                throw PhotoNutritionError.modelFailed(error.localizedDescription)
            }
        }
    }

    private static func promptBits(for request: PhotoNutritionRequest) -> String {
        var text = """
        Look at this photo and estimate nutrition for the food or drink shown.
        Return a clear product/meal name (e.g. "Coke Zero can", "dal tadka").
        """
        if let name = request.foodNameHint?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            text += "\nUser food name hint: \(name)"
        }
        if let qty = request.quantityHint?.trimmingCharacters(in: .whitespacesAndNewlines), !qty.isEmpty {
            text += "\nUser quantity hint: \(qty)"
        }
        return text
    }

    private static func mapDraft(
        _ draft: PhotoFoodNutritionDraft,
        nameHint: String?
    ) throws -> PhotoNutritionEstimate {
        try PhotoNutritionResponseParser.makeEstimate(
            name: draft.name,
            quantity: draft.quantity,
            servingUnitRaw: draft.servingUnit,
            quantityLabel: draft.quantityLabel,
            calories: draft.calories,
            proteinGrams: draft.proteinGrams,
            carbGrams: draft.carbGrams,
            fatGrams: draft.fatGrams,
            confidence: draft.confidence,
            notes: draft.notes,
            nameHint: nameHint
        )
    }

    private static func cgImage(from image: UIImage) -> CGImage? {
        if let cg = image.cgImage { return cg }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.cgImage
    }
}

@available(iOS 26.0, *)
@Generable
struct PhotoFoodNutritionDraft {
    @Guide(description: "Common name of the food or drink, e.g. Coke Zero, dal tadka, paneer tikka")
    var name: String

    @Guide(description: "Numeric quantity amount for the serving estimated")
    var quantity: Double

    @Guide(description: "One of: gram, piece, katori, plate, glass, tablespoon, cup")
    var servingUnit: String

    @Guide(description: "Human-readable quantity like '1 can (330 ml)' or '1 katori'")
    var quantityLabel: String

    @Guide(description: "Estimated calories for that quantity")
    var calories: Double

    @Guide(description: "Estimated protein grams")
    var proteinGrams: Double

    @Guide(description: "Estimated carbohydrate grams")
    var carbGrams: Double

    @Guide(description: "Estimated fat grams")
    var fatGrams: Double

    @Guide(description: "Confidence: low, medium, or high")
    var confidence: String

    @Guide(description: "Short note, e.g. read from label, typical can size")
    var notes: String
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
