import CryptoKit
import Foundation

struct EdKeyPair {
    let publicKey: String
    let privateKey: String
}

struct WireguardKeys {
    let base64EncodedPkCurveX25519: String
    let base64EncodedSkCurveX25519: String
}

// Generate Ed25519 key pair
func generateEd25519KeyPair() -> EdKeyPair {
    let privateKey = Curve25519.Signing.PrivateKey()
    let publicKey = privateKey.publicKey

    return EdKeyPair(
        publicKey: Data(publicKey.rawRepresentation).base64EncodedString(),
        privateKey: Data(privateKey.rawRepresentation).base64EncodedString()
    )
}

// Convert Ed25519 keys to X25519 for WireGuard
func generateWireguardConfigurationKeys(pk: String, sk: String) -> WireguardKeys? {
    guard let skData = Data(base64Encoded: sk),
          let pkData = Data(base64Encoded: pk) else { return nil }

    guard let curvePrivateKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: skData) else {
        print("Failed to create Curve25519 private key from raw representation")
        return nil
    }

    let curvePublicKey = curvePrivateKey.publicKey

    return WireguardKeys(
        base64EncodedPkCurveX25519: curvePublicKey.rawRepresentation.base64EncodedString(),
        base64EncodedSkCurveX25519: curvePrivateKey.rawRepresentation.base64EncodedString()
    )
}

// Sign a message using Ed25519 private key
func generateSign(message: Data, sk: String) -> Data? {
    guard let skData = Data(base64Encoded: sk) else { return nil }

    let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: skData)
    guard let signature = try? privateKey?.signature(for: message) else { return nil }

    return signature
}

// Generate a signed message with signature prepended
func generateSignedMessage(message: Data, privateKey: String) -> String? {
    guard let signature = generateSign(message: message, sk: privateKey) else { return nil }

    let payload = signature + message
    return payload.base64EncodedString()
}
