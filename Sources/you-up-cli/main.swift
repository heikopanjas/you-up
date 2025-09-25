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

    mutating func run() async throws {
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
}
