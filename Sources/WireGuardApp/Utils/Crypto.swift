import CryptoKit
import Foundation
import Clibsodium

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
    let x25519Pk = parseEdPublicKeyToCurveX25519(pk: pk)!
    let x25519Sk = parseEdPrivateKeyToCurveX25519(sk: sk)!

    return WireguardKeys(
        base64EncodedPkCurveX25519: x25519Pk,
        base64EncodedSkCurveX25519: x25519Sk
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

func parseEdPublicKeyToCurveX25519(pk: String) -> String? {
    // Decode base64 input
    guard let ed25519Data = Data(base64Encoded: pk), ed25519Data.count == 32 else {
        wg_log(.error, message: "Invalid ED public key: \(pk)")
        return nil
    }

    var x25519PublicKey = [UInt8](repeating: 0, count: 32)

    // Call libsodium function
    let result = ed25519Data.withUnsafeBytes { ed25519Ptr in
        crypto_sign_ed25519_pk_to_curve25519(
            &x25519PublicKey,
            ed25519Ptr.bindMemory(to: UInt8.self).baseAddress!
        )
    }

    guard result == 0 else {
        wg_log(.error, message: "Conversion failed")
        return nil
    }

    return Data(x25519PublicKey).base64EncodedString()
}

func parseEdPrivateKeyToCurveX25519(sk: String) -> String? {
    // Decode base64 input
    guard let ed25519SecretKeyData = Data(base64Encoded: sk), ed25519SecretKeyData.count == 32 || ed25519SecretKeyData.count == 64 else {
        wg_log(.error, message: "Invalid ED private key")
        return nil
    }

    var x25519SecretKey = [UInt8](repeating: 0, count: 32)

    // Only the first 32 bytes of the secret key are needed (the seed)
    let ed25519Seed = ed25519SecretKeyData.prefix(32)

    let result = ed25519Seed.withUnsafeBytes { seedPtr in
        crypto_sign_ed25519_sk_to_curve25519(
            &x25519SecretKey,
            seedPtr.bindMemory(to: UInt8.self).baseAddress!
        )
    }

    guard result == 0 else {
        wg_log(.error, message: "Conversion failed")
        return nil
    }

    return Data(x25519SecretKey).base64EncodedString()
}
