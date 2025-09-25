//
//  NetworkChecker.swift
//
import Foundation
import Network
import SystemConfiguration

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

    /// Default internet endpoints (used as fallback)
    public static let defaultInternetEndpoints = [
        "https://dns.google",  // Google DNS over HTTPS
        "https://1.1.1.1",  // Cloudflare DNS
        "https://httpbin.org/get"  // Simple HTTP endpoint
    ]

    /// The endpoints configuration to use for connectivity testing
    private let endpointsConfig: EndpointsConfiguration

    /// Individual check instances
    private let gatewayCheck: GatewayCheck
    private let internetCheck: InternetCheck
    private let dnsCheck: DNSCheck

    public init(endpointsConfig: EndpointsConfiguration? = nil) {
        self.endpointsConfig = endpointsConfig ?? ConfigurationLoader.loadEndpointsConfiguration()

        // Initialize individual check instances
        self.gatewayCheck = GatewayCheck()
        self.internetCheck = InternetCheck(config: self.endpointsConfig)
        self.dnsCheck = DNSCheck(config: self.endpointsConfig)
    }

    /// Get all active router addresses for network interfaces
    public func getActiveRouters() -> [RouterAddresses] {
        return gatewayCheck.getGatewayAddresses()
    }

    /// Get the currently configured internet endpoints
    public func getConfiguredEndpoints() -> [String] {
        return internetCheck.getEndpoints()
    }

    /// Get the currently configured DNS domains
    public func getConfiguredDNSDomains() -> [String] {
        return dnsCheck.getTestDomains()
    }

    /// Get configured DNS servers from system settings
    public func getDNSServers() -> [DNSServerInfo] {
        return dnsCheck.getDNSServers()
    }

    /// Check both gateway and internet reachability
    public func checkNetworkStatus() async -> NetworkStatus {
        async let gatewayStatus = gatewayCheck.check()
        async let internetStatus = internetCheck.check()
        async let dnsStatus = dnsCheck.check()

        return NetworkStatus(
            gateway: await gatewayStatus,
            internet: await internetStatus,
            dns: await dnsStatus
        )
    }

    /// Check if the default gateway/router is reachable
    public func checkGatewayReachability() async -> ReachabilityStatus {
        return await gatewayCheck.check()
    }

    /// Check if general internet is reachable (using configured endpoints)
    public func checkInternetReachability() async -> ReachabilityStatus {
        return await internetCheck.check()
    }

    /// Check DNS resolution capability
    public func checkDNSReachability() async -> ReachabilityStatus {
        return await dnsCheck.check()
    }

}
