import Foundation

enum Formatters {
    static let number: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static let oneDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }()

    static func kcal(_ value: Double) -> String {
        "\(number.string(from: NSNumber(value: value.rounded())) ?? "0") kcal"
    }

    static func grams(_ value: Double) -> String {
        "\(number.string(from: NSNumber(value: value.rounded())) ?? "0") g"
    }

    static func kg(_ value: Double) -> String {
        let s = oneDecimal.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
        return "\(s) kg"
    }

    static func signedKcal(_ value: Double) -> String {
        let rounded = value.rounded()
        if rounded > 0 { return "+\(Int(rounded)) kcal" }
        return "\(Int(rounded)) kcal"
    }
}
