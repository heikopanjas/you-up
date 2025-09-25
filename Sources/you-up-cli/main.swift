//
//  main.swift
//
import ArgumentParser
import Foundation
import you_up

@main
struct YouUpCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "you-up-cli",
        abstract: "Check internet and gateway reachability to diagnose network connectivity issues.",
        version: "0.1.0"
    )

    @Flag(name: [.short, .long], help: "Show verbose output with additional network details.")
    var verbose: Bool = false

    @Flag(name: [.long], help: "Only check internet connectivity (skip gateway check).")
    var internetOnly: Bool = false

    @Flag(name: [.long], help: "Only check gateway connectivity (skip internet check).")
    var gatewayOnly: Bool = false

    @Flag(name: [.short, .long], help: "Output results in JSON format.")
    var json: Bool = false

    @Flag(name: [.long], help: "Show configuration file path and create a sample configuration if none exists.")
    var showConfig: Bool = false

    mutating func run() async throws {
        if showConfig {
            try showConfigurationInfo()
            return
        }

        let checker = NetworkChecker()

        if json {
            await runJSONOutput(checker: checker)
        }
        else {
            await runHumanOutput(checker: checker)
        }
    }

    private func runHumanOutput(checker: NetworkChecker) async {
        if verbose {
            print("🔍 Checking network connectivity...")
            await printVerboseNetworkInfo(checker: checker, mode: getTestMode())
            print()
        }

        if gatewayOnly {
            let gatewayStatus = await checker.checkGatewayReachability()
            printGatewayStatus(gatewayStatus)
        }
        else if internetOnly {
            let internetStatus = await checker.checkInternetReachability()
            printInternetStatus(internetStatus)
        }
        else {
            let status = await checker.checkNetworkStatus()
            printGatewayStatus(status.gateway)
            printInternetStatus(status.internet)

            print()
            printSummary(gateway: status.gateway, internet: status.internet)
        }
    }

    private enum TestMode {
        case gatewayOnly
        case internetOnly
        case both
    }

    private func getTestMode() -> TestMode {
        if gatewayOnly {
            return .gatewayOnly
        }
        else if internetOnly {
            return .internetOnly
        }
        else {
            return .both
        }
    }

    private func printVerboseNetworkInfo(checker: NetworkChecker, mode: TestMode) async {
        let routers = checker.getActiveRouters()

        // Filter out interfaces that only have fe80:: (link-local) router addresses
        let meaningfulRouters = routers.filter { router in
            // Include if it has an IPv4 router
            if router.ipv4 != nil {
                return true
            }
            // Include if it has an IPv6 router that's not just fe80::
            if let ipv6 = router.ipv6, ipv6 != "fe80::" {
                return true
            }
            // Exclude interfaces with only fe80:: or no routers
            return false
        }

        // Show active network interfaces (always show for context)
        if !meaningfulRouters.isEmpty {
            print("📡 Active Network Interfaces:")
            for router in meaningfulRouters {
                print("  \(router.mediaType.emoji) \(router.interface) (\(router.mediaType.rawValue))")
            }
            print()
        }

        // Show router addresses only for gateway-only and both modes
        if mode == .gatewayOnly || mode == .both {
            // Collect and deduplicate router addresses
            var uniqueRouters = Set<String>()
            for router in meaningfulRouters {
                if let ipv4 = router.ipv4 {
                    uniqueRouters.insert(ipv4)
                }
                if let ipv6 = router.ipv6, ipv6 != "fe80::" {
                    uniqueRouters.insert(ipv6)
                }
            }

            if !uniqueRouters.isEmpty {
                print("🏠 Router Addresses:")
                let sortedRouters = uniqueRouters.sorted()
                for routerAddress in sortedRouters {
                    // Determine if it's IPv4 or IPv6
                    if routerAddress.contains(":") {
                        print("  • \(routerAddress) (IPv6)")
                    }
                    else {
                        print("  • \(routerAddress) (IPv4)")
                    }
                }
                print()
            }
        }

        // Show internet test endpoints only for internet-only and both modes
        if mode == .internetOnly || mode == .both {
            print("🌐 Internet Test Endpoints:")
            for endpoint in checker.getConfiguredEndpoints() {
                if let url = URL(string: endpoint), let host = url.host {
                    print("  • \(endpoint) (\(host))")
                }
                else {
                    print("  • \(endpoint)")
                }
            }
            print()
        }
    }

    private func runJSONOutput(checker: NetworkChecker) async {
        let status = await checker.checkNetworkStatus()

        let jsonData: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: status.timestamp),
            "gateway": [
                "status": status.gateway.description,
                "reachable": status.gateway.isReachable
            ],
            "internet": [
                "status": status.internet.description,
                "reachable": status.internet.isReachable
            ]
        ]

        if let jsonOutput = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
            let jsonString = String(data: jsonOutput, encoding: .utf8)
        {
            print(jsonString)
        }
    }

    private func printGatewayStatus(_ status: ReachabilityStatus) {
        let icon = status.isReachable ? "✅" : "❌"
        print("\(icon) Gateway/Router: \(status)")
    }

    private func printInternetStatus(_ status: ReachabilityStatus) {
        let icon = status.isReachable ? "✅" : "❌"
        print("\(icon) Internet: \(status)")
    }

    private func printSummary(gateway: ReachabilityStatus, internet: ReachabilityStatus) {
        print("📊 Network Diagnosis:")

        switch (gateway.isReachable, internet.isReachable) {
            case (true, true):
                print("   🎉 All systems operational - full internet connectivity")
            case (true, false):
                print("   ⚠️  Local network OK, but internet is unreachable")
                print("   💡 This suggests an ISP or WAN connectivity issue")
            case (false, true):
                print("   🤔 Internet reachable but gateway is not responding")
                print("   💡 This is unusual - check your router configuration")
            case (false, false):
                print("   🚫 No network connectivity detected")
                print("   💡 Check your network cables, WiFi connection, and router")
        }
    }

    private func showConfigurationInfo() throws {
        print("📋 Configuration Information")
        print()

        // Get config path
        let configPath: String?
        if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            configPath = "\(xdgConfigHome)/you-up/endpoints.json"
        }
        else if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            configPath = "\(homeDir)/.config/you-up/endpoints.json"
        }
        else {
            configPath = nil
        }

        guard let configPath = configPath else {
            print("❌ Cannot determine configuration directory path")
            return
        }

        print("📁 Configuration file path:")
        print("   \(configPath)")
        print()

        if FileManager.default.fileExists(atPath: configPath) {
            print("✅ Configuration file exists")

            // Load and display current configuration
            let config = ConfigurationLoader.loadEndpointsConfiguration()
            print("🌐 Configured endpoints:")
            for endpoint in config.endpoints {
                print("   • \(endpoint)")
            }
        }
        else {
            print("📝 Configuration file does not exist")
            print("   Creating sample configuration...")

            try ConfigurationLoader.createSampleConfiguration()
            print("✅ Sample configuration created at:")
            print("   \(configPath)")
            print()
            print("📖 Sample configuration contains:")
            let sampleConfig = EndpointsConfiguration.default
            for endpoint in sampleConfig.endpoints {
                print("   • \(endpoint)")
            }
            print()
            print("💡 You can edit this file to customize the internet test endpoints")
        }
    }
}
