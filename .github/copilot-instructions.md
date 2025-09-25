# Copilot Instructions for you-up

Last updated: 2025-09-25

## Project Overview

This is a Swift package project named "you-up" that provides network reachability checking capabilities for gateway, internet, and DNS connectivity. The project uses Swift 6.0 with strict concurrency enabled and targets macOS 15+.

The main differentiator of `you-up` is its ability to diagnose whether network issues are local (gateway/router problems), DNS-related (domain resolution issues), or external (internet connectivity problems), making it an excellent tool for comprehensive network troubleshooting.

## Project Structure

- **Library Target (`you-up`)**: Core network checking functionality in `Sources/you-up/`
  - `NetworkChecker.swift`: Main class with gateway, internet, and DNS reachability checking
  - `NetworkStatus` and `ReachabilityStatus`: Data structures for network state
  - `EndpointsConfiguration` and `ConfigurationLoader`: Configuration system for customizable internet test endpoints and DNS test domains
  - `DNSServerInfo`: Data structure for DNS server information
- **CLI Target (`you-up-cli`)**: Command-line interface in `Sources/you-up-cli/`
  - Provides human-readable output with smart network diagnosis
  - JSON output option for scripting and automation
  - Multiple checking modes (gateway-only, internet-only, dns-only, or all)
  - Configuration management (--show-config flag)
- **Dependencies**: Swift Argument Parser for CLI functionality
- **Configuration**: Supports user-configurable internet test endpoints and DNS test domains via JSON file

## Development Guidelines

### Code Style & Standards
- Use Swift 6.0 features and syntax
- Enable strict concurrency (`StrictConcurrency=complete`)
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add appropriate documentation comments for public APIs

### File Organization
- Keep library code in `Sources/you-up/`
- Keep CLI-specific code in `Sources/you-up-cli/`
- Use appropriate access control (public, internal, private)
- Organize related functionality into separate files

### Swift Package Manager
- Use semantic versioning for dependencies
- Keep `Package.swift` up to date with project requirements
- Ensure all targets have proper dependencies declared

### Network Functionality
- Use modern Swift networking APIs (URLSession, Network framework)
- Implement proper timeout handling (3-second timeouts for responsiveness)
- Test multiple endpoints to ensure reliability
- Provide both synchronous status and latency measurements
- Handle different failure modes (unreachable, timeout, unknown)
- Support configurable internet test endpoints through JSON configuration files
- Follow XDG Base Directory specification for configuration file placement

### CLI Development
- Use ArgumentParser for command-line interface
- Provide helpful descriptions and usage information
- Handle errors gracefully with user-friendly messages
- Support async operations where appropriate
- Offer multiple output formats (human-readable and JSON)
- Include smart network diagnosis based on combined results

### Testing
- Write unit tests for library functionality
- Test CLI commands and their outputs
- Use XCTest framework
- Maintain good test coverage

### Git & Commits
- Use conventional commit messages (feat:, fix:, docs:, etc.)
- Write descriptive but concise commit messages
- Stage changes before committing
- NEVER commit automatically - always ask for explicit confirmation
- NEVER use GitKraken or other GUI tools for git operations - ONLY use traditional git commands

## Current Issues to Address

✅ **Fixed Issues:**
1. ~~Import Inconsistency: The `main.swift` file imports `MyPackage` instead of `you-up`~~ - **FIXED**
2. ~~README: The README.md file needs proper documentation~~ - **FIXED**
3. ~~CLI Configuration: The CLI tool is named "mytool" instead of "you-up-cli"~~ - **FIXED**

All major inconsistencies have been resolved!

## Common Tasks

### Building the Project
```bash
swift build
```

### Running the CLI
```bash
# Basic connectivity check
swift run you-up-cli

# Verbose output with details
swift run you-up-cli --verbose

# Check only internet (skip gateway and DNS)
swift run you-up-cli --internet-only

# Check only gateway (skip internet and DNS)
swift run you-up-cli --gateway-only

# Check only DNS (skip gateway and internet)
swift run you-up-cli --dns-only

# JSON output for scripting
swift run you-up-cli --json

# Show configuration and create sample if needed
swift run you-up-cli --show-config
```

### Configuration Management
The tool supports configurable internet test endpoints through JSON configuration:

**Configuration file locations** (checked in order):
1. `$XDG_CONFIG_HOME/you-up/endpoints.json` (if XDG_CONFIG_HOME is set)
2. `$HOME/.config/you-up/endpoints.json` (fallback)

