import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL

    @AppStorage(AppSettings.Keys.restSound) private var restSound = true
    @AppStorage(AppSettings.Keys.restVibrate) private var restVibrate = true
    @AppStorage(AppSettings.Keys.keepAlive) private var keepAlive = true
    @AppStorage(AppSettings.Keys.weightStep) private var weightStep = 2.5

    @State private var showImporter = false
    @State private var preview: ImportPreview?
    @State private var importError: String?
    @State private var showError = false
    @State private var showClearHistory = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                importSection
                workoutSection
                notificationSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: ImportService.contentTypes,
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .sheet(item: $preview) { item in
                ImportPreviewView(preview: item)
            }
            .alert("Import failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "Unknown error")
            }
            .alert("Delete all workout history?", isPresented: $showClearHistory) {
                Button("Delete", role: .destructive) { store.clearLogs() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your plans and routines are kept. Only finished workouts are removed.")
            }
            .task { await refreshNotificationStatus() }
        }
    }

    // MARK: Sections

    private var importSection: some View {
        Section {
            Button {
                showImporter = true
            } label: {
                Label("Import from Excel / CSV", systemImage: "square.and.arrow.down")
            }
            NavigationLink {
                ImportFormatHelpView()
            } label: {
                Label("Table format", systemImage: "tablecells")
            }
        } header: {
            Text("Import")
        } footer: {
            Text("Each row is an exercise with its sets and rest time. Exercises are matched to the library by name; unknown names are added as custom exercises.")
        }
    }

    private var workoutSection: some View {
        Section {
            Toggle("Sound when rest is over", isOn: $restSound)
            Toggle("Vibrate when rest is over", isOn: $restVibrate)
            Toggle("Keep app awake during workout", isOn: $keepAlive)
            Picker("Weight step (+/−)", selection: $weightStep) {
                Text("1 kg").tag(1.0)
                Text("1.25 kg").tag(1.25)
                Text("2.5 kg").tag(2.5)
                Text("5 kg").tag(5.0)
            }
        } header: {
            Text("Workout")
        } footer: {
            Text("\"Keep app awake\" lets the app beep over your music, even in silent mode and when the phone is locked. Turn it off to rely only on notifications.")
        }
    }

    private var notificationSection: some View {
        Section {
            LabeledContent("Lock screen controls", value: controlsMode)
            HStack {
                Text("Status")
                Spacer()
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
            if notificationStatus == .notDetermined {
                Button("Allow Notifications") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                        Task { await refreshNotificationStatus() }
                    }
                }
            } else if notificationStatus == .denied {
                Button("Open iPhone Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Installed with SideStore, AltStore or Sideloadly the workout is controlled from a Live Activity on the lock screen. Inside LiveContainer extensions can't run, so a notification with Done, Skip, −1 rep and Edit is used instead; enable \"Fix Local Notifications\" for this app there.")
        }
    }

    private var dataSection: some View {
        Section {
            LabeledContent("Exercises in library", value: "\(store.libraryExercises.count)")
            LabeledContent("Custom exercises", value: "\(store.customExercises.count)")
            LabeledContent("Finished workouts", value: "\(store.logs.count)")
            Button("Delete Workout History", role: .destructive) {
                showClearHistory = true
            }
            .disabled(store.logs.isEmpty)
        } header: {
            Text("Data")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
        } header: {
            Text("About")
        } footer: {
            Text("Exercise data and images: free-exercise-db (public domain, Unlicense).")
        }
    }

    // MARK: Helpers

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var controlsMode: String {
        if !LiveActivityController.isInstalledNormally { return "Notification (LiveContainer)" }
        return LiveActivityController.shared.isAvailable ? "Live Activity" : "Notification (Live Activities off)"
    }

    private var statusText: String {
        switch notificationStatus {
        case .authorized: return "Allowed"
        case .denied: return "Off"
        case .provisional: return "Quiet"
        case .ephemeral: return "Temporary"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = settings.authorizationStatus
        await MainActor.run { notificationStatus = status }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
            showError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let routines = try ImportService.parse(url: url)
                if routines.isEmpty {
                    importError = "No exercises were found in \(url.lastPathComponent)."
                    showError = true
                } else {
                    preview = ImportPreview(fileName: url.lastPathComponent, routines: routines)
                }
            } catch {
                importError = error.localizedDescription
                showError = true
            }
        }
    }
}

