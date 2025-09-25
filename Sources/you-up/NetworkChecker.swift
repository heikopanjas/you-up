//
//  NetworkChecker.swift
//
import Foundation
import Network
import SystemConfiguration

/// Configuration for internet test endpoints
public struct EndpointsConfiguration: Codable, Sendable {
    public let endpoints: [String]
    public let dnsTestDomains: [String]

    public init(endpoints: [String], dnsTestDomains: [String]? = nil) {
        self.endpoints = endpoints
        self.dnsTestDomains = dnsTestDomains ?? Self.defaultDNSTestDomains
    }

    // Custom decoding to handle backward compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.endpoints = try container.decode([String].self, forKey: .endpoints)
        self.dnsTestDomains = try container.decodeIfPresent([String].self, forKey: .dnsTestDomains) ?? Self.defaultDNSTestDomains
    }

    private enum CodingKeys: String, CodingKey {
        case endpoints
        case dnsTestDomains
    }

    /// Default internet test endpoints
    public static let defaultInternetEndpoints = [
        "https://dns.google",  // Google DNS over HTTPS
        "https://1.1.1.1",  // Cloudflare DNS
        "https://httpbin.org/get"  // Simple HTTP endpoint
    ]

    /// Default DNS test domains
    public static let defaultDNSTestDomains = [
        "google.com",  // Reliable, globally distributed
        "cloudflare.com",  // Good DNS infrastructure
        "example.com",  // Designed for testing
        "apple.com"  // Relevant for macOS users
    ]

    /// Default configuration with reliable endpoints
    public static let `default` = EndpointsConfiguration(
        endpoints: defaultInternetEndpoints,
        dnsTestDomains: defaultDNSTestDomains
    )
}

/// Configuration loader for you-up settings
public struct ConfigurationLoader {

    /// Load endpoints configuration from the user's config directory
    /// Checks $XDG_CONFIG_HOME/you-up/endpoints.json first, then falls back to $HOME/.config/you-up/endpoints.json
    public static func loadEndpointsConfiguration() -> EndpointsConfiguration {
        let configPath = getConfigFilePath()

        guard let configPath = configPath,
            FileManager.default.fileExists(atPath: configPath),
            let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
            let config = try? JSONDecoder().decode(EndpointsConfiguration.self, from: data)
        else {
            return .default
        }

        // Validate that we have at least one endpoint
        guard !config.endpoints.isEmpty else {
            return .default
        }

        return config
    }

    /// Get the path to the endpoints configuration file
    private static func getConfigFilePath() -> String? {
        let configDir: String

        // Check XDG_CONFIG_HOME first
        if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            configDir = "\(xdgConfigHome)/you-up"
        }
        else {
            // Fallback to ~/.config/you-up
            guard let homeDir = ProcessInfo.processInfo.environment["HOME"] else {
                return nil
            }
            configDir = "\(homeDir)/.config/you-up"
        }

        return "\(configDir)/endpoints.json"
    }

    /// Create a sample configuration file at the config path
    public static func createSampleConfiguration() throws {
        guard let configPath = getConfigFilePath() else {
            throw ConfigurationError.cannotDetermineConfigPath
        }

        let configDir = URL(fileURLWithPath: configPath).deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true, attributes: nil)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(EndpointsConfiguration.default)
        try data.write(to: URL(fileURLWithPath: configPath))
    }
}

/// Configuration-related errors
public enum ConfigurationError: Error, LocalizedError {
    case cannotDetermineConfigPath

    public var errorDescription: String? {
        switch self {
            case .cannotDetermineConfigPath:
                return "Cannot determine configuration directory path"
        }
    }
}

/// Represents the media type of a network interface
public enum NetworkMediaType: String, CaseIterable {
    case ethernet = "Ethernet"
    case wifi = "Wi-Fi"
    case cellular = "Cellular"
    case bluetooth = "Bluetooth"
    case thunderbolt = "Thunderbolt"
    case usb = "USB"
    case firewire = "FireWire"
    case bridge = "Bridge"
    case tunnel = "Tunnel"
    case loopback = "Loopback"
    case unknown = "Unknown"

