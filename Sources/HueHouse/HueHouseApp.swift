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
                .frame(minWidth: 760, minHeight: 540)
                .task {
                    // Adding a MenuBarExtra scene can flip the activation policy
                    // to .accessory on some macOS versions, which prevents the
                    // main window from accepting key status — typing in any
                    // TextField then beeps. Force regular activation so the
                    // window can take first responder normally.
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)

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
}
