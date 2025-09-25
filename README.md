# you-up

A Swift package that provides network reachability checking for both internet and gateway connectivity. The main differentiator of `you-up` is its ability to diagnose whether network issues are local (gateway/router problems) or external (internet connectivity problems).

## Overview

This project provides a comprehensive network diagnostic tool with:

- **Gateway/Router reachability checking**: Determines if your local router is responding
- **Internet connectivity testing**: Tests connectivity to multiple reliable endpoints
- **Smart diagnosis**: Helps identify whether issues are local network or ISP/WAN related
- **Multiple output formats**: Human-readable and JSON output options
- **Configurable endpoints**: Customize internet test endpoints via JSON configuration
- **Swift 6.0 with strict concurrency**: Modern, safe Swift code
- **macOS 15+ support**: Native macOS networking capabilities

## Use Cases

Perfect for troubleshooting network connectivity issues:

- **Local Network Issues**: Can't reach your router/gateway
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

// Check both gateway and internet
let status = await checker.checkNetworkStatus()
print("Gateway: \(status.gateway)")
print("Internet: \(status.internet)")

// Check just internet connectivity
let internetStatus = await checker.checkInternetReachability()
print("Internet: \(internetStatus)")

// Check just gateway connectivity
let gatewayStatus = await checker.checkGatewayReachability()
print("Gateway: \(gatewayStatus)")

// Get configured internet test endpoints
let endpoints = checker.getConfiguredEndpoints()
print("Testing endpoints: \(endpoints)")
```

### Command Line Interface

#### Basic Usage

```bash
# Check both gateway and internet connectivity
swift run you-up-cli

# Output:
# ✅ Gateway/Router: reachable (15ms)
# ✅ Internet: reachable (45ms)
#
# 📊 Network Diagnosis:
#    🎉 All systems operational - full internet connectivity
```

#### Advanced Options

```bash
# Verbose output with additional details
swift run you-up-cli --verbose

# Check only internet connectivity
swift run you-up-cli --internet-only

# Check only gateway connectivity
swift run you-up-cli --gateway-only

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
  "timestamp": "2024-09-25T10:30:45Z",
  "gateway": {
    "status": "reachable (15ms)",
    "reachable": true
  },
  "internet": {
    "status": "reachable (45ms)",
    "reachable": true
  }
}
```

## Configuration

### Internet Test Endpoints

You can customize the endpoints used for internet connectivity testing by creating a configuration file. The tool follows the XDG Base Directory specification for configuration file placement.

#### Configuration File Locations

The tool checks for configuration files in the following order:

1. `$XDG_CONFIG_HOME/you-up/endpoints.json` (if `XDG_CONFIG_HOME` environment variable is set)
2. `$HOME/.config/you-up/endpoints.json` (fallback location)

#### Sample Configuration

Create an `endpoints.json` file with your preferred test endpoints:

```json
{
  "endpoints": [
    "https://dns.google",
    "https://1.1.1.1",
    "https://httpbin.org/get",
    "https://example.com"
  ]
}
```

#### Configuration Management

```bash
# Show current configuration path and create sample configuration if needed
swift run you-up-cli --show-config
```

If no configuration file exists, the tool will fall back to the built-in default endpoints. The `--show-config` command will display the configuration file path and create a sample configuration file if one doesn't exist.

## Network Diagnosis Logic

The tool provides intelligent diagnosis based on the combination of gateway and internet reachability:

| Gateway | Internet | Diagnosis |
|---------|----------|-----------|
| ✅ Reachable | ✅ Reachable | 🎉 All systems operational |
| ✅ Reachable | ❌ Unreachable | ⚠️ Local network OK, ISP/WAN issue |
| ❌ Unreachable | ✅ Reachable | 🤔 Unusual - check router config |
| ❌ Unreachable | ❌ Unreachable | 🚫 No network connectivity |

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
