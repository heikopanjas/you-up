# you-up

A Swift package that provides comprehensive network reachability checking for gateway, internet, and DNS connectivity. The main differentiator of `you-up` is its ability to diagnose whether network issues are local (gateway/router problems), DNS-related, or external (internet connectivity problems).

## Overview

This project provides a comprehensive network diagnostic tool with:

- **Gateway/Router reachability checking**: Determines if your local router is responding
- **Internet connectivity testing**: Tests connectivity to multiple reliable endpoints
- **DNS resolution testing**: Verifies DNS resolution capability with configurable test domains
- **Smart diagnosis**: Helps identify whether issues are local network, DNS, or ISP/WAN related
- **Multiple output formats**: Human-readable and JSON output options
- **Configurable endpoints**: Customize internet test endpoints and DNS test domains via JSON configuration
- **Swift 6.0 with strict concurrency**: Modern, safe Swift code
- **macOS 15+ support**: Native macOS networking capabilities

## Use Cases

Perfect for troubleshooting network connectivity issues:

- **Local Network Issues**: Can't reach your router/gateway
- **DNS Resolution Problems**: Domain names not resolving to IP addresses
- **ISP/WAN Problems**: Router works but no internet access
- **Service-Specific Issues**: Internet works but specific services don't
- **Network Monitoring**: Automated connectivity monitoring scripts
- **DevOps/SRE**: Network health checks in deployment scripts

## Installation

### Using Swift Package Manager

Add this package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/heikopanjas/you-up.git", from: "0.1.0")
]
```

### Building from Source

```bash
git clone https://github.com/heikopanjas/you-up.git
cd you-up
swift build
```

## Usage

### Library

```swift
import you_up

let checker = NetworkChecker()

// Check gateway, internet, and DNS
let status = await checker.checkNetworkStatus()
print("Gateway: \(status.gateway)")
print("Internet: \(status.internet)")
print("DNS: \(status.dns)")

// Check individual components
let internetStatus = await checker.checkInternetReachability()
print("Internet: \(internetStatus)")

let gatewayStatus = await checker.checkGatewayReachability()
print("Gateway: \(gatewayStatus)")

let dnsStatus = await checker.checkDNSReachability()
print("DNS: \(dnsStatus)")

// Get configuration information
let endpoints = checker.getConfiguredEndpoints()
let dnsTestDomains = checker.getConfiguredDNSTestDomains()
let dnsServers = checker.getDNSServers()

print("Testing endpoints: \(endpoints)")
print("DNS test domains: \(dnsTestDomains)")
print("DNS servers: \(dnsServers)")
```

### Command Line Interface

#### Basic Usage

```bash
# Check gateway, internet, and DNS connectivity
swift run you-up-cli

# Output:
# ✅ Gateway/Router: reachable (15ms)
# ✅ Internet: reachable (45ms)
# ✅ DNS: reachable (12ms)
#
# 📊 Network Diagnosis:
#    🎉 All systems operational - full network connectivity
```

#### Advanced Options

```bash
# Verbose output with additional details
swift run you-up-cli --verbose

# Check only internet connectivity
swift run you-up-cli --internet-only

# Check only gateway connectivity
swift run you-up-cli --gateway-only

# Check only DNS resolution
swift run you-up-cli --dns-only

# JSON output for scripting
swift run you-up-cli --json

# Show current configuration and create sample if needed
swift run you-up-cli --show-config

