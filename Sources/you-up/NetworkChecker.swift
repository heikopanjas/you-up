//
//  NetworkChecker.swift
//
import Foundation
import Network
import SystemConfiguration

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
        if case .reachable = self { return true }
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

    /// Get the default gateway IP address
    private func getDefaultGateway() -> String? {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>? = nil

        guard getifaddrs(&ifaddrs) == 0 else {
            return nil
        }

        defer {
            freeifaddrs(ifaddrs)
        }

        // For simplicity, we'll use a system command approach
        // In a production version, you might want to parse routing table directly
        let task = Process()
        task.launchPath = "/sbin/route"
        task.arguments = ["-n", "get", "default"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // Parse the gateway IP from route output
            for line in output.components(separatedBy: .newlines) where line.trimmingCharacters(in: .whitespaces).starts(with: "gateway:") {
                let components = line.components(separatedBy: .whitespaces)
                if components.count >= 2 {
                    return components[1]
                }
            }
        }
        catch {
            return nil
        }

        return nil
    }
}
