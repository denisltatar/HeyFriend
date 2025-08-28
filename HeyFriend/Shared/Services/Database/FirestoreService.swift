//
//  FirestoreService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/28/25.
//

import Foundation
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    // simple sanity write
    func writeHello(uid: String) async throws {
        try await db.collection("users").document(uid).setData([
            "hello": "world",
            "ts": FieldValue.serverTimestamp()
        ], merge: true)
    }
}
