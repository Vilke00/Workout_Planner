import Foundation
import Observation
import UIKit
import UniformTypeIdentifiers

/// Picks a file (or receives one via "Open in Gym Plan"), parses it and shows the import preview.
@MainActor
@Observable
final class ImportCoordinator {
    static let shared = ImportCoordinator()

    var preview: ImportPreview?
    var errorMessage: String?
    var showError = false

    private init() {}

    func pickFile() {
        DocumentPickerPresenter.shared.present { [weak self] url in
            self?.load(url)
        }
    }

    func load(_ url: URL) {
        do {
            let routines = try ImportService.parse(url: url)
            if routines.isEmpty {
                fail("No exercises were found in \(url.lastPathComponent).")
            } else {
                preview = ImportPreview(fileName: url.lastPathComponent, routines: routines)
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        showError = true
    }
}

/// UIKit document picker in copy mode. Copy mode needs no security-scoped access to the
/// original file, which is what breaks the SwiftUI file importer inside LiveContainer.
final class DocumentPickerPresenter: NSObject, UIDocumentPickerDelegate {
    static let shared = DocumentPickerPresenter()

    private var completion: ((URL) -> Void)?

    func present(completion: @escaping (URL) -> Void) {
        guard let top = Self.topViewController() else { return }
        self.completion = completion
        // .item = every file is selectable; the parser reports unsupported formats.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = self
        top.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let handler = completion
        completion = nil
        guard let url = urls.first else { return }
        // Wait for the picker to finish closing before presenting the preview sheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            handler?(url)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion = nil
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        let window = windows.first { $0.isKeyWindow } ?? windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
