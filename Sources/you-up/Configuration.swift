//
//  Configuration.swift
//
import Foundation

/// Configuration for internet test endpoints
public struct EndpointsConfiguration: Codable, Sendable {
    public let endpoints: [String]
    public let dnsEndpoints: [String]

    public init(endpoints: [String], dnsEndpoints: [String]? = nil) {
        self.endpoints = endpoints
        self.dnsEndpoints = dnsEndpoints ?? Self.defaultDNSEndpoints
    }

    // Custom decoding to handle backward compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.endpoints = try container.decode([String].self, forKey: .endpoints)
        self.dnsEndpoints = try container.decodeIfPresent([String].self, forKey: .dnsEndpoints) ?? Self.defaultDNSEndpoints
    }

    private enum CodingKeys: String, CodingKey {
        case endpoints
        case dnsEndpoints
    }

    /// Default internet test endpoints
    public static let defaultInternetEndpoints = [
        "https://dns.google",  // Google DNS over HTTPS
        "https://1.1.1.1",  // Cloudflare DNS
        "https://httpbin.org/get"  // Simple HTTP endpoint
    ]

    /// Default DNS test domains
    public static let defaultDNSEndpoints = [
        "google.com",  // Reliable, globally distributed
        "cloudflare.com",  // Good DNS infrastructure
        "example.com",  // Designed for testing
        "apple.com"  // Relevant for macOS users
    ]

    /// Default configuration with reliable endpoints
    public static let `default` = EndpointsConfiguration(
        endpoints: defaultInternetEndpoints,
        dnsEndpoints: defaultDNSEndpoints
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
