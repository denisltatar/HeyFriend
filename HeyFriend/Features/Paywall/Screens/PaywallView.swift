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
    static let yearlyID  = "com.heyfriend.plus.yearly"
    
    // StoreKit subscription group IDs
    static let subscriptionGroupIDLocal = "298AEF87"   // from Storekit-Local.storekit
    static let subscriptionGroupIDASC   = "21776835"   // from App Store Connect (numeric)
    
    static var subscriptionGroupID: String {
        #if DEBUG
        return subscriptionGroupIDLocal
        #else
        return subscriptionGroupIDASC
        #endif
    }
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
    
    // Helpful for alert when unsubscribing
    @State private var restoreMessage: String? = nil
    @State private var showingRestoreAlert = false
    @State private var isRestoring = false
    
    @State private var showingManageSheet = false

    @State private var willAutoRenew: Bool = true
//    var foundWillAutoRenew = true
//    
//    var foundActive = false
//    var foundProductId: String? = nil
//    var foundExpiresAt: Date? = nil
//    var foundWillAutoRenew = true



    var body: some View {
        ZStack {
            ScrollView {
                if entitlementsVM.isPlus {
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
                                if #available(iOS 17.0, *) {
                                    showingManageSheet = true
                                } else {
                                    openManageSubscriptions()
                                }
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
                          isRestoring: isRestoring,
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
            
            // ✅ Always re-check StoreKit and set hasPlus correctly
            if entitlementsVM.isPlus {
                await refreshPlusStatus()
            }
        }
        .applyManageSubscriptionsSheet(isPresented: $showingManageSheet, groupID: IAP.subscriptionGroupID)


        .alert("Restore Purchases", isPresented: $showingRestoreAlert) {
                Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
        .onDisappear {
            entitlementsVM.stop()
        }
        .onChange(of: showingManageSheet) { isShowing in
            if !isShowing {
                Task {
                    await refreshPlusStatus()
                }
            }
        }
        .onChange(of: hasPlus) { new in
            if new { dismiss() }
        }
    }

    // MARK: - StoreKit helpers

//    @MainActor
//    private func loadProducts() async {
//        errorText = nil
//        do {
//            let ids: [String] = [IAP.monthlyID, IAP.yearlyID]
//            print("🔎 Loading IAP products:", ids)
//
//            let fetched = try await Product.products(for: ids)
//
//            print("✅ Fetched:", fetched.map { "\($0.id) \($0.displayPrice)" })
//
//            // Sort for stable UI
//            self.products = fetched.sorted { $0.displayName < $1.displayName }
//
//            if fetched.isEmpty {
//                self.errorText = "No products returned. Check App Store Connect + build environment."
//            }
//        } catch {
//            print("❌ loadProducts error:", error)
//            self.errorText = "Failed to load products: \(error.localizedDescription)"
//        }
//    }
    
    private func loadProducts() async {
        do {
            let fetched = try await Product.products(for: [
                IAP.monthlyID,
                IAP.yearlyID
            ])
            print("Fetched products:", fetched.map { $0.id })
            products = fetched
        } catch {
            print("StoreKit error:", error)
            errorText = error.localizedDescription
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
        guard !isRestoring else { return }

        await MainActor.run {
            isRestoring = true
            restoreMessage = nil
            showingRestoreAlert = false
            errorText = nil
        }
        defer {
            Task { @MainActor in
                isRestoring = false
            }
        }

        // Light haptic to feel “real”
        await MainActor.run {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        do {
            // Single source of truth
            try await EntitlementSync.shared.restore()

            // Update the nicer Plus UI fields (plan, expiry, willAutoRenew)
            await refreshPlusStatus()

            let nowHasPlus = UserDefaults.standard.bool(forKey: "hf.hasPlus")

            await MainActor.run {
                restoreMessage = nowHasPlus
                    ? "Subscription restored ✅"
                    : "No active subscription found for this Apple ID.\n\nIf purchased on a different Apple ID, sign into that account and try again."
                showingRestoreAlert = true

                if nowHasPlus {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
        } catch {
            await MainActor.run {
                restoreMessage = "Restore failed. Please try again.\n\n\(error.localizedDescription)"
                showingRestoreAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }




    private func observeTransactionUpdates() async {
        // Keep local entitlement in sync with any changes (upgrades, renewals, refunds)
        for await result in Transaction.updates {
            if let tx = try? checkVerified(result) {
                // If active, apply it; otherwise refresh will clear hasPlus
                await applyEntitlementIfActive(tx)
                await tx.finish()
            }
            await refreshPlusStatus()
        }
    }

    private func applyEntitlementIfActive(_ tx: StoreKit.Transaction) async {
        guard tx.productType == .autoRenewable else { return }

        let isPlusProduct = (tx.productID == IAP.monthlyID) || (tx.productID == IAP.yearlyID)
        guard isPlusProduct else { return }

        let isValid = tx.revocationDate == nil &&
                      (tx.expirationDate ?? .distantFuture) > Date()

        guard isValid else { return }

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
        // 1) Find the active Plus entitlement (monthly OR yearly) with the latest expiration
        var bestTx: StoreKit.Transaction? = nil

        for await result in Transaction.currentEntitlements {
            guard let tx = try? checkVerified(result) else { continue }
            guard tx.productType == .autoRenewable else { continue }
            guard tx.productID == IAP.monthlyID || tx.productID == IAP.yearlyID else { continue }

            let isValid = tx.revocationDate == nil &&
                          (tx.expirationDate ?? .distantFuture) > Date()
            guard isValid else { continue }

            if let current = bestTx {
                let curExp = current.expirationDate ?? .distantFuture
                let newExp = tx.expirationDate ?? .distantFuture
                if newExp > curExp { bestTx = tx }
            } else {
                bestTx = tx
            }
        }

        // 2) Derive UI state from the best active entitlement
        let foundActive = (bestTx != nil)
        let foundProductId = bestTx?.productID
        let foundExpiresAt = bestTx?.expirationDate

        // 3) willAutoRenew: pull from Product.subscription.status (Transaction has no renewalInfo)
        var foundWillAutoRenew = true
        if let pid = foundProductId {
            foundWillAutoRenew = await fetchWillAutoRenew(for: pid)
        }

        // 4) Apply to UI on main thread
        await MainActor.run {
            hasPlus = foundActive
            plusProductId = foundProductId
            plusExpiresAt = foundExpiresAt
            willAutoRenew = foundWillAutoRenew

            if !foundActive {
                plusProductId = nil
                plusExpiresAt = nil
                willAutoRenew = true
            }
        }
    }


    
    private func fetchWillAutoRenew(for productID: String) async -> Bool {
        guard let product = products.first(where: { $0.id == productID }) else {
            return true // default fallback
        }

        do {
            guard let statuses = try await product.subscription?.status else {
                return true
            }

            // pick the best status (usually the “current” one)
            if let status = statuses.first {
                if case .verified(let renewalInfo) = status.renewalInfo {
                    return renewalInfo.willAutoRenew
                }
            }
        } catch {
            // ignore and fall back
        }

        return true
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
        guard let exp = resolvedExpiresAt else {
            return "Auto-renewing"
        }

        if willAutoRenew {
            return "Renews on \(exp.formatted(date: .long, time: .omitted))"
        } else {
            return "Cancelled — access until \(exp.formatted(date: .long, time: .omitted))"
        }
    }


    private func openManageSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }



    
}

private extension View {
    @ViewBuilder
    func applyManageSubscriptionsSheet(isPresented: Binding<Bool>, groupID: String) -> some View {
        if #available(iOS 17.0, *) {
            self.manageSubscriptionsSheet(isPresented: isPresented, subscriptionGroupID: groupID)
        } else {
            self
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
                    price: yearlyPrice.map { "\($0) / year (~$2.99/mo)" } ?? "Loading…",
                    isSelected: selected == "yearly"
                )
                .onTapGesture { selected = "yearly" }

                PricingOption(
                    title: "Monthly",
                    subtitle: "Cancel anytime",
                    price: monthlyPrice.map { "\($0) / month" } ?? "Loading…",
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
    let isRestoring: Bool
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
            .disabled(isPurchasing || isRestoring)

            Button {
                restoreAction()
            } label: {
                HStack(spacing: 8) {
                    if isRestoring {
                        ProgressView().controlSize(.small)
                    }
                    Text(isRestoring ? "Restoring…" : "Restore Subscription")
                }
                .font(.callout.weight(.semibold))
                .padding(.top, 6)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isPurchasing || isRestoring)

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
            Text("Restores paid subs only. Cancel anytime in Settings.")
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
