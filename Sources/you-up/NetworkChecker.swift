//
//  NetworkChecker.swift
//
import Foundation
import Network
import SystemConfiguration

/// Represents router addresses for a network interface
struct RouterAddresses {
    let interface: String
    let ipv4: String?
    let ipv6: String?
}

/// Represents the reachability status of different network components
public struct NetworkStatus: Sendable {
    public let gateway: ReachabilityStatus
    public let internet: ReachabilityStatus
    public let timestamp: Date

    public init(gateway: ReachabilityStatus, internet: ReachabilityStatus, timestamp: Date = Date()) {
        self.gateway = gateway
        self.internet = internet
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
    public init() {}

    /// Check both gateway and internet reachability
    public func checkNetworkStatus() async -> NetworkStatus {
        async let gatewayStatus = checkGatewayReachability()
        async let internetStatus = checkInternetReachability()

        return NetworkStatus(
            gateway: await gatewayStatus,
            internet: await internetStatus
        )
    }

    /// Check if the default gateway/router is reachable
    public func checkGatewayReachability() async -> ReachabilityStatus {
        guard let gatewayIP = getDefaultGateway() else {
            return .unknown
        }

        return await ping(host: gatewayIP)
    }

    /// Check if general internet is reachable (using multiple reliable endpoints)
    public func checkInternetReachability() async -> ReachabilityStatus {
        let testHosts = [
            "https://dns.google",  // Google DNS over HTTPS
            "https://1.1.1.1",  // Cloudflare DNS
            "https://httpbin.org/get"  // Simple HTTP endpoint
        ]

        // Try each host and return the first successful result
        for host in testHosts {
            let result = await httpCheck(url: host)
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

    /// Ping a specific host to check reachability using basic socket connection
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
                    ipv6: nil
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
                        ipv6: routerIP
                    )
                }
                else {
                    routerDict[interfaceName] = RouterAddresses(
                        interface: interfaceName,
                        ipv4: nil,
                        ipv6: routerIP
                    )
                }
            }
        }

        return Array(routerDict.values)
    }
}