# Get help
swift run you-up-cli --help
```

#### JSON Output Example

```bash
swift run you-up-cli --json
```

```json
{
  "timestamp": "2025-09-25T10:30:45Z",
  "gateway": {
    "status": "reachable (15ms)",
    "reachable": true
  },
  "internet": {
    "status": "reachable (45ms)",
    "reachable": true
  },
  "dns": {
    "status": "reachable (12ms)",
    "reachable": true
  }
}
```

## Configuration

### Internet Test Endpoints and DNS Test Domains

You can customize both the endpoints used for internet connectivity testing and the domains used for DNS resolution testing by creating a configuration file. The tool follows the XDG Base Directory specification for configuration file placement.

#### Configuration File Locations

The tool checks for configuration files in the following order:

1. `$XDG_CONFIG_HOME/you-up/endpoints.json` (if `XDG_CONFIG_HOME` environment variable is set)
2. `$HOME/.config/you-up/endpoints.json` (fallback location)

#### Sample Configuration

Create an `endpoints.json` file with your preferred test endpoints and DNS domains:

```json
{
  "endpoints": [
    "https://dns.google",
    "https://1.1.1.1",
    "https://httpbin.org/get",
    "https://example.com"
  ],
  "dnsTestDomains": [
    "google.com",
    "cloudflare.com",
    "example.com",
    "apple.com"
  ]
}
```

#### Configuration Management

```bash
# Show current configuration path and create sample configuration if needed
swift run you-up-cli --show-config
```

If no configuration file exists, the tool will fall back to the built-in default endpoints and DNS test domains. The `--show-config` command will display the configuration file path and create a sample configuration file if one doesn't exist.

## Network Diagnosis Logic

The tool provides intelligent diagnosis based on the combination of gateway, internet, and DNS reachability:

| Gateway | Internet | DNS | Diagnosis |
|---------|----------|-----|-----------|
| ✅ | ✅ | ✅ | 🎉 All systems operational |
| ✅ | ✅ | ❌ | ⚠️ DNS issues - try changing DNS servers |
| ✅ | ❌ | ✅ | ⚠️ ISP/WAN issue - internet unreachable |
| ✅ | ❌ | ❌ | ⚠️ ISP issues affecting connectivity and DNS |
| ❌ | ✅ | ✅ | 🤔 Unusual - check router configuration |
| ❌ | ✅ | ❌ | 🤔 Very unusual - check network settings |
| ❌ | ❌ | ✅ | ⚠️ Check cables, WiFi, and router |
| ❌ | ❌ | ❌ | 🚫 No network connectivity |

## Development

### Requirements

- Swift 6.0+
- macOS 15+
- Xcode 16+ (for development)

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

### Running the CLI

```bash
swift run you-up-cli [options]
```

## Project Structure

```text
you-up/
├── Sources/
│   ├── you-up/              # Library code
│   │   └── NetworkChecker.swift # Network checking functionality with configuration support
│   └── you-up-cli/          # CLI executable
│       └── main.swift       # Command-line interface with configuration management
├── Package.swift            # Swift Package Manager configuration
├── README.md               # This file
└── .github/
    └── copilot-instructions.md # Development guidelines and project documentation
```

## Technical Details

### Internet Connectivity Testing

The tool tests internet connectivity by making HTTP HEAD requests to multiple reliable endpoints. By default, it uses:

- `https://dns.google` (Google DNS over HTTPS)
- `https://1.1.1.1` (Cloudflare DNS)
- `https://httpbin.org/get` (HTTP testing service)

These endpoints can be customized using a JSON configuration file (see Configuration section above). The tool tests all configured endpoints and considers internet connectivity successful if any endpoint responds successfully.

### DNS Resolution Testing

The tool tests DNS resolution by attempting to resolve multiple test domains to IP addresses. By default, it uses:

- `google.com` (Reliable, globally distributed)
- `cloudflare.com` (Good DNS infrastructure)
- `example.com` (Designed for testing)
- `apple.com` (Relevant for macOS users)

The DNS test domains can be customized using the same JSON configuration file. The tool considers DNS resolution successful if any test domain resolves successfully. The test also discovers and displays the DNS servers configured on your system.

### Gateway Detection

Gateway reachability is determined by:

1. Finding the default gateway IP using system routing table
2. Attempting HTTP connection to the gateway address
3. Measuring response time and connection success

### Error Handling

The tool distinguishes between different types of network failures:

- **Reachable**: Connection successful with latency measurement
- **Unreachable**: Connection failed or rejected
- **Timeout**: Connection attempt timed out (3-second timeout)
- **Unknown**: Unable to determine status (e.g., no gateway found)

## License

This project is available under the terms specified in the LICENSE file.