    public var emoji: String {
        switch self {
            case .ethernet: return "🔌"
            case .wifi: return "📶"
            case .cellular: return "📱"
            case .bluetooth: return "🔵"
            case .thunderbolt: return "⚡"
            case .usb: return "🔌"
            case .firewire: return "🔥"
            case .bridge: return "🌉"
            case .tunnel: return "🚇"
            case .loopback: return "🔄"
            case .unknown: return "❓"
        }
    }
}

/// Represents router addresses for a network interface
public struct RouterAddresses {
    public let interface: String
    public let ipv4: String?
    public let ipv6: String?
    public let mediaType: NetworkMediaType

    public init(interface: String, ipv4: String?, ipv6: String?, mediaType: NetworkMediaType) {
        self.interface = interface
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.mediaType = mediaType
    }
}

/// Represents DNS server information
public struct DNSServerInfo: Sendable {
    public let address: String
    public let interface: String?
    public let isIPv6: Bool

    public init(address: String, interface: String?, isIPv6: Bool) {
        self.address = address
        self.interface = interface
        self.isIPv6 = isIPv6
    }
}

/// Represents the reachability status of different network components
public struct NetworkStatus: Sendable {
    public let gateway: ReachabilityStatus
    public let internet: ReachabilityStatus
    public let dns: ReachabilityStatus
    public let timestamp: Date

    public init(gateway: ReachabilityStatus, internet: ReachabilityStatus, dns: ReachabilityStatus, timestamp: Date = Date()) {
        self.gateway = gateway
        self.internet = internet
        self.dns = dns
        self.timestamp = timestamp
    }
}

/// Represents the reachability status of a network target
public enum ReachabilityStatus: Sendable, CustomStringConvertible {
    case reachable(latency: TimeInterval?)
    case unreachable
    case unknown
    case timeout

    public var description: String {
        switch self {
            case .reachable(let latency):
                if let latency = latency {
                    return "reachable (\(String(format: "%.0f", latency * 1000))ms)"
                }
                else {
                    return "reachable"
                }
            case .unreachable:
                return "unreachable"
            case .unknown:
                return "unknown"
            case .timeout:
                return "timeout"
        }
    }

    public var isReachable: Bool {
        if case .reachable = self {
            return true
        }
        return false
    }
}

/// Main class for checking network reachability
public final class NetworkChecker: Sendable {

    /// Default internet test endpoints (used as fallback)
    public static let defaultInternetTestEndpoints = [
        "https://dns.google",  // Google DNS over HTTPS
        "https://1.1.1.1",  // Cloudflare DNS
        "https://httpbin.org/get"  // Simple HTTP endpoint
    ]

    /// The endpoints configuration to use for internet connectivity testing
    private let endpointsConfig: EndpointsConfiguration

    public init(endpointsConfig: EndpointsConfiguration? = nil) {
        self.endpointsConfig = endpointsConfig ?? ConfigurationLoader.loadEndpointsConfiguration()
    }

    /// Get all active router addresses for network interfaces
    public func getActiveRouters() -> [RouterAddresses] {
        return getAllRouterAddresses()
    }

    /// Get the currently configured internet test endpoints
    public func getConfiguredEndpoints() -> [String] {
        return endpointsConfig.endpoints
    }

    /// Get the currently configured DNS test domains
    public func getConfiguredDNSTestDomains() -> [String] {
        return endpointsConfig.dnsTestDomains
    }

    /// Check both gateway and internet reachability
    public func checkNetworkStatus() async -> NetworkStatus {
        async let gatewayStatus = checkGatewayReachability()
        async let internetStatus = checkInternetReachability()
        async let dnsStatus = checkDNSReachability()

        return NetworkStatus(
            gateway: await gatewayStatus,
            internet: await internetStatus,
            dns: await dnsStatus
        )
    }

