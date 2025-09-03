//
//  AuthService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/28/25.
//

import Foundation
import FirebaseAuth
import GoogleSignIn

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

//    func signInAnonymouslyIfNeeded() async throws {
//        if Auth.auth().currentUser == nil {
//            _ = try await Auth.auth().signInAnonymously()
//        }
//    }

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

    @MainActor
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }
}
