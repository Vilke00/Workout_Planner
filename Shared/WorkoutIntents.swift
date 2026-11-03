import AppIntents
import Foundation

// Buttons on the Live Activity. LiveActivityIntent runs `perform()` inside the app process,
// so the app's WorkoutManager handles them. The extension only needs the type to build buttons.

struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Set"
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if MAIN_APP
        await MainActor.run { WorkoutManager.shared.completeCurrentSet() }
        #endif
        return .result()
    }
}

struct SkipSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Set"
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if MAIN_APP
        await MainActor.run { WorkoutManager.shared.skipCurrentSet() }
        #endif
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Rest"
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if MAIN_APP
        await MainActor.run { WorkoutManager.shared.skipRest() }
        #endif
        return .result()
    }
}

struct AdjustSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Adjust Set"
    static var isDiscoverable: Bool = false

    /// 0 = reps (or minutes), 1 = kg (or meters)
    @Parameter(title: "Value")
    var value: Int

    /// +1 or -1
    @Parameter(title: "Direction")
    var direction: Int

    init() {}

    init(value: Int, direction: Int) {
        self.value = value
        self.direction = direction
    }

    func perform() async throws -> some IntentResult {
        #if MAIN_APP
        let value = self.value
        let direction = self.direction
        await MainActor.run { WorkoutManager.shared.adjustFromControls(value: value, direction: direction) }
        #endif
        return .result()
    }
}
