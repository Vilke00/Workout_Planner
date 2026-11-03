import SwiftUI
import UIKit

@main
struct GymPlanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore.shared
    @State private var workout = WorkoutManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(workout)
                .tint(Theme.accent)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationManager.shared.configure()
        WorkoutManager.shared.restoreIfNeeded()
        return true
    }
}
