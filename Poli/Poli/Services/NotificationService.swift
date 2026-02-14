import UserNotifications

/// Manages local macOS notifications for the Poli application.
///
/// Uses `UNUserNotificationCenter` to request authorization and deliver
/// immediate notifications (e.g. "Correction applied", "Translation copied").
final class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Setup

    /// Requests notification authorization from the user.
    ///
    /// Asks for `.alert` and `.sound` permissions. This should be called
    /// once during app launch or onboarding.
    func setup() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[NotificationService] Authorization error: \(error.localizedDescription)")
            }
            if granted {
                print("[NotificationService] Notification permission granted.")
            }
        }
    }

    // MARK: - Send

    /// Delivers a local notification immediately.
    ///
    /// - Parameters:
    ///   - title: The notification title displayed in the banner.
    ///   - body: The notification body text.
    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // `nil` trigger means deliver immediately.
        )

        center.add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}
