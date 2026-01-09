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
    private var authHandle: AuthStateDidChangeListenerHandle?
    
    nonisolated var isPlus: Bool { UserDefaults.standard.bool(forKey: "hf.hasPlus") }

    /// Call this once at app launch.
    func start() {
        // Listen to Firebase auth changes (login/logout/switch).
        if authHandle == nil {
            authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
                // When auth changes, re-check entitlements after a tiny delay
                // to let Apple receipt/auth settle.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000) // 0.35s debounce
                    await self?.refresh()
                }
            }
        }

        // Initial refresh
        Task { await refresh() }

        // Listen for StoreKit updates
        if updatesTask == nil {
            updatesTask = Task { await listenForTransactionUpdates() }
        }
    }
    
    /// Manually trigger Apple sync (for your "Restore Purchases" button).
    func restore() async throws {
        try await AppStore.sync()
        await refresh()
    }


    /// Re-check current entitlements and (safely) mirror to local flag + Firestore.
    func refresh() async {
        // 1) Always compute local entitlement state (even if no Firebase user yet)
        var activePlus: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            guard plusIDs.contains(tx.productID),
                  tx.productType == .autoRenewable,
                  tx.revocationDate == nil,
                  (tx.expirationDate ?? .distantFuture) > Date()
            else { continue }
            activePlus = tx
            break
        }

        // 2) Defensive latest check
        if activePlus == nil {
            for id in plusIDs {
                if let latest = await Transaction.latest(for: id),
                   case .verified(let tx) = latest,
                   tx.revocationDate == nil,
                   !tx.isUpgraded,
                   (tx.expirationDate ?? .distantFuture) > Date() {
                    activePlus = tx
                    break
                }
            }
        }

        // 3) Update local UI flag immediately (fast UI)
        hasPlusFlag = (activePlus != nil)

        // 4) Only mirror to Firestore if we have a uid
        guard let uid = (AuthService.shared.userId ?? Auth.auth().currentUser?.uid) else {
            return
        }

        // 5) Write to Firestore
        if let tx = activePlus {
            let original = tx.originalID ?? tx.id
            try? await FirestoreService.shared.setPlus(
                uid: uid,
                productId: tx.productID,
                originalTransactionId: String(original),
                expiresAt: tx.expirationDate
            )
            
            if let tx = activePlus {
                print("✓ PLUS ACTIVE via \(tx.productID) exp=\(String(describing: tx.expirationDate))")
            } else {
                print("✗ No active Plus found in refresh()")
            }
        } else {
            // To avoid flapping: give the system a short grace window after login/foreground
            // before declaring "free".
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            // Re-check quickly once more to be sure.
            var stillNoPlus = true
            for await result in Transaction.currentEntitlements {
                if case .verified(let tx) = result,
                   plusIDs.contains(tx.productID),
                   tx.revocationDate == nil,
                   (tx.expirationDate ?? .distantFuture) > Date() {
                    stillNoPlus = false
                    break
                }
            }
            if stillNoPlus {
                try? await FirestoreService.shared.setFree(uid: uid)
            }
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
    
    // Optional: call on logout to clear fast UI state only (not server)
    func clearLocalFlagOnLogout() {
        hasPlusFlag = false
    }
}

extension EntitlementSync {
    func debugDumpEntitlements(label: String = "DEBUG") async {
        print("──── \(label): BEGIN ENTITLEMENT DUMP ────")

        // Current (active) entitlements
        var foundAny = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let tx):
                foundAny = true
                print("• CURRENT VERIFIED")
                print("  productID: \(tx.productID)")
                print("  type: \(tx.productType.rawValue)")
                print("  purchaseDate: \(tx.purchaseDate)")
                print("  expirationDate: \(String(describing: tx.expirationDate))")
                print("  revocationDate: \(String(describing: tx.revocationDate))")
                print("  isUpgraded: \(tx.isUpgraded)")
            case .unverified(let tx, let err):
                foundAny = true
                print("• CURRENT UNVERIFIED \(tx.productID) error: \(err)")
            }
        }
        if !foundAny { print("• No currentEntitlements found") }

        // Latest per product ID (defensive)
        for id in plusIDs {
            let latest = await Transaction.latest(for: id)
            switch latest {
            case .verified(let tx):
                print("• LATEST VERIFIED for \(id)")
                print("  purchaseDate: \(tx.purchaseDate)")
                print("  expirationDate: \(String(describing: tx.expirationDate))")
                print("  revocationDate: \(String(describing: tx.revocationDate))")
            case .unverified(let tx, let err):
                print("• LATEST UNVERIFIED for \(id) error: \(err) (tx: \(tx))")
            case .none:
                print("• LATEST none for \(id)")
            }
        }

        print("──── \(label): END ENTITLEMENT DUMP ────")
    }
}
