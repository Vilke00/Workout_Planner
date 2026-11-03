import Foundation
import UserNotifications

/// Local notifications: the workout "control" notification (with Done / Skip / −1 / Edit actions)
/// and the "rest is over" alert.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    enum Action: String {
        case done = "WORKOUT_DONE"
        case skip = "WORKOUT_SKIP"
        case minus = "WORKOUT_MINUS"
        case edit = "WORKOUT_EDIT"
    }

    enum Category: String {
        case weight = "WORKOUT_WEIGHT"
        case time = "WORKOUT_TIME"
    }

    static let controlID = "workout.control"
    static let restEndID = "workout.restEnd"

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    func configure() {
        center.delegate = self

        let done = UNNotificationAction(identifier: Action.done.rawValue, title: "✓ Done", options: [])
        let skip = UNNotificationAction(identifier: Action.skip.rawValue, title: "✕ Skip set", options: [])
        let minus = UNNotificationAction(identifier: Action.minus.rawValue, title: "−1 rep", options: [])
        let editWeight = UNTextInputNotificationAction(identifier: Action.edit.rawValue,
                                                       title: "Edit reps × kg",
                                                       options: [],
                                                       textInputButtonTitle: "Save",
                                                       textInputPlaceholder: "e.g. 10x62.5")
        let editTime = UNTextInputNotificationAction(identifier: Action.edit.rawValue,
                                                     title: "Edit min × meters",
                                                     options: [],
                                                     textInputButtonTitle: "Save",
                                                     textInputPlaceholder: "e.g. 5 1000")

        let weight = UNNotificationCategory(identifier: Category.weight.rawValue,
                                            actions: [done, skip, minus, editWeight],
                                            intentIdentifiers: [],
                                            options: [])
        let time = UNNotificationCategory(identifier: Category.time.rawValue,
                                          actions: [done, skip, editTime],
                                          intentIdentifiers: [],
                                          options: [])
        center.setNotificationCategories([weight, time])
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: Control notification

    func postControl(title: String, subtitle: String, body: String, category: Category?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = nil
        content.threadIdentifier = "workout"
        content.interruptionLevel = .passive
        if let category { content.categoryIdentifier = category.rawValue }
        let request = UNNotificationRequest(identifier: Self.controlID, content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }

    func removeControl() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.controlID])
        center.removePendingNotificationRequests(withIdentifiers: [Self.controlID])
    }

    // MARK: Rest end

    /// Scheduled alert with sound — used when the app is suspended by iOS.
    func scheduleRestEnd(at date: Date, title: String, body: String, category: Category?) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0.5 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "workout"
        content.interruptionLevel = .active
        if let category { content.categoryIdentifier = category.rawValue }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.restEndID, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// Immediate banner without sound — the app plays its own sound when it is awake.
    func showRestEndNow(title: String, body: String, category: Category?) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.restEndID])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        content.threadIdentifier = "workout"
        content.interruptionLevel = .active
        if let category { content.categoryIdentifier = category.rawValue }
        let request = UNNotificationRequest(identifier: Self.restEndID, content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }

    func cancelPendingRestEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.restEndID])
    }

    func clearRestEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.restEndID])
        center.removeDeliveredNotifications(withIdentifiers: [Self.restEndID])
    }

    func clearAll() {
        let ids = [Self.controlID, Self.restEndID]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let id = notification.request.identifier
        if id == Self.controlID || id == Self.restEndID {
            // The app is open and already shows everything; keep it only in Notification Center.
            completionHandler([.list])
        } else {
            completionHandler([.banner, .list, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionID = response.actionIdentifier
        let text = (response as? UNTextInputNotificationResponse)?.userText
        let isDefault = actionID == UNNotificationDefaultActionIdentifier
        DispatchQueue.main.async {
            if isDefault {
                WorkoutManager.shared.openFromNotification()
            } else {
                WorkoutManager.shared.handleNotificationAction(actionID, text: text)
            }
            completionHandler()
        }
    }
}
