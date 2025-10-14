//
//  PaywallView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/5/25.
//

//
//  PaywallView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/5/25.
//

import Foundation
import SwiftUI
import StoreKit

// MARK: - Config
private enum IAP {
    static let monthlyID = "com.heyfriend.plus.monthly"
    static let yearlyID  = "com.heyfriend.plus.yearly" // remove if you didn't create it
}

private enum Brand {
    static let amber  = Color(red: 1.00, green: 0.72, blue: 0.34)
    static let orange = Color(red: 1.00, green: 0.45, blue: 0.00)
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    // Entitlement cache for quick gating across the app (simple local flag).
    // You can later replace this with a central StoreKit manager if you want.
    @AppStorage("hf.hasPlus") private var hasPlus = false

    // UI state
    @State private var isPurchasing = false
    @State private var errorText: String?
    @State private var selectedPlan: String = "yearly" // "yearly" or "monthly"

    // StoreKit state
    @State private var products: [Product] = []
    private var monthlyProduct: Product? { products.first { $0.id == IAP.monthlyID } }
    private var yearlyProduct: Product?  { products.first { $0.id == IAP.yearlyID  } }
    
    // Plus Status (for nicer "You're on Plus" UI)
    @State private var plusProductId: String?
    @State private var plusExpiresAt: Date?
    
    // Entitlement VM
    @StateObject private var entitlementsVM = EntitlementsViewModel()

