import Foundation

// Authentication
enum AuthenticationError: Error {
    case authenticationFailed
}

func authenticateUser(authToken: String, authType: AuthenticationType) async throws -> UserAuthentication {
    let userAuthResult = await getUserAuthentication(idToken: authToken, authenticationType: authType)

    switch userAuthResult {
       case .success(let userAuth):
           return userAuth
       case .failure:
           throw AuthenticationError.authenticationFailed
       }
}

// Register Daemon
enum DaemonRegistrationError: Error {
    case daemonCreationFailed
    case networkControllerDataFetchFailed
}

func register(userAuthentication: UserAuthentication, daemonName: String) async throws -> NetworkIsolationDaemon {
    let ed25519Keys = generateEd25519KeyPair()
    
    let wireguardConfigKeys = generateWireguardConfigurationKeys(pk: ed25519Keys.publicKey, sk: ed25519Keys.privateKey)

    let userId = userAuthentication.userId
    let companyName = userAuthentication.companyName

    let createDaemonData = CreateDaemonApiRequest(publicKey: ed25519Keys.publicKey, name: daemonName)

    do {
        let createdDaemon = try await createDaemon(userId: userId, companyName: companyName, createDaemonData: createDaemonData)
        let daemonIpAddress = createdDaemon.ipAddress
        let daemonId = createdDaemon.daemonId

        let daemonPrivateKeyX25519 = wireguardConfigKeys.base64EncodedSkCurveX25519
        let daemonPrivateKeyEd25519 = ed25519Keys.sk

        let cloudControllerData = try await getDaemonConnectionData(daemonId: daemonId, companyName: companyName, daemonPrivateKeyEd25519: daemonPrivateKeyEd25519)

        let routerPublicKeyX25519 = parseEdPublicKeyToCurveX25519(cloudControllerData.routerPublicKey)
        let endpointAddress = cloudControllerData.endpointAddress
        let cloudIpAddress = cloudControllerData.ipAddress
        let allowedIps = cloudControllerData.allowedIps

        // Save the Daemon KeyPair in shared storage
        let daemonKeyPair = DaemonKeyPair(daemonName: daemonName, daemonId: daemonId, userId: userId, companyName: companyName, baseEncodedPkEd25519: ed25519Keys.pk, baseEncodedSkEd25519: ed25519Keys.sk)
        SharedStorage.shared.saveDaemonKeyPair(daemonKeyPair)

        // Build WireGuard configuration
        let company = Company(companyName: companyName)
        let daemon = Daemon(daemonId: daemonId, daemonName: daemonName, ipAddress: daemonIpAddress, privateKeyX25519: daemonPrivateKeyX25519)
        let dnsServer = DnsServer(ipAddress: cloudIpAddress)
        let networkController = NetworkController(routerPublicKeyX25519: routerPublicKeyX25519, daemonIpAddress: daemonIpAddress, endpointAddress: endpointAddress, allowedIps: allowedIps)

        let wireguardConfig = generateWireguardConfig(company: company, daemon: daemon, dnsServer: dnsServer, networkController: networkController)

        return NetworkIsolationDaemon(daemonId: daemonId, companyName: companyName, configurationString: wireguardConfig)

    } catch {
        throw DaemonRegistrationError.daemonCreationFailed
    }
}
