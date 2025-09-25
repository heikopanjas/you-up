//
//  InternetCheck.swift
//
import Foundation

/// Internet connectivity check
public final class InternetCheck: NetworkCheck, Sendable {
    private let endpoints: [String]

    public init(endpoints: [String]) {
        self.endpoints = endpoints
    }

    public convenience init(config: EndpointsConfiguration) {
        self.init(endpoints: config.endpoints)
    }

    public func check() async -> ReachabilityStatus {
        // Try each host and return the first successful result
        for host in endpoints {
            let result = await httpCheck(url: host)
            if result.isReachable {
                return result
            }
        }

        return .unreachable
    }

    /// Get the configured endpoints
    public func getEndpoints() -> [String] {
        return endpoints
    }

    /// Check internet connectivity using HTTP
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
}