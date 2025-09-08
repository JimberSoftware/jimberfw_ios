// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

public final class TunnelConfiguration {
    public var name: String?
    public var interface: InterfaceConfiguration
    public let peers: [PeerConfiguration]
    public let userId: Int?
    public let daemonId: Int?


    public init(name: String?, userId: Int?, daemonId: Int?, interface: InterfaceConfiguration, peers: [PeerConfiguration]) {
        self.interface = interface
        self.peers = peers
        self.name = name
        self.userId = userId
        self.daemonId = daemonId

        let peerPublicKeysArray = peers.map { $0.publicKey }
        let peerPublicKeysSet = Set<PublicKey>(peerPublicKeysArray)
        if peerPublicKeysArray.count != peerPublicKeysSet.count {
            fatalError("Two or more peers cannot have the same public key")
        }
    }
}

extension TunnelConfiguration: Equatable {
    public static func == (lhs: TunnelConfiguration, rhs: TunnelConfiguration) -> Bool {
        return lhs.name == rhs.name &&
            lhs.interface == rhs.interface &&
            Set(lhs.peers) == Set(rhs.peers)
    }
}
