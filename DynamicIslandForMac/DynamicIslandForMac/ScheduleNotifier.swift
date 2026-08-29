import UserNotifications

final class ScheduleNotifier {
    private static let prefix = "island.schedule."

    func reschedule(_ items: [ScheduleNotificationRequest]) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let stale = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: stale)

            UNUserNotificationCenter.current().getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                    return
                }
                for item in items {
                    self.enqueue(item)
                }
            }
        }
    }

    func postImmediate(title: String, body: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: Self.prefix + UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func enqueue(_ item: ScheduleNotificationRequest) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default

        let interval = max(1, item.fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.prefix + item.id,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
