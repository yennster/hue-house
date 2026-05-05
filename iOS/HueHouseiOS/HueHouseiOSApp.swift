import HueKit
import SwiftUI

@main
struct HueHouseiOSApp: App {
    @StateObject private var store: HueStore
    @AppStorage(HueAppStorage.appearanceModeKey) private var appearanceModeRawValue = "system"
    @Environment(\.scenePhase) private var scenePhase

    private let launchOptions: LaunchOptions

    init() {
        let options = LaunchOptions.parse(arguments: ProcessInfo.processInfo.arguments)
        self.launchOptions = options

        // Pre-populate demo state synchronously so child views see the seeded
        // store on their very first body pass — otherwise `BridgeView.task`
        // would race the demo seeding and briefly run network discovery.
        let store = HueStore()
        if options.demoMode {
            store.enableDemoMode()
        }
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView(initialTab: launchOptions.initialTab)
                .environmentObject(store)
                .preferredColorScheme(colorScheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await store.refreshLightsIfReady() }
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearanceModeRawValue {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

enum RootTab: String, Hashable {
    case lights, gradients, bridge
}

/// Parses the launch arguments for screenshot automation and UI testing.
/// Recognised arguments (case-insensitive values):
///   `-Demo YES`        — seed the store with demo lights and groups, bypassing bridge pairing.
///   `-Tab <name>`      — open the app on Lights / Gradients / Bridge.
struct LaunchOptions {
    var demoMode: Bool = false
    var initialTab: RootTab = .lights

    static func parse(arguments: [String]) -> LaunchOptions {
        var options = LaunchOptions()
        if let i = arguments.firstIndex(of: "-Demo"), i + 1 < arguments.count {
            let value = arguments[i + 1].lowercased()
            options.demoMode = ["yes", "true", "1"].contains(value)
        }
        if let i = arguments.firstIndex(of: "-Tab"), i + 1 < arguments.count,
           let tab = RootTab(rawValue: arguments[i + 1].lowercased()) {
            options.initialTab = tab
        }
        return options
    }
}
