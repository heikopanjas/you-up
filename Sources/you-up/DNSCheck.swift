//
//  DNSCheck.swift
//
import Foundation
import SystemConfiguration

/// DNS resolution check
public final class DNSCheck: NetworkCheck, Sendable {
    private let testDomains: [String]

    public init(testDomains: [String]) {
        self.testDomains = testDomains
    }

    public convenience init(config: EndpointsConfiguration) {
        self.init(testDomains: config.dnsEndpoints)
    }

    public func check() async -> ReachabilityStatus {
        // Try to resolve each test domain and return the first successful result
        for domain in testDomains {
            let result = await dnsResolveCheck(domain: domain)
            if result.isReachable {
                return result
            }
        }

        return .unreachable
    }

    /// Get the configured test domains
    public func getTestDomains() -> [String] {
        return testDomains
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
}
