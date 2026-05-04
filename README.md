<h1 align="center">Hue House</h1>

<p align="center">
  A native macOS control surface for Philips Hue lights, gradients, Siri, and Shortcuts.
</p>

<p align="center">
  <a href="https://github.com/yennster/hue-house/releases">
    <img alt="Version" src="https://img.shields.io/badge/version-0.2.0-black?style=for-the-badge">
  </a>
  <a href="https://www.swift.org">
    <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6.0-black?style=for-the-badge&logo=swift">
  </a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?style=for-the-badge&logo=apple">
  <a href="https://github.com/yennster/hue-house/stargazers">
    <img alt="GitHub stars" src="https://img.shields.io/github/stars/yennster/hue-house?style=for-the-badge">
  </a>
  <a href="https://github.com/yennster/hue-house/blob/main/LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/yennster/hue-house?style=for-the-badge">
  </a>
  <img alt="Last commit" src="https://img.shields.io/github/last-commit/yennster/hue-house?style=for-the-badge">
</p>

<p align="center">
  <a href="#highlights">Highlights</a>
  <span> - </span>
  <a href="#install">Install</a>
  <span> - </span>
  <a href="#pair-your-bridge">Pair</a>
  <span> - </span>
  <a href="#gradient-studio">Gradients</a>
  <span> - </span>
  <a href="#siri-and-shortcuts">Siri</a>
  <span> - </span>
  <a href="#packaging">Packaging</a>
</p>

## Highlights

Hue House is a SwiftUI Mac app for finding a Philips Hue Bridge on your local network, pairing with it once, and controlling the lights in your house from a polished Apple-style interface.

| Area | What it does |
| --- | --- |
| Bridge setup | Automatic local-network scan with Hue cloud discovery as a fallback. Manual IP entry is tucked away as an escape hatch. |
| Light controls | Toggle each light, scrub brightness, and apply quick-color presets (Warm, Cool, Red, Green, Blue). All On / All Off act on the currently-selected room or zone. |
| Per-light RGBA picker | Each color-capable light has an in-app color popover with R, G, B, and A (alpha-as-brightness) sliders. The preview seeds from the bulb's actual current color via the Hue API. |
| Rooms and zones | Pick the whole house, a room, or a Hue zone before applying actions. The light list and toolbar buttons all scope to the selection. |
| Gradient Studio | Six built-in multi-color palettes plus a CSS gradient importer for unlimited custom palettes. Custom palettes persist across launches. |
| Resilient bridge calls | Concurrent writes are capped to stay under the bridge's rate ceiling, HTTP 429 retries with exponential backoff, and per-light failures are quietly added to a session skip-list so subsequent applies don't waste effort on bulbs the bridge keeps refusing. |
| Menu bar dropdown | A `MenuBarExtra` provides a compact room picker, All On / All Off, gradients, and quick colors without opening the main window. |
| Siri and Shortcuts | App Intents expose lighting actions to Siri, Shortcuts, and Spotlight. |
| Apple-style UI | Liquid Glass on macOS 26, material fallbacks on macOS 14+, monotone SF Symbols, and a Light / Dark / System appearance picker. Custom Liquid Glass app icon. |

## Install

### From a release build (recommended)

