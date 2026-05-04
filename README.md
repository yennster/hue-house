# Hue House

A small native macOS app for controlling Philips Hue lights on your local network.

## Run

```sh
swift run HueHouse
```

## Build an App Bundle

```sh
sh Scripts/package-app.sh
open .build/HueHouse.app
```

The bundle script also generates App Intents metadata when full Xcode is installed, which is what Shortcuts and Siri use to discover Hue House actions.

## First Pairing

1. Click `Discover`, or enter your Hue Bridge IP address manually.
2. Press the physical link button on the Hue Bridge.
3. Click `Pair Bridge`.

The app stores the bridge IP in `UserDefaults` and the Hue application key in the macOS Keychain.

## Current Controls

- Discover Hue Bridges through the official Hue discovery endpoint.
- Pair this Mac with the bridge.
- List lights, rooms, and zones through the local Hue API v2.
- Toggle individual lights.
- Change brightness.
- Apply warm, cool, red, green, and blue presets.
- Apply prebuilt gradient palettes to all lights in a selected room, zone, or the whole house.
- Turn all lights on or off.
- Use the native macOS top toolbar menu for quick group, gradient, preset, and bridge actions.

## Gradient Studio

Gradient Studio includes six built-in palettes:

- Aurora Veil
- Solstice Glass
- Midnight Lagoon
- Glass Garden
- Ember Bloom
- Opal Mist

Hue gradient-capable lights receive multi-point gradient payloads. Standard color bulbs receive distributed colors from the selected palette, so rooms still feel like one coordinated gradient.

The top toolbar's `Hue Controls` menu can apply a gradient immediately: pick a room or zone, then choose a palette from the dropdown.

## Liquid Glass

On macOS versions that include Apple's Liquid Glass SwiftUI APIs, custom panels use `glassEffect`. Older macOS versions fall back to native translucent materials so the app still runs on macOS 14 and later.

## Siri and Shortcuts

Hue House exposes App Shortcuts for Siri:

- `Turn on Hue House`
- `Turn off Hue House`
- `Turn on Kitchen with Hue House`
- `Turn off Kitchen with Hue House`
- `Set Hue House to Aurora Veil`
- `Apply Midnight Lagoon with Hue House`
- `Apply a gradient to Kitchen with Hue House`

Room and zone names come from the Hue Bridge. Siri actions use the bridge IP stored in `UserDefaults` and the application key stored in Keychain, so pair the app once before using voice control.
