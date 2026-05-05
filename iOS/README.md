# Hue House for iOS

iOS app target that ships the same Hue networking, gradient, and color logic as the macOS app — packaged for iPhone and iPad.

## Layout

The Swift source files in this directory are **not** built by `swift build` (SwiftPM can't produce iOS app bundles). They're meant to be wired into an Xcode iOS app target that depends on the `HueKit` SwiftPM library at the repository root.

```
iOS/
  README.md                    ← you are here
  HueHouseiOS/
    HueHouseiOSApp.swift       SwiftUI App entry point
    RootView.swift             TabView with Lights / Gradients / Bridge tabs
    LightsView.swift           Group picker + light list with on/off + brightness
    LightDetailView.swift      Per-light controls (brightness, color, presets)
    RGBAColorSheet.swift       Sheet-presented RGBA color picker
    GradientsView.swift        Built-in palettes + custom gradients + apply
    ImportGradientSheet.swift  CSS gradient / comma color list importer
    BridgeView.swift           Pairing flow + bridge status + appearance
    Info.plist                 iOS bundle metadata, NSLocalNetworkUsageDescription, NSBonjourServices
```

All view code uses `import HueKit` to talk to the shared store, models, and bridge client. There is no AppKit anywhere in this directory.

## Setting up the Xcode app target

1. Open Xcode.
2. **File → New → Project → iOS → App.** Product name `Hue House`, organization identifier of your choice (e.g. `local.huehouse`), interface **SwiftUI**, language **Swift**. Save it under `iOS/` so the project lives next to this README.
3. Delete Xcode's auto-generated `ContentView.swift` and `*App.swift`. Drag the eight `.swift` files from `iOS/HueHouseiOS/` into the project navigator (uncheck "Copy items if needed" so they stay version-controlled at this path).
4. Replace the default `Info.plist` with the one in `iOS/HueHouseiOS/Info.plist` — it already declares `NSLocalNetworkUsageDescription`, the Bonjour service types Philips Hue advertises, and ATS local-networking opt-in.
5. **File → Add Package Dependencies… → Add Local…** and pick the repository root. Add the `HueKit` library product to the new app target.
6. In the target's **Signing & Capabilities**, sign with your Apple Developer team (required to run on a real device). Background modes / network entitlements are not needed.

## Running

- **Simulator**: pick an iPhone simulator and `⌘R`. The Local Network permission prompt fires the first time the Bridge tab attempts discovery.
- **Device**: requires Apple Developer membership ($99/yr) for signing. Free Personal Team certificates work too but expire after 7 days.

## Notes / known gaps

- iOS has no menu bar, no Dock — the macOS-only `MenuBarExtra` and the "Hide Dock icon" toggle do not exist here.
- Siri / Shortcuts (App Intents) are scoped to the macOS executable target. Adding iOS Shortcuts means re-declaring the intents in the iOS target with `import HueKit` so they reuse `HueAutomationService`.
- The Liquid Glass material treatment from macOS isn't replicated; the iOS UI uses standard system materials and `.insetGrouped` Form / List styles instead.
- Local Network permission can get stuck in the "denied" state if the user dismisses the prompt without choosing. Reset via **Settings → Hue House → Local Network**.