    /// Check if the default gateway/router is reachable
    public func checkGatewayReachability() async -> ReachabilityStatus {
        guard let gatewayIP = getDefaultGateway() else {
            return .unknown
        }

        return await ping(host: gatewayIP)
    }

    /// Check if general internet is reachable (using configured endpoints)
    public func checkInternetReachability() async -> ReachabilityStatus {
        // Try each host and return the first successful result
        for host in endpointsConfig.endpoints {
            let result = await httpCheck(url: host)
            if result.isReachable {
                return result
            }
        }

        return .unreachable
    }

    /// Check DNS resolution capability
    public func checkDNSReachability() async -> ReachabilityStatus {
        // Try to resolve each test domain and return the first successful result
        for domain in endpointsConfig.dnsTestDomains {
            let result = await dnsResolveCheck(domain: domain)
            if result.isReachable {
                return result
            }
        }

        return .unreachable
    }

    /// Ping a specific host to check reachability using HTTP
    private func httpCheck(url: String) async -> ReachabilityStatus {
        let startTime = Date()

        guard let url = URL(string: url) else {
            return .unreachable
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.httpMethod = "HEAD"  // Just check headers, don't download content

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
                (200 ... 299).contains(httpResponse.statusCode)
            {
                let latency = Date().timeIntervalSince(startTime)
                return .reachable(latency: latency)
            }
            else {
                return .unreachable
            }
        }
        catch {
            if error.localizedDescription.contains("timeout") {
                return .timeout
            }
            return .unreachable
        }
    }

