import HueKit
import SwiftUI

@main
struct HueHouseiOSApp: App {
    @StateObject private var store = HueStore()
    @AppStorage(HueAppStorage.appearanceModeKey) private var appearanceModeRawValue = "system"
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
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
