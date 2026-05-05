import HueKit
import SwiftUI

@main
struct HueHouseiOSApp: App {
    @StateObject private var store = HueStore()
    @AppStorage(HueAppStorage.appearanceModeKey) private var appearanceModeRawValue = "system"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(colorScheme)
                .task {
                    await store.refreshLightsIfReady()
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
