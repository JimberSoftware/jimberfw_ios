import Foundation

// Authentication
enum AuthenticationError: Error {
    case authenticationFailed
}

func authenticateUser(authToken: String, authType: AuthenticationType) async throws -> UserAuthentication {
    let userAuthResult = await getUserAuthentication(idToken: authToken, authenticationType: authType)
    if(userAuthResult == nil) {
        throw AuthenticationError.authenticationFailed
    }

    return userAuthResult!;
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

    let createdDaemon = await createDaemon(userId: userId, company: companyName, daemonData: createDaemonData)
    if(createdDaemon == nil) {
        // TODO: error
    }

    let daemonIpAddress = createdDaemon!.ipAddress
    let daemonId = createdDaemon!.daemonId

    let daemonPrivateKeyX25519 = wireguardConfigKeys!.base64EncodedSkCurveX25519
    let daemonPrivateKeyEd25519 = ed25519Keys.privateKey

    let cloudControllerData = await getDaemonConnectionData(daemonId: daemonId, companyName: companyName, sk: daemonPrivateKeyEd25519)
    if(cloudControllerData == nil) {
        // TODO: error
    }

    let routerPublicKeyX25519 = parseEdPublicKeyToCurveX25519(pk: cloudControllerData!.routerPublicKey)
    let endpointAddress = cloudControllerData!.endpointAddress
    let cloudIpAddress = cloudControllerData!.ipAddress
    let allowedIps = cloudControllerData!.allowedIps

    // Save the Daemon KeyPair in shared storage
    let daemonKeyPair = DaemonKeyPair(daemonName: daemonName, daemonId: daemonId, userId: userId, companyName: companyName, baseEncodedPkEd25519: ed25519Keys.publicKey, baseEncodedSkEd25519: ed25519Keys.privateKey)
    SharedStorage.shared.saveDaemonKeyPair(daemonKeyPair)

    // Build WireGuard configuration
    let company = Company(name: companyName)
    let daemon = Daemon(daemonId: daemonId, name: daemonName, ipAddress: daemonIpAddress, privateKey: daemonPrivateKeyX25519)
    let dnsServer = DnsServer(ipAddress: cloudIpAddress)
    let networkController = NetworkController(routerPublicKey: routerPublicKeyX25519!, ipAddress: daemonIpAddress, endpointAddress: endpointAddress, allowedIps: allowedIps)

    let wireguardConfig = generateWireguardConfig(company: company, daemon: daemon, dnsServer: dnsServer, networkController: networkController)

    return NetworkIsolationDaemon(daemonId: daemonId, companyName: companyName, configurationString: wireguardConfig)
}
