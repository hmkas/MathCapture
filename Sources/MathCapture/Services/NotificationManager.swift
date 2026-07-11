import UserNotifications

enum NotificationManager {
    static func showSuccess(format: OutputFormat = .mathML) {
        let content = UNMutableNotificationContent()
        content.title = format.notificationTitle
        content.subtitle = "Formula recognized and copied to clipboard"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func showError(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "MathCapture Error"
        content.body = message

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