    /// Check DNS resolution for a specific domain
    private func dnsResolveCheck(domain: String) async -> ReachabilityStatus {
        let startTime = Date()

        // Use a simple HTTP HEAD request to trigger DNS resolution
        // This tests both DNS resolution and basic connectivity
        guard let url = URL(string: "http://\(domain)") else {
            return .unreachable
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.httpMethod = "HEAD"

        do {
            // This will trigger DNS resolution as part of the HTTP request
            let (_, response) = try await URLSession.shared.data(for: request)

            let latency = Date().timeIntervalSince(startTime)

            // We don't care about the HTTP status code, just that DNS resolved
            // and we could establish a connection
            if response is HTTPURLResponse {
                // Any response means DNS worked
                return .reachable(latency: latency)
            }
            else {
                // Non-HTTP response, but still means DNS resolution worked
                return .reachable(latency: latency)
            }
        }
        catch {
            if error.localizedDescription.contains("timeout") {
                return .timeout
            }
            else if error.localizedDescription.contains("could not be resolved")
                || error.localizedDescription.contains("host name could not be resolved")
            {
                return .unreachable
            }
            else {
                // Other errors (connection refused, etc.) still mean DNS worked
                let latency = Date().timeIntervalSince(startTime)
                return .reachable(latency: latency)
            }
        }
    }

    /// Get configured DNS servers from system settings
    public func getDNSServers() -> [DNSServerInfo] {
        var dnsServers: [DNSServerInfo] = []

        guard let dynamicStore = SCDynamicStoreCreate(nil, "GetDNSServers" as CFString, nil, nil) else {
            return []
        }

        // Get global DNS configuration
        if let globalDNS = SCDynamicStoreCopyValue(dynamicStore, "State:/Network/Global/DNS" as CFString) as? [String: Any],
            let servers = globalDNS["ServerAddresses"] as? [String]
        {
            for server in servers {
                dnsServers.append(
                    DNSServerInfo(
                        address: server,
                        interface: nil,
                        isIPv6: server.contains(":")
                    ))
            }
        }

        // Get per-service DNS configuration
        let dnsPattern = "State:/Network/Service/[^/]+/DNS" as CFString
        if let dnsServices = SCDynamicStoreCopyKeyList(dynamicStore, dnsPattern) as? [String] {
            for serviceKey in dnsServices {
                guard let dnsInfo = SCDynamicStoreCopyValue(dynamicStore, serviceKey as CFString) as? [String: Any],
                    let servers = dnsInfo["ServerAddresses"] as? [String]
                else {
                    continue
                }

                let interfaceName = dnsInfo["InterfaceName"] as? String

                for server in servers {
                    // Avoid duplicates from global DNS
                    let serverInfo = DNSServerInfo(
                        address: server,
                        interface: interfaceName,
                        isIPv6: server.contains(":")
                    )

                    if !dnsServers.contains(where: { $0.address == serverInfo.address }) {
                        dnsServers.append(serverInfo)
                    }
                }
            }
        }

        return dnsServers
    }
    private func ping(host: String) async -> ReachabilityStatus {
        let startTime = Date()

        guard let url = URL(string: "http://\(host)") else {
            return .unreachable
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.httpMethod = "HEAD"

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            let latency = Date().timeIntervalSince(startTime)
            return .reachable(latency: latency)
        }
        catch {
            if error.localizedDescription.contains("timeout") {
                return .timeout
            }
            return .unreachable
        }
    }

    /// Get the default gateway IP address using SystemConfiguration
    private func getDefaultGateway() -> String? {
        let routerAddresses = getAllRouterAddresses()

        // Prefer active interfaces with IPv4 routers, fall back to IPv6
        for router in routerAddresses {
            if let ipv4 = router.ipv4 {
                return ipv4
            }
        }

        // If no IPv4 router found, try IPv6
        for router in routerAddresses {
            if let ipv6 = router.ipv6 {
                return ipv6
            }
        }

        return nil
    }

    /// Determine the media type of a network interface
    private func getInterfaceMediaType(_ interfaceName: String) -> NetworkMediaType {
        // First try to get detailed information from SystemConfiguration
        if let detailedType = getDetailedInterfaceType(interfaceName) {
            return detailedType
        }

        // Fall back to interface naming patterns on macOS
        if interfaceName.starts(with: "en") {
            // en0, en1, etc. - default to ethernet if we can't determine specifics
            return .ethernet
        }
        else if interfaceName.starts(with: "wi") || interfaceName.starts(with: "wl") {
            return .wifi
        }
        else if interfaceName.starts(with: "pdp_ip") || interfaceName.starts(with: "cellular") {
            return .cellular
        }
        else if interfaceName.starts(with: "utun") || interfaceName.starts(with: "tun") {
            return .tunnel
        }
        else if interfaceName.starts(with: "bridge") {
            return .bridge
        }
        else if interfaceName.starts(with: "lo") {
            return .loopback
        }
        else if interfaceName.starts(with: "fw") {
            return .firewire
        }
        else if interfaceName.starts(with: "usb") {
            return .usb
        }
        else if interfaceName.starts(with: "thunderbolt") {
            return .thunderbolt
        }
        else {
            return .unknown
        }
    }

    /// Get detailed interface type using SystemConfiguration
    private func getDetailedInterfaceType(_ interfaceName: String) -> NetworkMediaType? {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "GetInterfaceType" as CFString, nil, nil) else {
            return nil
        }

        // Try to get the service name and user-defined name
        let servicesPattern = "Setup:/Network/Service/[^/]+/Interface" as CFString
        guard let serviceKeys = SCDynamicStoreCopyKeyList(dynamicStore, servicesPattern) as? [String] else {
            return nil
        }

        for serviceKey in serviceKeys {
            guard let serviceInfo = SCDynamicStoreCopyValue(dynamicStore, serviceKey as CFString) as? [String: Any],
                let deviceName = serviceInfo["DeviceName"] as? String,
                deviceName == interfaceName
            else {
                continue
            }

            // Get the service ID from the key path
            let keyComponents = serviceKey.components(separatedBy: "/")
            guard keyComponents.count >= 4 else { continue }
            let serviceID = keyComponents[3]

            // Check the service setup for user-defined name
            let serviceSetupKey = "Setup:/Network/Service/\(serviceID)"
            if let serviceSetup = SCDynamicStoreCopyValue(dynamicStore, serviceSetupKey as CFString) as? [String: Any],
                let userDefinedName = serviceSetup["UserDefinedName"] as? String
            {

                // Use the user-defined name to determine interface type
                let lowercaseName = userDefinedName.lowercased()

                if lowercaseName.contains("wi-fi") || lowercaseName.contains("wifi") || lowercaseName.contains("airport") {
                    return .wifi
                }
                else if lowercaseName.contains("thunderbolt") {
                    return .thunderbolt
                }
                else if lowercaseName.contains("ethernet") {
                    return .ethernet
                }
                else if lowercaseName.contains("usb") {
                    return .usb
                }
                else if lowercaseName.contains("bluetooth") {
                    return .bluetooth
                }
                else if lowercaseName.contains("cellular") || lowercaseName.contains("mobile") {
                    return .cellular
                }
            }

            // Also check the hardware type
            if let hardware = serviceInfo["Hardware"] as? String {
                let lowercaseHardware = hardware.lowercased()
                if lowercaseHardware.contains("airport") || lowercaseHardware.contains("wifi") {
                    return .wifi
                }
                else if lowercaseHardware.contains("ethernet") {
                    return .ethernet
                }
            }
        }

        // Also try the link information
        let interfaceKey = "State:/Network/Interface/\(interfaceName)/Link" as CFString
        if let linkInfo = SCDynamicStoreCopyValue(dynamicStore, interfaceKey) as? [String: Any],
            let active = linkInfo["Active"] as? Bool, active
        {

            // Check for Wi-Fi specific indicators
            if linkInfo["SSID"] != nil {
                return .wifi
            }
        }

        return nil
    }

