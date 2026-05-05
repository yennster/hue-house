import AppKit
import Foundation

/// Re-registers the running bundle with LaunchServices and refreshes the
/// App Intents parameters, then opens Shortcuts.app so the user can verify.
/// Used by the "Set Up Siri & Shortcuts" button in the Bridge tab.
///
/// macOS doesn't expose a public API to force App Intents registration; the
/// system is supposed to do it automatically when an app in /Applications
/// launches. When that fails (stale LaunchServices cache after multiple
/// installs, ad-hoc-signed bundle quirks, etc.), the closest thing to a
/// Terminal-free fix is to invoke `lsregister -f <bundle>` from the app
/// itself — which is exactly what this does.
@MainActor
enum SiriShortcutsSetup {
    enum Result {
        case opened
        case notInApplicationsFolder(URL)
        case registrationFailed(String)
    }

    /// Tries to re-register the bundle and then open Shortcuts.app.
    static func run() -> Result {
        let bundleURL = Bundle.main.bundleURL
        let path = bundleURL.path

        let systemApplications = "/Applications/"
        let userApplications = NSString(string: "~/Applications/").expandingTildeInPath + ""
        let isInstalled = path.hasPrefix(systemApplications) || path.hasPrefix(userApplications)

        guard isInstalled else {
            return .notInApplicationsFolder(bundleURL)
        }

        // 1. Refresh App Intents parameters so the OS picks up the latest
        //    phrase set / entity values.
        HueHouseShortcuts.updateAppShortcutParameters()

        // 2. Force LaunchServices to re-process the bundle's Info.plist and
        //    Metadata.appintents. Equivalent to running `lsregister -f` in
        //    Terminal but without the user touching a shell.
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        if FileManager.default.isExecutableFile(atPath: lsregister) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: lsregister)
            process.arguments = ["-f", bundleURL.path]
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    return .registrationFailed("lsregister exited with status \(process.terminationStatus)")
                }
            } catch {
                return .registrationFailed(error.localizedDescription)
            }
        }

        // 3. Open Shortcuts.app so the user can verify the actions appeared.
        if let url = URL(string: "shortcuts://") {
            NSWorkspace.shared.open(url)
        }

        return .opened
    }
}
