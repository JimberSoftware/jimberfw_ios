// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

/// Replaces all lines matching `pattern` in `input` with `replacement`, in multiline mode.
func replacingLines(
    in input: String,
    matching pattern: String,
    with replacement: String
) throws -> String {
    let regex = try NSRegularExpression(
        pattern: pattern,
        options: [.anchorsMatchLines]
    )
    let range = NSRange(input.startIndex..<input.endIndex, in: input)
    return regex.stringByReplacingMatches(
        in: input,
        options: [],
        range: range,
        withTemplate: replacement
    )
}

/// Applies all four replacements to your config.
func updateWireGuardConfig(
    currentConfig: String,
    newPublicKeyLine: String,
    newAllowedIpsLine: String,
    newDnsServerLine: String,
    newEndpointLine: String
) -> String {
    var updated = currentConfig
    do {
        // ^\s*PublicKey\s*=.*$
        updated = try replacingLines(
            in: updated,
            matching: #"^\s*PublicKey\s*=.*$"#,
            with: newPublicKeyLine
        )
        // ^\s*AllowedIPs\s*=.*$
        updated = try replacingLines(
            in: updated,
            matching: #"^\s*AllowedIPs\s*=.*$"#,
            with: newAllowedIpsLine
        )
        // ^\s*DNS\s*=.*$
        updated = try replacingLines(
            in: updated,
            matching: #"^\s*DNS\s*=.*$"#,
            with: newDnsServerLine
        )
        // ^\s*Endpoint\s*=.*$
        // you want to end up with e.g. "Endpoint = your.host:51820"
        let endpointReplacement = "\(newEndpointLine):51820"
        updated = try replacingLines(
            in: updated,
            matching: #"^\s*Endpoint\s*=.*$"#,
            with: endpointReplacement
        )
    } catch {
        print("Failed to update config: \(error)")
    }
    return updated
}