**Sample configuration** (`endpoints.json`):
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

**Configuration commands**:
```bash
# Show current configuration and create sample if needed
swift run you-up-cli --show-config
```

### Running Tests
```bash
swift test
```

## Recent Updates & Decisions

- **2024-09-25**: Initial copilot instructions created based on project analysis
  - Identified Swift 6.0 package with library and CLI components
  - Noted import inconsistencies and naming issues to be addressed
  - Established development guidelines and project structure documentation

- **2024-09-25**: Fixed all major inconsistencies in the project
  - Fixed import statement: Changed `import MyPackage` to `import you_up` in main.swift
  - Renamed CLI struct from `MyTool` to `YouUpCLI` for better naming consistency
  - Updated CLI command name from "mytool" to "you-up-cli"
  - Made configuration property `let` instead of `var` to resolve concurrency safety warning
  - Created comprehensive README.md with proper documentation, usage examples, and project structure
  - Fixed markdown linting issues (blank lines around lists, language specification, trailing newline)
  - Verified fixes with successful build and CLI test

- **2024-09-25**: Transformed project from greeting tool to network reachability checker
  - Completely rewrote `NetworkChecker.swift` (formerly Greeter.swift) to implement network functionality
  - Added `NetworkStatus` and `ReachabilityStatus` data structures for network state management
  - Implemented gateway reachability checking using system routing table and HTTP connections
  - Implemented internet connectivity testing using multiple reliable endpoints (Google DNS, Cloudflare, httpbin.org)
  - Updated CLI to provide comprehensive network diagnosis with human-readable and JSON output options
  - Added multiple CLI modes: verbose, internet-only, gateway-only, and JSON output
  - Implemented smart network diagnosis logic to distinguish between local and WAN connectivity issues
  - Updated README.md with comprehensive documentation for network reachability features
  - Added proper error handling for different network failure modes (unreachable, timeout, unknown)
  - Used modern Swift async/await patterns with proper timeout handling (3-second timeouts)

- **2025-09-25**: Added configurable internet endpoints feature
  - Implemented `EndpointsConfiguration` struct with Codable and Sendable conformance for configuration management
  - Added `ConfigurationLoader` class with XDG Base Directory specification support
  - Configuration file locations: `$XDG_CONFIG_HOME/you-up/endpoints.json` or `$HOME/.config/you-up/endpoints.json`
  - Modified `NetworkChecker` to use configurable endpoints instead of hardcoded static endpoints
  - Added `getConfiguredEndpoints()` method to expose current endpoint configuration
  - Updated CLI to use instance-based endpoint configuration instead of static property
  - Added `--show-config` CLI flag to display configuration path and create sample configuration
  - Implemented automatic fallback to default endpoints when configuration file is missing or invalid
  - Added proper error handling for configuration loading and directory creation
  - Updated copilot instructions with configuration management documentation and examples

- **2025-09-25**: Updated README.md with configurable endpoints documentation
  - Added configuration section explaining XDG Base Directory specification compliance
  - Documented configuration file locations and JSON format
  - Added `--show-config` CLI option to usage examples
  - Updated library usage examples to include `getConfiguredEndpoints()` method
  - Enhanced technical details section to explain configurable endpoint behavior
  - Updated project structure section to reflect current state with copilot instructions

- **2025-09-25**: Implemented DNS resolution testing as third reachability type
  - Added `DNSServerInfo` data structure for DNS server information
  - Extended `NetworkStatus` to include DNS reachability status
  - Extended `EndpointsConfiguration` to support configurable DNS test domains with defaults (google.com, cloudflare.com, example.com, apple.com)
  - Implemented `checkDNSReachability()` method using HTTP-based DNS resolution testing
  - Added `getDNSServers()` method to discover system DNS servers from router/system settings
  - Added `getConfiguredDNSTestDomains()` method to expose configured DNS test domains
  - Updated CLI with `--dns-only` flag for isolated DNS testing
  - Enhanced verbose output to show DNS servers and test domains
  - Updated JSON output to include DNS status information
  - Expanded network diagnosis logic to handle 8 combinations of gateway/internet/DNS states
  - Updated `--show-config` to display both internet endpoints and DNS test domains
  - Updated README.md with comprehensive DNS functionality documentation
  - Updated copilot instructions with DNS testing guidelines and current project state
