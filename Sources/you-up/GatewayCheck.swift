//
//  GatewayCheck.swift
//
import Foundation
import Network
import SystemConfiguration

/// Gateway/Router connectivity check
public final class GatewayCheck: NetworkCheck, Sendable {
    private let gatewayIP: String?

    public init() {
        self.gatewayIP = Self.getDefaultGateway()
    }

    /// Initialize with a specific gateway IP for testing
    public init(gatewayIP: String) {
        self.gatewayIP = gatewayIP
    }

    public func check() async -> ReachabilityStatus {
        guard let gatewayIP = gatewayIP else {
            return .unknown
        }

        return await networkFrameworkPing(host: gatewayIP)
    }

    /// Get available gateway/router addresses
    public func getGatewayAddresses() -> [RouterAddresses] {
        return Self.getAllRouterAddresses()
    }

    /// Ping gateway using Network.framework TCP connection test (preferred method)
    private func networkFrameworkPing(host: String) async -> ReachabilityStatus {
        let startTime = Date()

        // Try to connect to common router management ports
        // Most routers have at least one of these services running
        let testPorts: [UInt16] = [80, 443, 22, 23, 53]

        for port in testPorts {
            let result = await testPortConnectivity(host: host, port: port, startTime: startTime)
            if case .reachable = result {
                return result
            }
        }

        return .timeout  // If no ports responded, consider it a timeout
    }

    /// Test connectivity to a specific port
    private func testPortConnectivity(host: String, port: UInt16, startTime: Date) async -> ReachabilityStatus {
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
            let parameters = NWParameters.tcp
            parameters.serviceClass = .interactiveVideo

            let connection = NWConnection(to: endpoint, using: parameters)

            // Use actor for thread-safe state management
            let state = PortTestState()

            connection.stateUpdateHandler = { connectionState in
                Task {
                    await state.handleStateUpdate(connectionState, connection: connection, startTime: startTime, continuation: continuation)
                }
            }

            let queue = DispatchQueue(label: "port-test-\(port)", qos: .userInitiated)
            connection.start(queue: queue)

            // Very short timeout for port testing (500ms per port)
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                await state.handleTimeout(connection: connection, continuation: continuation)
            }
        }
    }

    // Actor to handle port test state safely
    private actor PortTestState {
        private var hasResumed = false

        func handleStateUpdate(
            _ state: NWConnection.State, connection: NWConnection, startTime: Date, continuation: CheckedContinuation<ReachabilityStatus, Never>
        ) {
            guard !hasResumed else { return }

            switch state {
                case .ready:
                    hasResumed = true
                    let latency = Date().timeIntervalSince(startTime)
                    connection.cancel()
                    continuation.resume(returning: .reachable(latency: latency))

                case .failed(_):
                    hasResumed = true
                    connection.cancel()
                    // For port testing, a connection refused is actually good - it means the host is reachable
                    let latency = Date().timeIntervalSince(startTime)
                    continuation.resume(returning: .reachable(latency: latency))

                case .cancelled:
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: .timeout)
                    }

                default:
                    break
            }
        }

        func handleTimeout(connection: NWConnection, continuation: CheckedContinuation<ReachabilityStatus, Never>) {
            guard !hasResumed else { return }
            hasResumed = true
            connection.cancel()
            continuation.resume(returning: .timeout)
        }
    }

    // Actor to handle path monitoring state safely with Swift 6 concurrency
    private actor ConnectionState {
        private var hasResumed = false

        func handleTimeout(continuation: CheckedContinuation<ReachabilityStatus, Never>) {
            guard !hasResumed else { return }
            hasResumed = true
            continuation.resume(returning: .timeout)
        }
    }

    /// Get the default gateway IP address using SystemConfiguration
    private static func getDefaultGateway() -> String? {
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
    private static func getAllRouterAddresses() -> [RouterAddresses] {
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

    /// Determine the media type of a network interface
    private static func getInterfaceMediaType(_ interfaceName: String) -> NetworkMediaType {
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
    private static func getDetailedInterfaceType(_ interfaceName: String) -> NetworkMediaType? {
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
}