struct ImportPreview: Identifiable {
    let id = UUID()
    let fileName: String
    let routines: [ImportedRoutine]
}

/// Shows what will be imported and where.
struct ImportPreviewView: View {
    let preview: ImportPreview

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var targetPlanID: UUID?
    @State private var newPlanName = ""
    @State private var resultMessage: String?
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Import into", selection: $targetPlanID) {
                        Text("New plan").tag(UUID?.none)
                        ForEach(store.plans) { plan in
                            Text(plan.name).tag(UUID?.some(plan.id))
                        }
                    }
                    if targetPlanID == nil {
                        TextField("New plan name", text: $newPlanName)
                    }
                } footer: {
                    Text("Routines with the same name as an existing routine get the exercises added to the end.")
                }

                ForEach(preview.routines) { routine in
                    Section(routine.name) {
                        ForEach(routine.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(summary(exercise))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(preview.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { runImport() }
                        .bold()
                }
            }
            .alert("Import complete", isPresented: $showResult) {
                Button("OK") { dismiss() }
            } message: {
                Text(resultMessage ?? "")
            }
            .onAppear {
                if targetPlanID == nil { targetPlanID = store.selectedPlanID }
                if newPlanName.isEmpty {
                    newPlanName = (preview.fileName as NSString).deletingPathExtension
                }
            }
        }
    }

    private func summary(_ exercise: ImportedExercise) -> String {
        let base = "\(Fmt.setsSummary(exercise.sets, mode: exercise.mode)) · Rest \(Fmt.rest(exercise.restSeconds))"
        return exercise.supersetWithNext ? base + " · + superset with next" : base
    }

    private func runImport() {
        let result = store.applyImport(preview.routines, planID: targetPlanID, newPlanName: newPlanName)
        var message = "Added \(result.exercisesAdded) exercises to \"\(result.planName)\""
        if result.routinesCreated > 0 { message += " (\(result.routinesCreated) new routines)" }
        message += "."
        if !result.customCreated.isEmpty {
            let names = result.customCreated.prefix(8).joined(separator: ", ")
            let more = result.customCreated.count > 8 ? " and \(result.customCreated.count - 8) more" : ""
            message += "\n\nNot found in the library, added as custom exercises: \(names)\(more)."
        }
        resultMessage = message
        showResult = true
    }
}

struct ImportFormatHelpView: View {
    var body: some View {
        List {
            Section {
                Text("The first row holds the column names. Use one row per exercise:")
                Text("Routine | Exercise | Superset | Rest | Set 1 | Set 2 …")
                    .font(.system(.footnote, design: .monospaced))
            } header: {
                Text("Layout")
            }
            Section {
                example("10x60", "10 reps × 60 kg")
                example("12", "12 reps, bodyweight")
                example("1 min", "1 minute")
                example("30 s", "30 seconds")
                example("400 m", "400 meters")
                example("20 min 5 km", "20 minutes, 5000 meters")
            } header: {
                Text("Set cells")
            }
            Section {
                example("90", "90 seconds")
                example("1:30", "1 minute 30 seconds")
                example("2 min", "2 minutes")
                example("(empty)", "Off")
            } header: {
                Text("Rest cells")
            }
            Section {
                example("+", "Superset with the next row")
                example("(empty)", "Normal exercise")
            } header: {
                Text("Superset column (optional)")
            }
            Section {
                Text("You can also use one row per set with the columns Routine, Exercise, Reps, Kg, Time (min), Distance (m) and Rest. An empty Exercise cell continues the exercise above.")
                Text("If the Routine column is empty, the routine from the row above is used. Without a Routine column everything goes into a routine called \"Imported\".")
            } header: {
                Text("Other options")
            }
        }
        .navigationTitle("Table format")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func example(_ cell: String, _ meaning: String) -> some View {
        HStack {
            Text(cell)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(meaning)
                .foregroundStyle(.secondary)
        }
    }
}
