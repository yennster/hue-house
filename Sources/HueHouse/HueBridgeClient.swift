import Darwin
import Foundation

final class HueBridgeClient: @unchecked Sendable {
    private let host: String
    private let applicationKey: String?
    private let bridgeSession: URLSession

    init(host: String, applicationKey: String? = nil) {
        self.host = Self.normalizedHost(from: host)
        self.applicationKey = applicationKey
        self.bridgeSession = URLSession(
            configuration: .ephemeral,
            delegate: HueBridgeCertificateDelegate(allowedHost: Self.normalizedHost(from: host)),
            delegateQueue: nil
        )
    }

    static func normalizedHost(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let valueWithScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        if let host = URLComponents(string: valueWithScheme)?.host {
            return host
        }

        return trimmed
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/")
            .first
            .map(String.init) ?? trimmed
    }

    static func discoverBridges() async throws -> [HueBridgeDiscovery] {
        async let localResult = localDiscoveryResult()
        async let hueDiscoveryResult = hueDiscoveryResult()

        let results = await [localResult, hueDiscoveryResult]
        var discoveries: [HueBridgeDiscovery] = []

        for result in results {
            if case let .success(foundBridges) = result {
                discoveries.append(contentsOf: foundBridges)
            }
        }

        return uniqueDiscoveries(discoveries)
    }

    static func localDiscoveryDescription() -> String {
        guard let network = LocalIPv4Network.activeCandidates().first else {
            return "this Mac's current local network"
        }

        return network.displayLabel
    }

    private static func hueDiscoveryResult() async -> Result<[HueBridgeDiscovery], Error> {
        do {
            return .success(try await discoverBridgesFromHueDiscovery())
        } catch {
            return .failure(error)
        }
    }

    private static func localDiscoveryResult() async -> Result<[HueBridgeDiscovery], Error> {
        .success(await discoverLocalBridges())
    }

