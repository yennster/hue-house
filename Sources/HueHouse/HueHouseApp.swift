import SwiftUI

@main
struct HueHouseApp: App {
    @StateObject private var store = HueStore()
    @AppStorage(HueAppStorage.appearanceModeKey) private var appearanceModeRawValue = HueAppearanceMode.system.rawValue

    init() {
        HueHouseShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(appearanceMode.colorScheme)
                .frame(minWidth: 720, minHeight: 480)
                .task {
                    await store.refreshLightsIfReady()
                }
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Lights") {
                    Task { await store.refreshLights() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!store.canControlLights)

                Button("Apply Selected Gradient") {
                    Task { await store.applySelectedGradient() }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(!store.canControlLights)
            }
        }

        MenuBarExtra {
            HueMenuBarView()
                .environmentObject(store)
                .preferredColorScheme(appearanceMode.colorScheme)
        } label: {
            HueMenuBarLabel()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }

    private var appearanceMode: HueAppearanceMode {
        HueAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }
}
