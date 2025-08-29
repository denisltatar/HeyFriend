//
//  AuthService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/28/25.
//

import Foundation
import FirebaseAuth

final class AuthService: ObservableObject {
    static let shared = AuthService()
    @Published var userId: String?

    private init() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.userId = user?.uid
        }
    }

    func signInAnonymouslyIfNeeded() async throws {
        if Auth.auth().currentUser == nil {
            _ = try await Auth.auth().signInAnonymously()
        }
    }
}