    private static func discoverBridgesFromHueDiscovery() async throws -> [HueBridgeDiscovery] {
        let url = URL(string: "https://discovery.meethue.com")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateHTTPResponse(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([HueBridgeDiscovery].self, from: data)
    }

    private static func discoverLocalBridges() async -> [HueBridgeDiscovery] {
        let addresses = LocalIPv4Network.activeCandidates()
            .flatMap { $0.hostAddresses(limit: 512) }

        guard !addresses.isEmpty else { return [] }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 0.85
        configuration.timeoutIntervalForResource = 0.85
        configuration.waitsForConnectivity = false

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        var discoveries: [HueBridgeDiscovery] = []
        let batchSize = 48

        for startIndex in stride(from: 0, to: addresses.count, by: batchSize) {
            let endIndex = min(startIndex + batchSize, addresses.count)

            await withTaskGroup(of: HueBridgeDiscovery?.self) { taskGroup in
                for ipAddress in addresses[startIndex..<endIndex] {
                    taskGroup.addTask {
                        await probeHueBridge(ipAddress: ipAddress, session: session)
                    }
                }

                for await discovery in taskGroup {
                    if let discovery {
                        discoveries.append(discovery)
                    }
                }
            }
        }

        return uniqueDiscoveries(discoveries)
    }

    private static func probeHueBridge(ipAddress: String, session: URLSession) async -> HueBridgeDiscovery? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = ipAddress
        components.path = "/api/config"

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 0.85
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTPResponse(response)

            let config = try JSONDecoder().decode(HueBridgeConfiguration.self, from: data)
            guard let bridgeID = config.bridgeID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !bridgeID.isEmpty
            else {
                return nil
            }

            let configuredIPAddress = config.ipAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
            return HueBridgeDiscovery(
                id: bridgeID.lowercased(),
                internalIPAddress: configuredIPAddress?.isEmpty == false ? configuredIPAddress! : ipAddress
            )
        } catch {
            return nil
        }
    }

    private static func uniqueDiscoveries(_ discoveries: [HueBridgeDiscovery]) -> [HueBridgeDiscovery] {
        var seenIDs = Set<String>()
        var seenAddresses = Set<String>()
        var unique: [HueBridgeDiscovery] = []

        for discovery in discoveries {
            let id = discovery.id.lowercased()
            let address = discovery.internalIPAddress

            guard !seenIDs.contains(id), !seenAddresses.contains(address) else {
                continue
            }

            seenIDs.insert(id)
            seenAddresses.insert(address)
            unique.append(discovery)
        }

        return unique.sorted {
            $0.internalIPAddress.localizedStandardCompare($1.internalIPAddress) == .orderedAscending
        }
    }

    func createApplicationKey() async throws -> String {
        let payload = try JSONSerialization.data(
            withJSONObject: ["devicetype": "HueHouse#Mac"],
            options: []
        )

        let entries: [HueCreateUserEntry] = try await bridgeRequest(
            method: "POST",
            path: "/api",
            body: payload,
            requiresApplicationKey: false
        )

        if let username = entries.compactMap(\.success?.username).first {
            return username
        }

        if let description = entries.compactMap(\.error?.description).first {
            throw HueAppError.bridgeRejected(description)
        }

        throw HueAppError.bridgeRejected("The bridge did not return an application key.")
    }

    func fetchLights() async throws -> [HueLight] {
        let response: HueResourceResponse<HueLight> = try await bridgeRequest(
            method: "GET",
            path: "/clip/v2/resource/light",
            body: nil,
            requiresApplicationKey: true
        )
        try response.throwIfNeeded()
        return response.data
    }

    func fetchGroups() async throws -> [HueLightGroup] {
        async let rooms = fetchGroupResource(path: "/clip/v2/resource/room")
        async let zones = fetchGroupResource(path: "/clip/v2/resource/zone")

        return try await rooms + zones
    }

    func setLight(id: String, on: Bool) async throws {
        let payload = try JSONSerialization.data(
            withJSONObject: ["on": ["on": on]],
            options: []
        )
        try await updateLight(id: id, payload: payload)
    }

    func setLight(id: String, brightness: Double) async throws {
        let clamped = min(100, max(1, brightness))
        let payload = try JSONSerialization.data(
            withJSONObject: ["dimming": ["brightness": clamped]],
            options: []
        )
        try await updateLight(id: id, payload: payload)
    }

    func applyPreset(_ preset: HuePreset, to id: String) async throws {
        guard let payload = preset.payload else { return }
        try await updateLight(id: id, payload: payload)
    }

    /// Sets a light's color from an sRGB triple. Supplying brightness routes
    /// the value into the same payload so the bridge applies both atomically.
    func setLight(
        id: String,
        red: Double,
        green: Double,
        blue: Double,
        brightness: Double? = nil
    ) async throws {
        let color = HueGradientColor.fromSRGB(red: red, green: green, blue: blue)
        var object: [String: Any] = [
            "on": ["on": true],
            "color": ["xy": ["x": color.x, "y": color.y]]
        ]
        if let brightness {
            object["dimming"] = ["brightness": min(100, max(1, brightness))]
        }
        let payload = try JSONSerialization.data(withJSONObject: object, options: [])
        try await updateLight(id: id, payload: payload)
    }

    func applyGradient(_ preset: HueGradientPreset, to light: HueLight, index: Int, total: Int) async throws {
        guard let payload = preset.payload(for: light, index: index, total: total) else {
            throw HueAppError.bridgeRejected("Could not build a gradient payload for \(light.name).")
        }

        try await updateLight(id: light.id, payload: payload)
    }

    private func fetchGroupResource(path: String) async throws -> [HueLightGroup] {
        let response: HueResourceResponse<HueLightGroup> = try await bridgeRequest(
            method: "GET",
            path: path,
            body: nil,
            requiresApplicationKey: true
        )
        try response.throwIfNeeded()
        return response.data
    }

    private func updateLight(id: String, payload: Data) async throws {
        let response: HueResourceResponse<HueUpdateResult> = try await bridgeRequest(
            method: "PUT",
            path: "/clip/v2/resource/light/\(id)",
            body: payload,
            requiresApplicationKey: true
        )
        try response.throwIfNeeded()
    }

    private func bridgeRequest<T: Decodable>(
        method: String,
        path: String,
        body: Data?,
        requiresApplicationKey: Bool
    ) async throws -> T {
        guard !host.isEmpty else { throw HueAppError.missingBridgeHost }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path

        guard let url = components.url else {
            throw HueAppError.invalidBridgeHost(host)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if requiresApplicationKey {
            guard let applicationKey else { throw HueAppError.missingApplicationKey }
            request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        }

        let (data, _) = try await Self.performWithRateLimitRetry(
            request: request,
            session: bridgeSession
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    /// Sends `request` and retries automatically when the bridge replies with
    /// HTTP 429 (its rate-limit response). The Hue Bridge accepts roughly ten
    /// writes/second; bursts beyond that trigger 429s that disappear after a
    /// short pause. Backoff respects the `Retry-After` header when present.
    private static func performWithRateLimitRetry(
        request: URLRequest,
        session: URLSession,
        maxAttempts: Int = 4
    ) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            attempt += 1
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (data, response)
            }

            if httpResponse.statusCode == 429, attempt < maxAttempts {
                let delay = retryDelay(from: httpResponse, attempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw HueAppError.httpStatus(httpResponse.statusCode)
            }
            return (data, response)
        }
    }

    private static func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HueAppError.httpStatus(httpResponse.statusCode)
        }
    }

    private static func retryDelay(from response: HTTPURLResponse, attempt: Int) -> Double {
        if let retryAfterHeader = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryAfterHeader) {
            return min(seconds, 5)
        }
        // Exponential backoff with jitter: ~0.4s, ~0.8s, ~1.6s.
        let base = 0.4 * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.15)
        return min(base + jitter, 3)
    }
}

