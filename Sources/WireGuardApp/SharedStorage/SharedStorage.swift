import Foundation

struct DaemonKeyPair {
    let daemonName: String
    let daemonId: Int
    let userId: Int
    let companyName: String
    let baseEncodedPkEd25519: String
    let baseEncodedSkEd25519: String
}

class SharedStorage {

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let refreshTokenKey = "refresh_token"
        static let authenticationTokenKey = "authentication_token"
        static let currentUserKey = "current_user"
        static let wireGuardKeyPairKey = "wireguard_keypair"
        static let wireGuardDaemonNameKey = "name"
        static let wireGuardDaemonIdKey = "id"
        static let wireGuardUserIdKey = "userId"
        static let wireGuardCompanyKey = "company"
        static let wireGuardPkEd25519Key = "pk_ed25519"
        static let wireGuardSkEd25519Key = "sk_ed25519"
    }

    static let shared = SharedStorage()

    private init() {}

    // MARK: - UserDefaults Operations

    // Save and Get Refresh Token
    func saveRefreshToken(_ token: String) {
        defaults.set(token, forKey: Keys.refreshTokenKey)
    }

    func getRefreshToken() -> String? {
        return defaults.string(forKey: Keys.refreshTokenKey)
    }

    func clearRefreshToken() {
        defaults.removeObject(forKey: Keys.refreshTokenKey)
    }

    // Save and Get Authentication Token
    func saveAuthenticationToken(_ token: String) {
        defaults.set(token, forKey: Keys.authenticationTokenKey)
    }

    func getAuthenticationToken() -> String? {
        return defaults.string(forKey: Keys.authenticationTokenKey)
    }

    func clearAuthenticationToken() {
        defaults.removeObject(forKey: Keys.authenticationTokenKey)
    }

    // Save and Get Current User
    func saveCurrentUser(user: User) {
        let userDict: [String: Any] = [
            "id": user.id,
            "email": user.email
        ]
        defaults.set(userDict, forKey: Keys.currentUserKey)
    }

    func getCurrentUser() -> User? {
        guard let userDict = defaults.dictionary(forKey: Keys.currentUserKey) else { return nil }
        if let id = userDict["id"] as? Int, let email = userDict["email"] as? String {
            return User(id: id, email: email)
        }
        return nil
    }

    func clearCurrentUser() {
        defaults.removeObject(forKey: Keys.currentUserKey)
    }

    // Save and Get Daemon Key Pair
    func saveDaemonKeyPair(_ kp: DaemonKeyPair) {
        var keyPairs = getDaemonKeyPairs()
        // Remove any existing key pair with the same daemonId or userId
        keyPairs.removeAll { $0.daemonId == kp.daemonId || $0.userId == kp.userId }
        keyPairs.append(kp)

        let encodedKeyPairs = try? JSONEncoder().encode(keyPairs)
        defaults.set(encodedKeyPairs, forKey: Keys.wireGuardKeyPairKey)
    }

    func getDaemonKeyPairByUserId(_ userId: Int) -> DaemonKeyPair? {
        let keyPairs = getDaemonKeyPairs()
        return keyPairs.first { $0.userId == userId }
    }

    func getDaemonKeyPairByDaemonId(_ daemonId: Int) -> DaemonKeyPair? {
        let keyPairs = getDaemonKeyPairs()
        return keyPairs.first { $0.daemonId == daemonId }
    }

    private func getDaemonKeyPairs() -> [DaemonKeyPair] {
        guard let data = defaults.data(forKey: Keys.wireGuardKeyPairKey),
              let keyPairs = try? JSONDecoder().decode([DaemonKeyPair].self, from: data) else {
            return []
        }
        return keyPairs
    }

    // Clear Daemon Keys by Daemon ID
    func clearDaemonKeys(daemonId: Int) {
        var keyPairs = getDaemonKeyPairs()
        keyPairs.removeAll { $0.daemonId == daemonId }

        let encodedKeyPairs = try? JSONEncoder().encode(keyPairs)
        defaults.set(encodedKeyPairs, forKey: Keys.wireGuardKeyPairKey)
    }

    // Clear All User Data
    func clearAll() {
        defaults.removeObject(forKey: Keys.refreshTokenKey)
        defaults.removeObject(forKey: Keys.authenticationTokenKey)
        defaults.removeObject(forKey: Keys.currentUserKey)
        defaults.removeObject(forKey: Keys.wireGuardKeyPairKey)
    }

    // Get All Stored Values
    func getAll() -> [String: Any] {
        return defaults.dictionaryRepresentation()
    }
}
