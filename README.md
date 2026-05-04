<h1 align="center">Hue House</h1>

<p align="center">
  A native macOS control surface for Philips Hue lights, gradients, Siri, and Shortcuts.
</p>

<p align="center">
  <a href="https://github.com/yennster/philips-hue-mac-app/releases">
    <img alt="Version" src="https://img.shields.io/badge/version-0.1.0-black?style=for-the-badge">
  </a>
  <a href="https://www.swift.org">
    <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6.0-black?style=for-the-badge&logo=swift">
  </a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?style=for-the-badge&logo=apple">
  <a href="https://github.com/yennster/philips-hue-mac-app/stargazers">
    <img alt="GitHub stars" src="https://img.shields.io/github/stars/yennster/philips-hue-mac-app?style=for-the-badge">
  </a>
  <a href="https://github.com/yennster/philips-hue-mac-app/blob/main/LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/yennster/philips-hue-mac-app?style=for-the-badge">
  </a>
  <img alt="Last commit" src="https://img.shields.io/github/last-commit/yennster/philips-hue-mac-app?style=for-the-badge">
  <a href="https://buymeacoffee.com/yennster">
    <img alt="Buy Me a Coffee" src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-yennster-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black">
  </a>
</p>

<p align="center">
  <a href="#highlights">Highlights</a>
  <span> - </span>
  <a href="#quick-start">Quick Start</a>
  <span> - </span>
  <a href="#siri-and-shortcuts">Siri</a>
  <span> - </span>
  <a href="#packaging">Packaging</a>
</p>

## Highlights

Hue House is a small SwiftUI Mac app for finding a Philips Hue Bridge on your current network, pairing with it once, and controlling the lights in your house from a polished Apple-style interface.

| Area | What it does |
| --- | --- |
| Bridge setup | Automatically scans the current local network, then falls back to Hue discovery. Manual IP entry is tucked away as an escape hatch. |
| Light controls | Toggle lights, adjust brightness, turn everything on or off, and apply quick color presets. |
| Rooms and zones | Pick the whole house, a room, or a Hue zone before applying actions. |
| Gradient Studio | Apply built-in multi-color palettes across every light in the selected group. |
| Siri and Shortcuts | Exposes App Intents so Siri can turn lights on/off and apply gradients by voice. |
| Apple-style UI | Liquid Glass when available, material fallbacks on macOS 14+, monotone symbols, and system/light/dark appearance modes. |

## Gradient Studio

Hue House ships with six built-in palettes:

- Aurora Veil
- Solstice Glass
- Midnight Lagoon
- Glass Garden
- Ember Bloom
- Opal Mist

Gradient-capable Hue lights receive multi-point gradient payloads. Standard color bulbs receive distributed colors from the same palette, so a mixed room still reads like one coordinated scene.

## Quick Start

### Requirements

- macOS 14 or newer
- Swift 6 toolchain
- Xcode for packaged App Intents metadata
- A Philips Hue Bridge on the same local network

### Run from source

```sh
swift run HueHouse
```

### Pair your bridge

1. Open Hue House.
2. Let the app search the Mac's current Wi-Fi or Ethernet network.
3. Select the discovered bridge.
4. Press the physical link button on the Hue Bridge.
5. Click `Pair Bridge`.

Hue House stores the bridge IP address in `UserDefaults` and the Hue application key in the macOS Keychain.

## Siri and Shortcuts

Hue House exposes App Shortcuts for common lighting actions:

```text
Turn on Hue House
Turn off Hue House
Turn on Kitchen with Hue House
Turn off Kitchen with Hue House
Set Hue House to Aurora Veil
Apply Midnight Lagoon with Hue House
Apply a gradient to Kitchen with Hue House
```

Room and zone names come from your Hue Bridge. Pair the app once before using voice control so Siri can reuse the stored bridge IP and application key.

## Packaging

Build a standalone app bundle:

```sh
sh Scripts/package-app.sh
open .build/HueHouse.app
```

The packaging script:

- Builds the release executable with SwiftPM.
- Creates `.build/HueHouse.app`.
- Copies `Packaging/Info.plist`.
- Generates App Intents metadata when full Xcode tooling is installed.

## Project Structure

```text
Sources/HueHouse/
  ContentView.swift            SwiftUI interface and controls
  HueBridgeClient.swift        Hue discovery, pairing, and local API requests
  HueStore.swift               Main app state and light actions
  HueModels.swift              Hue API response and preset models
  HueSiriIntents.swift         Siri and Shortcuts App Intents
  VisualStyle.swift            Liquid Glass and adaptive visual styling
Packaging/Info.plist           App bundle metadata and privacy descriptions
Scripts/package-app.sh         Release app bundle builder
```

## Privacy

Hue House talks directly to the Hue Bridge on your local network. The app does not run a backend service. Pairing data stays on the Mac:

- Bridge IP address: `UserDefaults`
- Hue application key: macOS Keychain

## Versioning

Current app version: `0.1.0`

Release builds use the `CFBundleShortVersionString` and `CFBundleVersion` values in `Packaging/Info.plist`. Tag GitHub releases with semantic versions such as `v0.1.0` so the repository badges, release notes, and app bundle version stay aligned.

## Support

If Hue House makes your mornings a little brighter, you can [buy me a coffee](https://buymeacoffee.com/yennster). Always appreciated, never required.
