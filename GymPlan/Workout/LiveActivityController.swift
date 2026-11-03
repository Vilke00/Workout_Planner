import ActivityKit
import Foundation

/// Starts / updates / ends the lock screen Live Activity.
/// Inside LiveContainer app extensions can't run, so the app falls back to the control notification.
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<WorkoutActivityAttributes>?

    /// Apps installed by iOS (SideStore, AltStore, Sideloadly, Xcode) live in ".../Bundle/Application/".
    /// Inside LiveContainer the bundle sits in LiveContainer's own data folder.
    static var isInstalledNormally: Bool {
        Bundle.main.bundlePath.contains("/Bundle/Application/")
    }

    var isAvailable: Bool {
        Self.isInstalledNormally && ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isRunning: Bool { activity != nil }

    func start(routineName: String, startDate: Date, state: WorkoutActivityAttributes.ContentState) {
        endAll()
        guard isAvailable else { return }
        let attributes = WorkoutActivityAttributes(routineName: routineName, startDate: startDate)
        do {
            activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Live Activity could not start: \(error)")
            activity = nil
        }
    }

    /// After the app was relaunched: reconnect to the running activity or start a new one.
    func restore(routineName: String, startDate: Date, state: WorkoutActivityAttributes.ContentState) {
        guard isAvailable else { return }
        if let existing = Activity<WorkoutActivityAttributes>.activities.first {
            activity = existing
            update(state)
        } else {
            start(routineName: routineName, startDate: startDate, state: state)
        }
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func endAll() {
        activity = nil
        let running = Activity<WorkoutActivityAttributes>.activities
        guard !running.isEmpty else { return }
        Task {
            for item in running {
                await item.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
