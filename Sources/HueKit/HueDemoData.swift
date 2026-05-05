import Foundation

/// In-memory fake bridge state used by `HueStore.enableDemoMode()`.
/// Lets the UI be exercised end-to-end without a real Hue Bridge on the network.
enum HueDemoData {
    static let bridgeHost = "demo.local"
    static let applicationKey = "demo-application-key"

    static let lights: [HueLight] = [
        makeLight(
            id: "demo-l1",
            ownerID: "demo-d1",
            name: "Sofa Lamp",
            on: true,
            brightness: 78,
            color: .init(x: 0.4317, y: 0.2018)  // pinkish red
        ),
        makeLight(
            id: "demo-l2",
            ownerID: "demo-d2",
            name: "Floor Lamp",
            on: true,
            brightness: 60,
            color: .init(x: 0.1690, y: 0.1410)  // cool blue
        ),
        makeGradientLight(
            id: "demo-l3",
            ownerID: "demo-d3",
            name: "TV Strip",
            on: true,
            brightness: 85
        ),
        makeLight(
            id: "demo-l4",
            ownerID: "demo-d4",
            name: "Bedside Left",
            on: false,
            brightness: 40,
            color: .init(x: 0.5142, y: 0.4111)  // warm amber
        ),
        makeWhiteLight(
            id: "demo-l5",
            ownerID: "demo-d5",
            name: "Closet",
            on: false,
            brightness: 100
        ),
    ]

    static let groups: [HueLightGroup] = [
        HueLightGroup(
            id: "demo-g1",
            type: "room",
            metadata: HueMetadata(name: "Living Room", archetype: "living_room"),
            children: [
                HueResourceReference(rid: "demo-d1", rtype: "device"),
                HueResourceReference(rid: "demo-d2", rtype: "device"),
                HueResourceReference(rid: "demo-d3", rtype: "device"),
            ]
        ),
        HueLightGroup(
            id: "demo-g2",
            type: "room",
            metadata: HueMetadata(name: "Bedroom", archetype: "bedroom"),
            children: [
                HueResourceReference(rid: "demo-d4", rtype: "device"),
                HueResourceReference(rid: "demo-d5", rtype: "device"),
            ]
        ),
    ]

    private static func makeLight(
        id: String,
        ownerID: String,
        name: String,
        on: Bool,
        brightness: Double,
        color: HueXY
    ) -> HueLight {
        HueLight(
            id: id,
            type: "light",
            owner: HueResourceReference(rid: ownerID, rtype: "device"),
            metadata: HueMetadata(name: name, archetype: "table_shade"),
            on: HueOnState(on: on),
            dimming: HueDimming(brightness: brightness, minDimLevel: 1),
            colorTemperature: HueColorTemperature(mirek: 366, mirekValid: true),
            color: HueColor(xy: color),
            gradient: nil
        )
    }

    private static func makeWhiteLight(
        id: String,
        ownerID: String,
        name: String,
        on: Bool,
        brightness: Double
    ) -> HueLight {
        HueLight(
            id: id,
            type: "light",
            owner: HueResourceReference(rid: ownerID, rtype: "device"),
            metadata: HueMetadata(name: name, archetype: "ceiling_round"),
            on: HueOnState(on: on),
            dimming: HueDimming(brightness: brightness, minDimLevel: 1),
            colorTemperature: HueColorTemperature(mirek: 300, mirekValid: true),
            color: nil,
            gradient: nil
        )
    }

    private static func makeGradientLight(
        id: String,
        ownerID: String,
        name: String,
        on: Bool,
        brightness: Double
    ) -> HueLight {
        let points = [
            HueGradientPoint(xy: HueXY(x: 0.6750, y: 0.3220)),
            HueGradientPoint(xy: HueXY(x: 0.4317, y: 0.2018)),
            HueGradientPoint(xy: HueXY(x: 0.1690, y: 0.1410)),
        ]
        return HueLight(
            id: id,
            type: "light",
            owner: HueResourceReference(rid: ownerID, rtype: "device"),
            metadata: HueMetadata(name: name, archetype: "hue_lightstrip"),
            on: HueOnState(on: on),
            dimming: HueDimming(brightness: brightness, minDimLevel: 1),
            colorTemperature: HueColorTemperature(mirek: 366, mirekValid: true),
            color: HueColor(xy: HueXY(x: 0.4317, y: 0.2018)),
            gradient: HueGradient(points: points, mode: "interpolated_palette", pointsCapable: 5, pixelCount: 24)
        )
    }
}