    /// Get all router addresses for active network interfaces
    private func getAllRouterAddresses() -> [RouterAddresses] {
        var routerDict: [String: RouterAddresses] = [:]

        guard let dynamicStore = SCDynamicStoreCreate(nil, "GetRouterIPs" as CFString, nil, nil) else {
            return []
        }

        // Process IPv4
        let ipv4Pattern = "State:/Network/Service/[^/]+/IPv4" as CFString
        if let ipv4Services = SCDynamicStoreCopyKeyList(dynamicStore, ipv4Pattern) as? [String] {
            for serviceKey in ipv4Services {
                guard let ipv4Info = SCDynamicStoreCopyValue(dynamicStore, serviceKey as CFString) as? [String: Any],
                    let interfaceName = ipv4Info["InterfaceName"] as? String,
                    let routerIP = ipv4Info["Router"] as? String
                else {
                    continue
                }

                routerDict[interfaceName] = RouterAddresses(
                    interface: interfaceName,
                    ipv4: routerIP,
                    ipv6: nil,
                    mediaType: getInterfaceMediaType(interfaceName)
                )
            }
        }

        // Process IPv6
        let ipv6Pattern = "State:/Network/Service/[^/]+/IPv6" as CFString
        if let ipv6Services = SCDynamicStoreCopyKeyList(dynamicStore, ipv6Pattern) as? [String] {
            for serviceKey in ipv6Services {
                guard let ipv6Info = SCDynamicStoreCopyValue(dynamicStore, serviceKey as CFString) as? [String: Any],
                    let interfaceName = ipv6Info["InterfaceName"] as? String,
                    let routerIP = ipv6Info["Router"] as? String
                else {
                    continue
                }

                if let existing = routerDict[interfaceName] {
                    routerDict[interfaceName] = RouterAddresses(
                        interface: interfaceName,
                        ipv4: existing.ipv4,
                        ipv6: routerIP,
                        mediaType: existing.mediaType
                    )
                }
                else {
                    routerDict[interfaceName] = RouterAddresses(
                        interface: interfaceName,
                        ipv4: nil,
                        ipv6: routerIP,
                        mediaType: getInterfaceMediaType(interfaceName)
                    )
                }
            }
        }

        return Array(routerDict.values)
    }
}