    var body: some View {
        ZStack {
            ScrollView {
                if hasPlus {
                    // MARK: - Subscribed UI
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("You’re on ")
                                .font(.system(size: 32, weight: .bold)) +
                            Text("Plus").italic().foregroundStyle(Brand.orange)
                                .font(.system(size: 32, weight: .bold))
                        }
                        .multilineTextAlignment(.center)
                        .padding(.top, 30)

                        // Status Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(plusPlanLabel, systemImage: "sparkles")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .imageScale(.large)
                                    .foregroundStyle(Brand.orange)
                            }

                            Divider().opacity(0.25)

                            HStack(spacing: 10) {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(.secondary)
                                Text(plusRenewalLabel)
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }

                            if let pid = plusProductId {
                                HStack(spacing: 10) {
                                    Image(systemName: "number")
                                        .foregroundStyle(.secondary)
                                    Text(pid)
                                        .foregroundStyle(.secondary)
                                        .font(.footnote.monospaced())
                                }
                            }
                        }
                        .padding(16)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Brand.orange.opacity(0.15), lineWidth: 1)
                        )

                        // Your benefits (reuse the same component for visual parity)
                        FeatureList()

                        // Actions
                        VStack(spacing: 10) {
                            Button {
                                openManageSubscriptions()
                            } label: {
                                Text("Manage Subscription")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryGradientButtonStyle())

                            Button("Restore Purchases") {
                                Task {
                                    await restorePurchases()
                                    await refreshPlusStatus()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.top, 6)

                        LegalLinks()
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .onAppear {
                        // light haptic when viewing status
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } else {
                    // Existing upgrade flow (your current VStack with FeatureList, PricingPicker, CTASection, LegalLinks)
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            (Text("Upgrade to ") + Text("Plus").italic().foregroundStyle(Brand.orange))
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 30)

                        FeatureList()
                        PricingPicker(
                            selected: $selectedPlan,
                            yearlyPrice: yearlyProduct?.displayPrice,
                            monthlyPrice: monthlyProduct?.displayPrice
                        )
                        CTASection(
                            selectedPlan: selectedPlan,
                            isPurchasing: isPurchasing,
                            errorText: errorText,
                            purchaseAction: { plan in Task { await purchaseSelected(plan) } },
                            restoreAction: { Task { await restorePurchases() } }
                        )
                        .padding(.top, 6)
                        LegalLinks()
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

            }
        }
        .task {
            // Obtaining entitlements to update paywall/settings
            entitlementsVM.start()
            await loadProducts()
            await observeTransactionUpdates()
            if hasPlus {
                await refreshPlusStatus()
            }
        }
        .onDisappear {
            entitlementsVM.stop()
        }
        .onChange(of: hasPlus) { new in
            if new { dismiss() }
        }
    }

    // MARK: - StoreKit helpers

    private func loadProducts() async {
        do {
            print("IDs:", [IAP.monthlyID, IAP.yearlyID])
            let fetched = try await Product.products(for: [IAP.monthlyID, IAP.yearlyID])
            print("Fetched count:", fetched.count)
            for p in fetched { print("→", p.id, p.displayName, p.displayPrice) }
            
            var ids: Set<String> = [IAP.monthlyID]
            if !IAP.yearlyID.isEmpty { ids.insert(IAP.yearlyID) }
            products = try await Product.products(for: ids)
                .sorted { $0.displayName < $1.displayName }
        } catch {
            errorText = "Failed to load products: \(error.localizedDescription)"
        }
    }

    private func purchaseSelected(_ plan: String) async {
        errorText = nil
        guard let product = (plan == "yearly" ? yearlyProduct : monthlyProduct) ?? monthlyProduct else {
            errorText = "Plan unavailable right now. Please try again."
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                // Verify Apple’s signed transaction
                let transaction: StoreKit.Transaction = try checkVerified(verification)
                // Mark entitlement
                await applyEntitlementIfActive(transaction)
                // Always finish
                await transaction.finish()
                // Dismiss if unlocked
                if hasPlus { dismiss() }
            case .userCancelled:
                break
            case .pending:
                errorText = "Purchase pending…"
            @unknown default:
                errorText = "Unknown purchase state."
            }
        } catch {
            errorText = "Purchase failed: \(error.localizedDescription)"
        }
    }

    private func restorePurchases() async {
        errorText = nil
        do {
            try await AppStore.sync()
            // Write free plan if no active plan is found
            var foundActive = false
            // Re-scan current entitlements
            for await result in Transaction.currentEntitlements {
                if let tx = try? checkVerified(result) {
                    await applyEntitlementIfActive(tx)
                    if hasPlus { foundActive = true }
                }
            }
            if !foundActive, let uid = AuthService.shared.userId {
                try? await FirestoreService.shared.setFree(uid: uid)
            }
        } catch {
            errorText = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func observeTransactionUpdates() async {
        // Keep local entitlement in sync with any changes (upgrades, renewals, refunds)
        for await result in Transaction.updates {
            if let tx = try? checkVerified(result) {
                await applyEntitlementIfActive(tx)
                await tx.finish()
            }
        }
    }

    private func applyEntitlementIfActive(_ tx: StoreKit.Transaction) async {
        guard [.autoRenewable].contains(tx.productType) else { return }
        // Make sure this transaction is for one of our Plus products and still valid
        let isPlusProduct = (tx.productID == IAP.monthlyID) || (tx.productID == IAP.yearlyID)
        let isValid = tx.productType == .autoRenewable &&
                      isPlusProduct &&
                      tx.revocationDate == nil &&
                      (tx.expirationDate ?? .distantFuture) > Date()

        if isValid {
            hasPlus = true
            if let uid = AuthService.shared.userId {
                let original = tx.originalID ?? tx.id
                try? await FirestoreService.shared.setPlus(
                    uid: uid,
                    productId: tx.productID,
                    originalTransactionId: String(original),
                    expiresAt: tx.expirationDate
                )
            }
        } else {
            hasPlus = false
            if let uid = AuthService.shared.userId {
                try? await FirestoreService.shared.setFree(uid: uid)
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "StoreKit", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Transaction unverified"])
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Plus Status (for nicer "You're on Plus" UI)

    private func refreshPlusStatus() async {
        // Scan active entitlements and capture our Plus line item
        for await result in Transaction.currentEntitlements {
            if let tx = try? checkVerified(result) {
                guard tx.productType == .autoRenewable else { continue }
                let isPlus = (tx.productID == IAP.monthlyID) || (tx.productID == IAP.yearlyID)
                guard isPlus, tx.revocationDate == nil, (tx.expirationDate ?? .distantFuture) > Date() else { continue }
                await MainActor.run {
                    self.plusProductId = tx.productID
                    self.plusExpiresAt = tx.expirationDate
                }
            }
        }
    }

    private var resolvedProductId: String? {
        // Prefer live StoreKit; fall back to Firestore VM
        plusProductId ?? entitlementsVM.productId
    }

    private var resolvedExpiresAt: Date? {
        plusExpiresAt ?? entitlementsVM.expiresAt
    }

    private var plusPlanLabel: String {
        switch resolvedProductId {
        case IAP.yearlyID?:  return "Plus • Yearly"
        case IAP.monthlyID?: return "Plus • Monthly"
        case .some:          return "Plus"
        case .none:          return "Plus"
        }
    }

    private var plusRenewalLabel: String {
        if let exp = resolvedExpiresAt {
            return "Renews on \(exp.formatted(date: .long, time: .omitted))"
        }
        return "Auto-renewing"
    }

    private func openManageSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }



    
}

// MARK: - Components

private struct FeatureList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            (Text("What you get with ") + Text("Plus").italic().foregroundStyle(Brand.orange))
                .font(.title3.weight(.semibold))

            VStack(spacing: 10) {
                BulletRow(icon: "timer", title: "Unlimited sessions up to 20 min per session")
                BulletRow(icon: "chart.line.uptrend.xyaxis", title: "Richer insights over time")
                BulletRow(icon: "brain.head.profile", title: "Emotion & personality analysis")
                BulletRow(icon: "folder.badge.person.crop", title: "Long-term memory updates")
                BulletRow(icon: "lock.shield", title: "Secure cloud backup")
                BulletRow(icon: "sparkles", title: "Early access to new features")
                BulletRow(icon: "person.2.fill", title: "Priority support")
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct BulletRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .symbolRenderingMode(.monochrome)
                .renderingMode(.template)
                .foregroundStyle(Brand.orange)
                .imageScale(.medium)

            Text(title)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}

private struct PricingPicker: View {
    @Binding var selected: String  // "monthly" or "yearly"
    var yearlyPrice: String?
    var monthlyPrice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a plan")
                .font(.title3.weight(.semibold))

            VStack(spacing: 12) {
                
                PricingOption(
                    title: "Yearly",
                    subtitle: "Best value • Save 50%",
                    price: yearlyPrice.map { "\($0) / year (~$4.99/mo)" } ?? "—",
                    isSelected: selected == "yearly"
                )
                .onTapGesture { selected = "yearly" }

                PricingOption(
                    title: "Monthly",
                    subtitle: "Cancel anytime",
                    price: monthlyPrice.map { "\($0) / month" } ?? "—",
                    isSelected: selected == "monthly"
                )
                .onTapGesture { selected = "monthly" }
            }
        }
    }
}

private struct PricingOption: View {
    let title: String
    let subtitle: String
    let price: String
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(price).font(.headline)
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .imageScale(.large)
                .foregroundColor(isSelected ? Brand.orange : .secondary)
                .padding(.leading, 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isSelected ? Brand.orange.opacity(0.7) : .clear, lineWidth: 2)
                )
        )
    }
}

private struct CTASection: View {
    let selectedPlan: String
    let isPurchasing: Bool
    let errorText: String?
    let purchaseAction: (_ plan: String) -> Void
    let restoreAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button {
                purchaseAction(selectedPlan)
            } label: {
                if isPurchasing {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Processing…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Continue with \(selectedPlan.capitalized) Plan")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryGradientButtonStyle())
            .controlSize(.regular)
            .disabled(isPurchasing)

            Button("Restore Purchases", action: restoreAction)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
}

private struct LegalLinks: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Recurring billing. Cancel anytime in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Link("Privacy Policy", destination: URL(string: "https://heyfriend-website.vercel.app/privacy")!)
                // Deep link to Apple subscription management
//                Link("Manage Subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PrimaryGradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Brand.amber, Brand.orange
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .shadow(color: Brand.amber.opacity(0.35), radius: 10, x: 0, y: 6)
            .opacity(isEnabled ? 1.0 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
