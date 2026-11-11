import Foundation
import Observation
import UserNotifications

/// The app's three quiet local notifications, each off until turned on and each worded like the
/// rest of the app: a nudge to check in, never a scolding.
/// - Morning: a little after the target wake time, for the sleep check-in.
/// - Evening: at the time picked in Settings, for the day's goals.
/// - The 1st of the month: for the month's work number, when there is a job.
enum Reminder {
    static let evening = "labatalla.daily"
    static let morning = "labatalla.morning"
    static let month = "labatalla.month"
    /// The key in a notification's userInfo that says which screen it opens.
    static let routeKey = "route"

    /// Minutes after the target wake time that the morning nudge comes.
    static let morningDelay = 15

    /// When the morning nudge comes for a wake time.
    static func morningMinute(wake: Int) -> Int { clampMinute(wake + morningDelay) }

    /// What should be pending for these settings, as (id, hour, minute, day of month, title, body, route).
    static func planned(_ s: Settings, hasWork: Bool) -> [Planned] {
        var out: [Planned] = []
        let mantra = s.mantra.isEmpty ? DEFAULT_MANTRA : s.mantra
        if s.morningCheckIn {
            let m = morningMinute(wake: s.targetWakeMinute)
            out.append(Planned(id: morning, hour: m / 60, minute: m % 60, day: nil,
                               title: "Sleep check-in", body: "How was the night? A few dials and a tap.", route: .sleep))
        }
        if s.reminderOn {
            out.append(Planned(id: evening, hour: s.reminderMinute / 60, minute: s.reminderMinute % 60, day: nil,
                               title: mantra, body: "Today's check-in: yes or no, and the reason. Whatever got done counts.", route: .today))
        }
        if s.monthStartReminder && hasWork {
            let m = clampMinute(s.targetWakeMinute + 60)
            out.append(Planned(id: month, hour: m / 60, minute: m % 60, day: 1,
                               title: "A new month", body: "What is the number for it, and the hours a day?", route: .today))
        }
        return out
    }

    struct Planned: Equatable {
        var id: String
        var hour: Int
        var minute: Int
        /// Day of the month, for the one that comes monthly.
        var day: Int?
        var title: String
        var body: String
        var route: Route
    }

    enum Route: String { case sleep, today }

    /// Puts the pending notifications in line with the settings. Asks permission the first time
    /// any is turned on; after that iOS remembers the answer and shows nothing.
    static func sync(_ settings: Settings, hasWork: Bool = false) {
        let center = UNUserNotificationCenter.current()
        let wanted = planned(settings, hasWork: hasWork)
        let unwanted = [evening, morning, month].filter { id in !wanted.contains { $0.id == id } }
        center.removePendingNotificationRequests(withIdentifiers: unwanted)
        guard !wanted.isEmpty else { return }
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            for item in wanted {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default
                content.userInfo = [routeKey: item.route.rawValue]
                var at = DateComponents()
                at.hour = item.hour
                at.minute = item.minute
                if let day = item.day { at.day = day }
                let trigger = UNCalendarNotificationTrigger(dateMatching: at, repeats: true)
                center.removePendingNotificationRequests(withIdentifiers: [item.id])
                try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
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

/// The screen a tapped notification asked for. RootView watches it and clears it once shown.
@Observable
final class RouteBox {
    var route: Reminder.Route?
}

/// Hears a tapped notification and puts its route in the box.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    let box = RouteBox()

    /// Called once as the app starts, so a tap that launches the app is heard too.
    func listen() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let raw = response.notification.request.content.userInfo[Reminder.routeKey] as? String
        let route = raw.flatMap { Reminder.Route(rawValue: $0) } ?? .today
        DispatchQueue.main.async { [box] in box.route = route }
        completionHandler()
    }

    /// With the app open, the nudge still shows as a banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
