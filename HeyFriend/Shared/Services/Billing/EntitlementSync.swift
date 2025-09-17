//
//  EntitlementSync.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/9/25.
//

import Foundation
import StoreKit
import FirebaseAuth

@MainActor
final class EntitlementSync {
    static let shared = EntitlementSync()
    private init() {}

    // Keep these in one place (add/remove yearly if not used)
    private let plusIDs: Set<String> = [
        "com.heyfriend.plus.monthly",
        "com.heyfriend.plus.yearly"
    ]

    // Convenience over @AppStorage so we can write from anywhere.
    private var hasPlusFlag: Bool {
        get { UserDefaults.standard.bool(forKey: "hf.hasPlus") }
        set { UserDefaults.standard.set(newValue, forKey: "hf.hasPlus") }
    }

    private var updatesTask: Task<Void, Never>?
    
    nonisolated var isPlus: Bool { UserDefaults.standard.bool(forKey: "hf.hasPlus") }

    /// Call this once at app launch.
    func start() {
        // 1) Do an initial refresh
        Task { await refresh() }
        // 2) Begin listening for changes from the App Store
        if updatesTask == nil {
            updatesTask = Task { await listenForTransactionUpdates() }
        }
    }

    /// Re-check current entitlements and mirror to local flag + Firestore.
    func refresh() async {
        // 1) Find an active Plus transaction (if any)
        var activePlus: Transaction?
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productType == .autoRenewable,
               plusIDs.contains(tx.productID),
               tx.revocationDate == nil,
               (tx.expirationDate ?? .distantFuture) > Date() {
                activePlus = tx
                break
            }
        }
        
        // 2) Flip local flag
        hasPlusFlag = (activePlus != nil)
        
        // 3) Write to Firestore once (with metadata if active)
        guard let uid = (AuthService.shared.userId ?? Auth.auth().currentUser?.uid) else { return }
        
        if let tx = activePlus {
            let original = tx.originalID ?? tx.id
            try? await FirestoreService.shared.setPlus(
                uid: uid,
                productId: tx.productID,
                originalTransactionId: String(original),
                expiresAt: tx.expirationDate
            )
        } else {
            try? await FirestoreService.shared.setFree(uid: uid)
        }
    }

    // MARK: - Live updates
    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let tx) = result {
                await apply(tx)
                await tx.finish()
            }
        }
    }

    private func apply(_ tx: Transaction) async {
        let valid =
            tx.productType == .autoRenewable &&
            plusIDs.contains(tx.productID) &&
            tx.revocationDate == nil &&
            (tx.expirationDate ?? .distantFuture) > Date()

        // Flip local flag
        hasPlusFlag = valid

        // Mirror to Firestore (with metadata if valid)
        guard let uid = (AuthService.shared.userId ?? Auth.auth().currentUser?.uid) else { return }

        if valid {
            let original = tx.originalID ?? tx.id
            try? await FirestoreService.shared.setPlus(
                uid: uid,
                productId: tx.productID,
                originalTransactionId: String(original),
                expiresAt: tx.expirationDate
            )
        } else {
            try? await FirestoreService.shared.setFree(uid: uid)
        }
    }
}
