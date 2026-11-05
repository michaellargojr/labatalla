import Foundation
import UserNotifications

/// One quiet local notification a day, at the time picked in Settings. Off until turned on, and
/// worded like the rest of the app: a nudge to mark the day, never a scolding.
enum Reminder {
    static let id = "labatalla.daily"

    /// Puts the pending notification in line with the settings. Asks permission the first time
    /// the reminder is turned on; after that iOS remembers the answer and shows nothing.
    static func sync(_ settings: Settings) {
        let center = UNUserNotificationCenter.current()
        guard settings.reminderOn else {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return
        }
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = settings.mantra.isEmpty ? DEFAULT_MANTRA : settings.mantra
            content.body = "Mark today. Whatever got done counts."
            content.sound = .default
            var at = DateComponents()
            at.hour = settings.reminderMinute / 60
            at.minute = settings.reminderMinute % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: at, repeats: true)
            center.removePendingNotificationRequests(withIdentifiers: [id])
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    /// "8:00 PM" for a minute of the day, in the phone's own style.
    static func timeText(_ minute: Int) -> String {
        var c = DateComponents()
        c.hour = minute / 60
        c.minute = minute % 60
        let d = Calendar.current.date(from: c) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
}
