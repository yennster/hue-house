import HueKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HueStore

    var body: some View {
        TabView {
            NavigationStack { LightsView() }
                .tabItem { Label("Lights", systemImage: "lightbulb.2.fill") }

            NavigationStack { GradientsView() }
                .tabItem { Label("Gradients", systemImage: "paintpalette.fill") }

            NavigationStack { BridgeView() }
                .tabItem { Label("Bridge", systemImage: "wifi.router.fill") }
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
