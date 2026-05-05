import HueKit
import SwiftUI

@main
struct HueHouseApp: App {
    @StateObject private var store = HueStore()
    @AppStorage(HueAppStorage.appearanceModeKey) private var appearanceModeRawValue = HueAppearanceMode.system.rawValue
    @AppStorage(HueAppStorage.hidesDockIconKey) private var hidesDockIcon = false

    init() {
        HueHouseShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 760, minHeight: 540)
                .task {
                    applyActivationPolicy()
                    HueAppearanceMode.apply(
                        HueAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
                    )
                    await store.refreshLightsIfReady()
                }
                .onChange(of: appearanceModeRawValue) { _, newValue in
                    HueAppearanceMode.apply(
                        HueAppearanceMode(rawValue: newValue) ?? .system
                    )
                }
                .onChange(of: hidesDockIcon) { _, _ in
                    applyActivationPolicy()
                }
        }
        .windowResizability(.contentSize)
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
        } label: {
            HueMenuBarLabel()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }

    /// Applies the user's "Hide Dock icon" preference. `.accessory` removes the
    /// Dock tile and the app's main menu bar, but the menu bar extra and any
    /// open windows stay visible. Switching back to `.regular` restores the
    /// Dock icon and re-activates the app so the window can take key status.
    private func applyActivationPolicy() {
        if hidesDockIcon {
            NSApplication.shared.setActivationPolicy(.accessory)
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
