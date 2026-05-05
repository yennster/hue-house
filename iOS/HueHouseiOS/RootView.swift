import HueKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HueStore
    @State private var selectedTab: RootTab

    init(initialTab: RootTab = .lights) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { LightsView() }
                .tabItem { Label("Lights", systemImage: "lightbulb.2.fill") }
                .tag(RootTab.lights)

            NavigationStack { GradientsView() }
                .tabItem { Label("Gradients", systemImage: "paintpalette.fill") }
                .tag(RootTab.gradients)

            NavigationStack { BridgeView() }
                .tabItem { Label("Bridge", systemImage: "wifi.router.fill") }
                .tag(RootTab.bridge)
        }
        .alert(
            store.errorAlert?.title ?? "",
            isPresented: Binding(
                get: { store.errorAlert != nil },
                set: { if !$0 { store.errorAlert = nil } }
            ),
            presenting: store.errorAlert
        ) { _ in
            Button("OK", role: .cancel) { store.errorAlert = nil }
        } message: { alert in
            Text(alert.message)
        }
    }
}
