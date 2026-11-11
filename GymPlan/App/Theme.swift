import SwiftUI
import UIKit

/// ARK: Survival Ascended palette (always dark).
enum Theme {
    /// Cyan glow from the logo.
    static let accent = Color(hex: 0x28B8E8)
    /// Text and icons on top of the accent.
    static let onAccent = Color(hex: 0x00131B)
    /// Editing a set that was already done.
    static let edit = Color(hex: 0xFF9F0A)
    /// Rust red from the logo: Stop and destructive actions.
    static let danger = Color(hex: 0xB8493B)
    static let text = Color(hex: 0xEEF6F9)
    static let muted = Color(hex: 0x9AABB3)
    static let background = Color.black
    static let card = Color(hex: 0x0D161B)
    static let card2 = Color(hex: 0x16232B)

    static let uiAccent = UIColor(red: 0x28 / 255, green: 0xB8 / 255, blue: 0xE8 / 255, alpha: 1)
    static let uiCard = UIColor(red: 0x0D / 255, green: 0x16 / 255, blue: 0x1B / 255, alpha: 1)
    static let uiOnAccent = UIColor(red: 0x00 / 255, green: 0x13 / 255, blue: 0x1B / 255, alpha: 1)

    /// Tab bar, navigation bar and segmented controls in the palette.
    @MainActor
    static func applyUIKitAppearance() {
        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = uiCard
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = .black
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let segments = UISegmentedControl.appearance()
        segments.selectedSegmentTintColor = uiAccent
        segments.setTitleTextAttributes([.foregroundColor: uiOnAccent], for: .selected)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension View {
    /// Lists and forms on the palette's background (rows use Theme.card).
    func themedList() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

enum AppSettings {
    enum Keys {
        static let restSound = "restSound"
        static let restVibrate = "restVibrate"
        static let keepAlive = "keepAlive"
        static let weightStep = "weightStep"
        static let restBetweenExercises = "restBetweenExercises"
        static let selectedPlan = "selectedPlanID"
    }

    private static var defaults: UserDefaults { .standard }

    static var restSound: Bool { defaults.object(forKey: Keys.restSound) as? Bool ?? true }
    static var restVibrate: Bool { defaults.object(forKey: Keys.restVibrate) as? Bool ?? true }
    static var keepAlive: Bool { defaults.object(forKey: Keys.keepAlive) as? Bool ?? true }
    static var weightStep: Double { defaults.object(forKey: Keys.weightStep) as? Double ?? 2.5 }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum Fmt {
    /// 60 -> "60", 62.5 -> "62.5", 62.25 -> "62.25"
    static func num(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if abs(value - value.rounded()) < 0.001, abs(value) < 1_000_000_000 {
            return String(Int(value.rounded()))
        }
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    static func clock(_ interval: TimeInterval) -> String {
        let safe = interval.isFinite ? max(0, interval) : 0
        let total = Int(safe.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    static func rest(_ seconds: Int) -> String {
        seconds <= 0 ? "Off" : clock(TimeInterval(seconds))
    }

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func setValue(reps: Int, weight: Double, minutes: Double, meters: Double, mode: TrackingMode) -> String {
        switch mode {
        case .weightReps:
            return weight > 0 ? "\(reps) × \(num(weight)) kg" : "\(reps) reps"
        case .timeDistance:
            var parts: [String] = []
            if minutes > 0 { parts.append("\(num(minutes)) min") }
            if meters > 0 { parts.append("\(num(meters)) m") }
            return parts.isEmpty ? "—" : parts.joined(separator: " · ")
        }
    }

    static func setValue(_ set: SetTemplate, mode: TrackingMode) -> String {
        setValue(reps: set.reps, weight: set.weight, minutes: set.minutes, meters: set.meters, mode: mode)
    }

    static func setValue(_ set: LoggedSet, mode: TrackingMode) -> String {
        setValue(reps: set.reps, weight: set.weight, minutes: set.minutes, meters: set.meters, mode: mode)
    }

    static func setValue(_ set: SessionSet, mode: TrackingMode) -> String {
        setValue(reps: set.reps, weight: set.weight, minutes: set.minutes, meters: set.meters, mode: mode)
    }

    /// "3 × 10 × 60 kg" when all sets are equal, otherwise "10×60 · 8×65 · 6×70"
    static func setsSummary(_ sets: [SetTemplate], mode: TrackingMode) -> String {
        guard let first = sets.first else { return "No sets" }
        let values = sets.map { setValue($0, mode: mode) }
        if values.allSatisfy({ $0 == values[0] }) {
            return "\(sets.count) × " + setValue(first, mode: mode)
        }
        return values.joined(separator: " · ")
    }

    static func loggedSummary(_ sets: [LoggedSet], mode: TrackingMode) -> String {
        guard let first = sets.first else { return "—" }
        let values = sets.map { setValue($0, mode: mode) }
        if values.allSatisfy({ $0 == values[0] }) {
            return "\(sets.count) × " + setValue(first, mode: mode)
        }
        return values.joined(separator: " · ")
    }

    /// Accepts both "62.5" and "62,5".
    static func parseDouble(_ text: String) -> Double {
        let cleaned = text.trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else { return 0 }
        return max(0, value)
    }

    static func parseInt(_ text: String) -> Int {
        let value = parseDouble(text)
        return Int(min(value, 100_000).rounded())
    }

    /// "middle back" -> "Middle Back"
    static func title(_ raw: String) -> String { raw.capitalized }

    /// All numbers in a string: "10x62,5" -> [10, 62.5]
    static func numbers(in text: String) -> [Double] {
        var result: [Double] = []
        var current = ""
        for ch in text.replacingOccurrences(of: ",", with: ".") {
            if ch.isNumber || (ch == "." && !current.contains(".")) {
                current.append(ch)
            } else {
                if let v = Double(current) { result.append(v) }
                current = ""
            }
        }
        if let v = Double(current) { result.append(v) }
        return result
    }
}
