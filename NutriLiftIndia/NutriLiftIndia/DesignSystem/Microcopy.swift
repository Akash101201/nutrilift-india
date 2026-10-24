import Foundation

/// Friendly, non-shaming copy. Going over a target is never a failure.
enum Microcopy {
    static func calorieLine(consumed: Double, target: Double) -> String {
        guard target > 0 else { return "" }
        if consumed <= 0 { return "Log your first meal to get the ring moving 🍛" }
        switch consumed / target {
        case ..<0.5: return "Off to a good start 🌱"
        case ..<0.9: return "Going well, keep it up 💪"
        case ...1.05: return "Right on target 🎯"
        default: return "A little over today, and that's okay. Tomorrow's a fresh start 🌅"
        }
    }

    static func streakLine(streak: Int, loggedToday: Bool) -> String {
        switch (streak, loggedToday) {
        case (0, _): "Log a meal today to start a streak"
        case (_, true): "Nice, you're on a roll today"
        default: "Log a meal today to keep it going"
        }
    }

    static func waterLine(glasses: Int, goal: Int) -> String {
        if glasses >= goal { return "Hydration goal done! 🎉" }
        if glasses == 0 { return "Start with a glass of water" }
        return "\(goal - glasses) more to go"
    }
}
