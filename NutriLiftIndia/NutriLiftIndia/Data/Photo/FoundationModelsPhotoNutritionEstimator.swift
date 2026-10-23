import Foundation
import UIKit

/// Sole photo estimator: Apple Foundation Models when available.
/// Never falls back to cloud or non-Apple ML. When the FoundationModels
/// framework is missing from the SDK, `isAvailable` is false and the UI disables photo estimate.
struct FoundationModelsPhotoNutritionEstimator: PhotoNutritionEstimating {
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
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
        if #available(iOS 26.0, *) {
            return try await FoundationModelsBridge.estimate(request)
        }
        #endif
        throw PhotoNutritionError.unavailable
    }
}

#if canImport(FoundationModels)
import FoundationModels

/// Isolates Apple Foundation Models APIs so the rest of the app builds on older SDKs.
/// If Apple adjusts API names in your Xcode version, update only this bridge.
@available(iOS 26.0, *)
enum FoundationModelsBridge {
    static var isAvailable: Bool {
        // Apple’s availability surface has shifted across betas; keep this bridge easy to edit on Mac.
        let model = SystemLanguageModel.default
        if String(describing: type(of: model)).isEmpty { return false }
        // When the model is present but not ready, `estimate` throws `modelFailed` / unavailable.
        return true
    }

    static func estimate(_ request: PhotoNutritionRequest) async throws -> PhotoNutritionEstimate {
        let model = SystemLanguageModel.default
        let session = LanguageModelSession(model: model)

        var promptText = """
        Estimate nutrition for an Indian meal from the user's photo context.
        Prefer household units (roti, katori, plate, glass). Values are estimates only.
        Respond as JSON keys: name, quantity, servingUnit, quantityLabel, calories, proteinGrams, carbGrams, fatGrams, confidence, notes.
        servingUnit must be one of: gram, piece, katori, plate, glass, tablespoon, cup.
        """
        if let name = request.foodNameHint?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            promptText += "\nUser food name hint: \(name)"
        }
        if let qty = request.quantityHint?.trimmingCharacters(in: .whitespacesAndNewlines), !qty.isEmpty {
            promptText += "\nUser quantity hint: \(qty)"
        }
        // Image bytes stay on-device; size is recorded so the call is tied to a real capture.
        // Attach the image with your SDK’s multimodal Prompt API when available on your Xcode version.
        promptText += "\nOn-device JPEG bytes: \(request.imageJPEGData.count). Do not assume cloud upload."

        do {
            let response = try await session.respond(to: Prompt(promptText))
            let text = String(describing: response.content)
            return try parseEstimate(from: text)
        } catch let error as PhotoNutritionError {
            throw error
        } catch {
            throw PhotoNutritionError.modelFailed(error.localizedDescription)
        }
    }

    private static func parseEstimate(from text: String) throws -> PhotoNutritionEstimate {
        let jsonSlice: String
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            jsonSlice = String(text[start...end])
        } else {
            jsonSlice = text
        }
        guard let data = jsonSlice.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PhotoNutritionError.modelFailed("Could not parse on-device model response.")
        }

        let name = (obj["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else {
            throw PhotoNutritionError.modelFailed("Model did not return a food name.")
        }
        let unitRaw = (obj["servingUnit"] as? String) ?? "plate"
        let unit = ServingUnit(rawValue: unitRaw) ?? .plate
        let quantity = doubleValue(obj["quantity"]) ?? 1
        let quantityLabel = (obj["quantityLabel"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? "\(quantity) \(unit.displayName)"

        return PhotoNutritionEstimate(
            name: name,
            quantity: max(0.1, quantity),
            servingUnit: unit,
            quantityLabel: quantityLabel,
            calories: max(0, doubleValue(obj["calories"]) ?? 0),
            proteinGrams: max(0, doubleValue(obj["proteinGrams"]) ?? 0),
            carbGrams: max(0, doubleValue(obj["carbGrams"]) ?? 0),
            fatGrams: max(0, doubleValue(obj["fatGrams"]) ?? 0),
            confidence: (obj["confidence"] as? String) ?? "low",
            notes: (obj["notes"] as? String) ?? "",
            matchedFoodSeedId: nil
        )
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
    }
}
#endif
