func generateWireguardConfig(company: Company, daemon: Daemon, dnsServer: DnsServer, networkController: NetworkController) -> String {
    return """
    [Interface]
    #company \(company.name)
    PrivateKey = \(daemon.privateKey ?? "")
    Address = \(daemon.ipAddress)
    DNS = \(dnsServer.ipAddress)

    [Peer]
    PublicKey = \(networkController.routerPublicKey)
    AllowedIPs = \(networkController.allowedIps)
    Endpoint = \(networkController.endpointAddress):51820
    PersistentKeepalive = 15
    """
}
