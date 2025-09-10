//
//  AuthService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/28/25.
//

import Foundation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

final class AuthService: ObservableObject {
    static let shared = AuthService()
    @Published var userId: String?

    private init() {
        // Set immediately on starsignInAnonymouslyIfNeededtup
        self.userId = Auth.auth().currentUser?.uid
        
        // Then keep it in sync
        Auth.auth().addStateDidChangeListener { _, user in
            self.userId = user?.uid
        }
    }

    func signInAnonymouslyIfNeeded() async throws {
        if Auth.auth().currentUser == nil {
            _ = try await Auth.auth().signInAnonymously()
        }
    }

    // MARK: - Google Sign-In
    @MainActor
    func signInWithGoogle(presenting presenter: UIViewController) async throws {
        // Try restore first (fast path)
        if let restored = try? await GIDSignIn.sharedInstance.restorePreviousSignIn(),
           let idToken = restored.idToken?.tokenString {
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: restored.accessToken.tokenString
            )
            _ = try await Auth.auth().signIn(with: credential)
            return
        }

        // Fresh sign-in
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "AuthService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing Google ID token"])
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        _ = try await Auth.auth().signIn(with: credential)
    }
    
    // Keep the last nonce so we can verify the response
    private var currentNonce: String?

    // Call from the Apple button's request closure
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    // Call from the Apple button's completion closure
    @MainActor
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            throw error
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                throw NSError(domain: "AuthService", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential"])
            }
            guard let idTokenData = credential.identityToken,
                  let idTokenString = String(data: idTokenData, encoding: .utf8) else {
                throw NSError(domain: "AuthService", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "Missing Apple ID token"])
            }
            guard let nonce = currentNonce else {
                throw NSError(domain: "AuthService", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "Missing state (nonce)"])
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            _ = try await Auth.auth().signIn(with: firebaseCredential)
            // auth state change will route you to RootTabView
        }
    }

    // MARK: - Crypto helpers (Apple nonce)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { fatalError("Unable to generate nonce. SecRandomCopyBytes failed.") }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    @MainActor
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.userId = nil
        } catch {
            print("Sign out failed:", error.localizedDescription)
        }
    }
}
