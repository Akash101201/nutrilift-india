import Foundation
import UserNotifications

enum LocalNotificationService {
    static func requestAndSchedule(hour: Int) async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        guard granted == true else { return }

        center.removeAllPendingNotificationRequests()
        var date = DateComponents()
        date.hour = hour
        date.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "NutriLift India"
        content.body = "Gentle nudge: log a meal when you can. No pressure."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "meal_reminder", content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
