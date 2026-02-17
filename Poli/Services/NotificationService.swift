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

    /// Requests notification authorization only if the user hasn't been asked yet.
    ///
    /// Checks the current authorization status first and only calls
    /// `requestAuthorization` when the status is `.notDetermined`.
    func setup() {
        center.getNotificationSettings { [weak self] settings in
            guard let self, settings.authorizationStatus == .notDetermined else { return }

            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                #if DEBUG
                if let error {
                    print("[NotificationService] Authorization error: \(error.localizedDescription)")
                }
                print("[NotificationService] Notification permission \(granted ? "granted" : "denied").")
                #endif
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
            trigger: nil
        )

        center.add(request) { error in
            #if DEBUG
            if let error {
                print("[NotificationService] Failed to send notification: \(error.localizedDescription)")
            }
            #endif
        }
    }
}