1. Download `HueHouse-vX.Y.Z.zip` from the [Releases page](https://github.com/yennster/hue-house/releases) and unzip it.
2. Drag `HueHouse.app` into `/Applications`.
3. The bundle is ad-hoc signed but **not notarized**, so the first launch needs a Gatekeeper bypass:
   - **Right-click `HueHouse.app` → Open**, then click **Open** in the dialog. macOS remembers the choice for future launches.
   - If macOS shows `"HueHouse" is damaged and can't be opened` (the browser added a quarantine flag that blocks even right-click → Open), strip the flag once in Terminal:
     ```sh
     xattr -cr /Applications/HueHouse.app
     ```

### From source

```sh
git clone https://github.com/yennster/hue-house.git
cd hue-house
swift run HueHouse
```

`swift run` launches the binary without building an `.app` bundle, so the Dock icon will show the generic Swift placeholder instead of the Hue House icon. Use `Scripts/package-app.sh` (see [Packaging](#packaging)) to build a proper bundle.

## Pair your bridge

1. Open Hue House.
2. Let the app search the Mac's current Wi-Fi or Ethernet network. Discovered bridges appear in the right column.
3. Select your bridge.
4. Press the physical **link** button on the Hue Bridge.
5. Click `Pair Bridge` within 30 seconds.

Hue House stores the bridge IP address in `UserDefaults` and the Hue application key in the macOS Keychain. After pairing, the Bridge tab condenses to a status card; the new **Lights** tab becomes the primary working surface.

If automatic discovery can't see the bridge, expand **Manual IP address** in the Bridge tab and type the bridge's IPv4 address directly.

## Gradient Studio

### Built-in palettes

- **Aurora Veil** — mint, teal, violet
- **Solstice Glass** — rose, peach, gold
- **Midnight Lagoon** — cyan, blue, indigo
- **Glass Garden** — lime, jade, sky
- **Ember Bloom** — coral, ruby, violet
- **Opal Mist** — lavender, pearl, aqua

Gradient-capable Hue lights (Lightstrip Plus, Play, Festavia, etc.) receive a multi-point gradient payload. Standard color bulbs receive distributed colors from the same palette so a mixed room still reads as one coordinated scene.

### Importing CSS gradients

Click **Import CSS Gradient** at the bottom of the palette list. Paste any standard CSS gradient — `linear-gradient`, `radial-gradient`, or `conic-gradient` — and the app extracts the color stops, converts each from sRGB to CIE 1931 xy chromaticity (the same color space the bridge expects), and saves it as a custom palette.

```
linear-gradient(90deg, rgba(131,58,180,1) 0%, rgba(253,29,29,1) 50%, rgba(252,176,69,1) 100%)
```

Hex (`#ff0080`, `#fff`), `rgb()` / `rgba()`, and named colors (`coral`, `indigo`, `hotpink`, …) are all supported. Direction tokens (`90deg`, `to right`) and stop positions (`50%`) are accepted but ignored — Hue gradients only consume the ordered color list. Custom palettes appear in both the main window and the menu bar dropdown, are persisted in `UserDefaults`, and can be deleted from the palette row.

### Reliability

- Gradient apply runs at most four bridge writes in flight at once.
- HTTP 429 (rate-limit) responses are retried automatically with exponential backoff, honoring `Retry-After` when the bridge sends one.
- A bulb that fails (network glitch, communication error, etc.) is added to an in-memory session skip-list. Subsequent gradient / All On / All Off / preset applies in the same session quietly route around it. An inline "N skipped this session" badge in Gradient Studio offers a one-click reset.

## Per-light RGBA color picker

Each color-capable light row has a small color swatch on the right with an eyedropper icon. Clicking it opens an in-app popover containing:

- A live preview of the chosen color over a checkerboard so the alpha channel reads naturally
- The current `#RRGGBBAA` hex value
- Sliders for **R**, **G**, **B** (0–255) and **A** (0–100, mapped to bulb brightness; A = 0 turns the bulb off)
- The preview seeds from the bulb's *actual* current xy + brightness via the Hue API, so the popover shows what the bulb is doing right now rather than a generic default

Sliders apply on release, so you can scrub freely without rate-limiting the bridge.

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

## Menu bar

When Hue House is running, a lightbulb glyph appears in the macOS menu bar. Clicking it opens a 320pt-wide window with:

- The current room/zone picker
- All On / All Off
- The full gradient palette (built-ins plus your custom CSS imports)
- Quick-color presets
- Refresh, Open App, and Quit actions

The same `HueStore` powers both the menu bar and the main window, so changes in either are reflected instantly in the other.

## Packaging

Build a standalone, ad-hoc-signed app bundle:

```sh
sh Scripts/package-app.sh
open .build/HueHouse.app
```

The packaging script:

- Builds the release executable with SwiftPM.
- Creates `.build/HueHouse.app`.
- Copies `Packaging/Info.plist` and the bundled `AppIcon.icns`.
- Generates App Intents metadata when full Xcode tooling is installed.
- Ad-hoc signs the bundle (`codesign --sign -`) so recent macOS launches the app via right-click → Open instead of refusing it as "damaged."

For a fully frictionless launch (no Gatekeeper prompt at all), the bundle would need to be signed with an Apple Developer ID and notarized — that requires Apple Developer Program membership.

## Project Structure

```text
Sources/HueHouse/
  ContentView.swift            Main SwiftUI interface, tabs, light list, RGBA popover
  HueHouseApp.swift            App entry point, MenuBarExtra, command groups
  HueMenuBarView.swift         Menu bar dropdown UI
  HueBridgeClient.swift        Hue discovery, pairing, and local API client (with 429 retry)
  HueStore.swift               Main app state, light actions, batch update orchestration
  HueModels.swift              Hue API response types, preset/gradient models, sRGB ↔ xy math
  HueCSSGradient.swift         CSS linear-gradient parser
  HueAppearanceMode.swift      Light / Dark / System appearance handling
  HueAppError.swift            Error formatting for user-facing alerts
  HueSiriIntents.swift         Siri and Shortcuts App Intents
  HueAppStorage.swift          UserDefaults key constants
  KeychainStore.swift          Hue application key storage
  VisualStyle.swift            Liquid Glass / material styling and shared theme tokens
Packaging/
  Info.plist                   App bundle metadata and privacy descriptions
  AppIcon.icns                 Generated multi-resolution app icon
  AppIcon-1024.png             Master icon source (importable into Icon Composer)
Scripts/
  package-app.sh               Release app bundle builder + ad-hoc signer
  generate-icon.swift          Layered Liquid Glass icon generator (CoreGraphics)
```

## Privacy

Hue House talks directly to the Hue Bridge on your local network. The app does not run a backend service or send any data to third parties. Pairing data stays on the Mac:

- Bridge IP address: `UserDefaults`
- Hue application key: macOS Keychain
- Custom CSS palettes: `UserDefaults` (JSON-encoded)
- Session skip-list: in-memory only, cleared on relaunch or `Forget Bridge`

Network access is limited to the Hue Bridge IP and `discovery.meethue.com` for cloud-assisted discovery; the latter is only contacted during pairing if local-network discovery fails.

## Versioning

Current app version: `0.2.0`

Release builds use the `CFBundleShortVersionString` and `CFBundleVersion` values in `Packaging/Info.plist`. Tag GitHub releases with semantic versions such as `v0.2.0` so the repository badges, release notes, and app bundle version stay aligned.

## Support

If Hue House makes your mornings a little brighter, a coffee tip is always appreciated, never required.

<p align="center">
  <a href="https://www.buymeacoffee.com/yennster"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=☕&slug=yennster&button_colour=ec5fb2&font_colour=ffffff&font_family=Cookie&outline_colour=000000&coffee_colour=FFDD00" /></a>
</p>
