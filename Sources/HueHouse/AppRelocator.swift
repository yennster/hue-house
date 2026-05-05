import AppKit
import Foundation

/// Prompts the user to move Hue House into `/Applications` on first launch
/// from a non-installed location (e.g. a download in `~/Downloads`).
///
/// macOS keeps better track of apps that live in `/Applications` or
/// `~/Applications` — Spotlight indexing, the menu bar lifecycle, and
/// auto-update flows all behave more predictably from there.
///
/// On accept we copy the bundle, launch the moved copy, and quit ourselves.
/// On decline we set a UserDefaults flag so the prompt doesn't reappear.
enum AppRelocator {
    private static let skipPromptKey = "HueHouseSkipMoveToApplicationsPrompt"

    @MainActor
    static func promptIfNeeded() {
        let bundleURL = Bundle.main.bundleURL
        let path = bundleURL.path

        // Skip during development. `swift run` and freshly built bundles in
        // `.build/` aren't intended for "real" install.
        guard !path.contains("/.build/") else { return }

        let systemApplications = "/Applications/"
        let userApplications = (NSString(string: "~/Applications/").expandingTildeInPath as String) + ""
        if path.hasPrefix(systemApplications) || path.hasPrefix(userApplications) {
            return
        }

        if UserDefaults.standard.bool(forKey: skipPromptKey) {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Move Hue House to Applications?"
        alert.informativeText = """
        Hue House works best when installed in your Applications folder. Move now and Hue House will relaunch from there.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            relocate(from: bundleURL)
        default:
            UserDefaults.standard.set(true, forKey: skipPromptKey)
        }
    }

    @MainActor
    private static func relocate(from source: URL) {
        let destination = URL(fileURLWithPath: "/Applications/HueHouse.app")
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: destination.path) {
                // Replace any older copy. removeItem will throw on a permission
                // failure, which we surface to the user below.
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't move Hue House"
            alert.informativeText = """
            \(error.localizedDescription)

            Drag HueHouse.app into your Applications folder manually and relaunch it from there.
            """
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        // Launch the relocated copy and quit ourselves so the moved bundle
        // becomes the running instance — and the OS indexes its App Intents.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", destination.path]
        try? process.run()

        NSApp.terminate(nil)
    }
}
