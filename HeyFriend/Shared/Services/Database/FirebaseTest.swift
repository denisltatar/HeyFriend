//
//  FirebaseTest.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/28/25.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

func firebaseSmokeTest() {
    // Anonymous sign-in just to prove it works
    Auth.auth().signInAnonymously { result, error in
        if let error = error {
            print("Auth error:", error)
            return
        }
        guard let user = result?.user else { return }
        print("Signed in as:", user.uid)

        // Simple Firestore write
        let db = Firestore.firestore()
        db.collection("test").document(user.uid).setData([
            "hello": "world",
            "ts": FieldValue.serverTimestamp()
        ]) { err in
            if let err = err {
                print("Write failed:", err)
            } else {
                print("Write succeeded ✅")
            }
        }
    }
}
