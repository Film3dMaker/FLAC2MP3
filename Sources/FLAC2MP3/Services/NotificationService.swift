import Foundation
import UserNotifications

public struct NotificationService {
    public static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    public static func sendCompletionNotification(successCount: Int, failCount: Int, totalCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Conversión completada 🎉"
        if failCount == 0 {
            content.body = "Se convirtieron exitosamente los \(totalCount) archivos de audio."
        } else {
            content.body = "\(successCount) de \(totalCount) archivos convertidos (\(failCount) con error)."
        }
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error displaying notification: \(error.localizedDescription)")
            }
        }
    }

    public static func sendErrorNotification(error: String) {
        let content = UNMutableNotificationContent()
        content.title = "FLAC2MP3 - Error"
        content.body = error
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