private struct HueBridgeConfiguration: Decodable {
    let bridgeID: String?
    let ipAddress: String?

    private enum CodingKeys: String, CodingKey {
        case bridgeID = "bridgeid"
        case ipAddress = "ipaddress"
    }
}

private struct LocalIPv4Network {
    let interfaceName: String
    let address: UInt32
    let netmask: UInt32

    var displayLabel: String {
        "\(maskedAddress) on \(interfaceDisplayName)"
    }

    private var interfaceDisplayName: String {
        if interfaceName.hasPrefix("en") {
            return "Wi-Fi or Ethernet"
        }

        return interfaceName
    }

    private var maskedAddress: String {
        let octets = Self.octets(from: address)
        return "\(octets[0]).\(octets[1]).\(octets[2]).x"
    }

    private var networkAddress: UInt32 {
        address & netmask
    }

    private var broadcastAddress: UInt32 {
        networkAddress | ~netmask
    }

    private var hostCount: UInt32 {
        guard broadcastAddress > networkAddress + 1 else { return 0 }
        return broadcastAddress - networkAddress - 1
    }

    func hostAddresses(limit: Int) -> [String] {
        guard hostCount > 0 else { return [] }

        let scanNetwork: UInt32
        let scanBroadcast: UInt32

        if hostCount > UInt32(limit) {
            scanNetwork = address & 0xFFFF_FF00
            scanBroadcast = scanNetwork | 0x0000_00FF
        } else {
            scanNetwork = networkAddress
            scanBroadcast = broadcastAddress
        }

        let firstHost = scanNetwork + 1
        let lastHost = scanBroadcast - 1
        guard firstHost <= lastHost else { return [] }

        return (firstHost...lastHost)
            .filter { $0 != address }
            .map(Self.ipAddress(from:))
    }

    static func activeCandidates() -> [LocalIPv4Network] {
        var interfaceAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddress) == 0, let firstAddress = interfaceAddress else {
            return []
        }

        defer { freeifaddrs(interfaceAddress) }

        var networks: [LocalIPv4Network] = []

        for pointer in sequence(first: firstAddress, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let addressPointer = interface.ifa_addr,
                  let netmaskPointer = interface.ifa_netmask,
                  addressPointer.pointee.sa_family == UInt8(AF_INET)
            else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard isUsableInterface(name: name, flags: interface.ifa_flags) else {
                continue
            }

            let address = addressPointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let netmask = netmaskPointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }

            guard address != 0, netmask != 0 else { continue }

            networks.append(LocalIPv4Network(
                interfaceName: name,
                address: address,
                netmask: netmask
            ))
        }

        return unique(networks)
            .sorted { $0.priority < $1.priority }
    }

    private var priority: Int {
        if interfaceName == "en0" { return 0 }
        if interfaceName.hasPrefix("en") { return 1 }
        return 2
    }

    private static func isUsableInterface(name: String, flags: UInt32) -> Bool {
        guard flags & UInt32(IFF_UP) != 0,
              flags & UInt32(IFF_RUNNING) != 0,
              flags & UInt32(IFF_LOOPBACK) == 0
        else {
            return false
        }

        let ignoredPrefixes = [
            "awdl",
            "bridge",
            "gif",
            "llw",
            "lo",
            "p2p",
            "stf",
            "utun",
            "vmenet"
        ]

        return !ignoredPrefixes.contains { name.hasPrefix($0) }
    }

    private static func unique(_ networks: [LocalIPv4Network]) -> [LocalIPv4Network] {
        var seen = Set<String>()
        var uniqueNetworks: [LocalIPv4Network] = []

        for network in networks {
            let key = "\(network.networkAddress)-\(network.netmask)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            uniqueNetworks.append(network)
        }

        return uniqueNetworks
    }

    private static func ipAddress(from value: UInt32) -> String {
        let octets = octets(from: value)
        return "\(octets[0]).\(octets[1]).\(octets[2]).\(octets[3])"
    }

    private static func octets(from value: UInt32) -> [UInt32] {
        [
            (value >> 24) & 0xFF,
            (value >> 16) & 0xFF,
            (value >> 8) & 0xFF,
            value & 0xFF
        ]
    }
}

private final class HueBridgeCertificateDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let allowedHost: String

    init(allowedHost: String) {
        self.allowedHost = allowedHost
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.host == allowedHost,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }

        return (.useCredential, URLCredential(trust: serverTrust))
    }
}
