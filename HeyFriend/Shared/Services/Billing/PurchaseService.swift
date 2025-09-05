//
//  PurchaseService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/5/25.
//

import Foundation
import StoreKit

actor PurchaseService {
    static let shared = PurchaseService()

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            _ = try check(verification) // throws if invalid
            // Optionally refresh entitlements here
        case .userCancelled, .pending:
            return
        @unknown default:
            return
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        // Optionally re-check entitlements
    }

    private func check<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, _):
            throw NSError(domain: "PurchaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transaction unverified"])
        case .verified(let safe):
            return safe
        }
    }
}
