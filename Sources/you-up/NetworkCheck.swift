//
//  NetworkCheck.swift
//
import Foundation

/// Protocol for network connectivity checks
public protocol NetworkCheck: Sendable {
    /// Perform the connectivity check
    func check() async -> ReachabilityStatus
}