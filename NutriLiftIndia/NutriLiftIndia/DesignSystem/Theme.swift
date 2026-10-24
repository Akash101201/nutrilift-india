import SwiftUI
import UIKit

// MARK: - Color helpers

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// A color that switches between a light-mode and a dark-mode hex value (0xRRGGBB).
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

// MARK: - Theme

/// Warm, Indian-inspired palette: saffron, chilli, leaf green and a cool teal for contrast.
enum Theme {
    // Brand colors
    static let saffron = Color(light: 0xF5A524, dark: 0xFFB93D)
    static let chilli = Color(light: 0xE8493F, dark: 0xFF6B5E)
    static let leaf = Color(light: 0x2FA866, dark: 0x4CC985)
    static let teal = Color(light: 0x1F85B5, dark: 0x4FB3E0)
    static let plum = Color(light: 0x8E5BD6, dark: 0xB48CF0)

    // Surfaces
    static let background = Color(light: 0xFFF8EF, dark: 0x14110F)
    static let card = Color(light: 0xFFFFFF, dark: 0x221D1A)
    static let cardSelected = Color(light: 0xFFF1DB, dark: 0x3A2C1B)

    // Meaning
    static let calories = saffron
    static let protein = chilli
    static let carbs = Color(light: 0xE0A100, dark: 0xFFD25A)
    static let fat = leaf
    static let fiber = plum
    static let water = teal

    // Gradients
    static let brandGradient = LinearGradient(
        colors: [saffron, chilli],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let freshGradient = LinearGradient(
        colors: [leaf, teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let waterGradient = LinearGradient(
        colors: [teal.opacity(0.85), teal],
        startPoint: .top,
        endPoint: .bottom
    )

    static let confettiColors: [Color] = [saffron, chilli, leaf, teal, plum]

    // Shape
    static let radius: CGFloat = 20
    static let smallRadius: CGFloat = 14
}

// MARK: - Type

extension Font {
    /// Rounded system font that still scales with Dynamic Type.
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

// MARK: - Backgrounds

private struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            ZStack(alignment: .top) {
                Theme.background
                LinearGradient(
                    colors: [Theme.saffron.opacity(0.18), Theme.saffron.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
            }
            .ignoresSafeArea()
        }
    }
}

extension View {
    /// Warm cream background with a soft saffron glow at the top.
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}

// MARK: - Greeting

enum Greeting {
    static func forNow(_ date: Date = Date(), calendar: Calendar = .current) -> (emoji: String, text: String) {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return ("🌅", "Good morning")
        case 12..<17: return ("☀️", "Good afternoon")
        case 17..<21: return ("🌇", "Good evening")
        default: return ("🌙", "Hey, night owl")
        }
    }
}
