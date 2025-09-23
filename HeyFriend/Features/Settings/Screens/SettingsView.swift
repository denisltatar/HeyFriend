//
//  SettingsView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI
import StoreKit
import LocalAuthentication
import FirebaseAuth

// MARK: - App Config / Keys
private enum AppConfig {
    static let appStoreID = "1234567890" // <-- replace with real numeric ID
}

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    
    // Trial/Plus state
    @Environment(\.scenePhase) private var scenePhase   // ← provides scenePhase
    @StateObject private var entitlements = EntitlementsViewModel()
    @AppStorage("hf.hasPlus") private var hasPlus = false   // ← added as a quick fallback

    // Persisted settings
    @AppStorage(SettingsKeys.requireBiometricsForInsights) private var requireBiometrics = false
    @AppStorage(SettingsKeys.appAppearance) private var appearanceRaw = AppAppearance.system.rawValue
    
    // Paywall display
    @State private var showPaywall = false
    
    
    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // 🔒 Privacy & Security
//                Section("Privacy & Security") {
//                    Toggle(isOn: Binding(
//                        get: { requireBiometrics },
//                        set: { newValue in
//                            if newValue {
//                                Biometrics.requireAuth { success in
//                                    if success {
//                                        requireBiometrics = true
//                                    } else {
//                                        // Revert if auth fails/cancelled
//                                        requireBiometrics = false
//                                    }
//                                }
//                            } else {
//                                requireBiometrics = false
//                            }
//                        })) {
//                            Label("Require Face ID / Touch ID for Insights", systemImage: "faceid")
//                        }
//                }

                // 🎨 Personalization
                Section("Personalization") {
                    Picker(selection: appearanceBinding,
                          label: Label("Theme", systemImage: "paintpalette")) {
                       ForEach(AppAppearance.allCases) { style in
                           Text(style.label).tag(style)
                       }
                   } .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
                

                // 💳 Subscription / Billing
                Section("Subscription") {
                    if entitlements.isPlus {
                        Button {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                openURL(url)
                            }
                        } label: {
                            Label("Manage Plus Subscription", systemImage: "sparkles")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        
                        Button {
                            showPaywall = true   // reuse your existing sheet
                        } label: {
                            Label("View your plan", systemImage: "person.badge.shield.checkmark")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showPaywall = true
                        } label: {
                            Label("Upgrade to Plus", systemImage: "sparkles")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                    }
                    

//                    Button {
//                        // TODO: Present paywall / Plus screen
//                        // e.g., show a sheet or navigate to a PaywallView()
//                        // For now, just haptic feedback or placeholder
//                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                        showPaywall = true
//                    } label: {
//                        Label("Upgrade to Plus", systemImage: "sparkles")
//                    }
//                    .buttonStyle(.plain)
//                    .foregroundStyle(.primary)
                    
//                    FreeSessionsPill(
//                        isPlus: entitlements.isPlus,
//                        remaining: entitlements.remaining,
//                        limit: entitlements.freeLimit,
//                        onUpgradeTap: { showPaywall = true }
//                    )
//                    .padding(.horizontal, 17)
//                    .padding(.top, 4)
                }
                
                

                // 📣 Support & Community
                Section("Support & Policies") {
                    Button {
                        if let url = URL(string: "https://heyfriend-website.vercel.app/privacy") {
                            openURL(url)
                        }
                    } label: {
                        Label("Privacy Policy & Terms of Service", systemImage: "doc.text")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }

                // Feedback (Rate this app)
                Section("Feedback") {
                    Button {
                        if let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        } else {
                            requestReview()
                        }
                    } label: {
                        Label("Rate this app", systemImage: "star.leadinghalf.filled")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    Button {
                        let urlString = "itms-apps://itunes.apple.com/app/id\(AppConfig.appStoreID)?action=write-review"
                        if let url = URL(string: urlString) { openURL(url) }
                    } label: {
                        Label("Write a review on the App Store", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
                
                // About (kept minimal)
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
//                    HStack {
//                        Text("Build")
//                        Spacer()
//                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
//                            .foregroundStyle(.secondary)
//                    }
                }

                // Spacer section before bottom button
                Section { EmptyView() }
                
                // Sign Out button
                Section {
                    Button(role: .destructive) {
                        auth.signOut() }
                    label: {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
//            .safeAreaInset(edge: .bottom) {
//                Button(role: .destructive) {
//                    auth.signOut()
//                } label: {
//                    Text("Sign Out")
//                        .frame(maxWidth: .infinity)
//                }
//                .buttonStyle(.borderedProminent)
//                .tint(.red)
//                .padding()
//            }
        }
        .task { entitlements.start() }          // ← start listening
        // For payment testing
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, let u = Auth.auth().currentUser, !u.isAnonymous {
                Task {
                    await EntitlementSync.shared.debugDumpEntitlements(label: "Foreground")
//                    await EntitlementSync.shared.restore()         // force receipt
                    await EntitlementSync.shared.refresh()
                    await EntitlementSync.shared.debugDumpEntitlements(label: "After Restore+Refresh")
                }
                
            }
        }
        .onDisappear { entitlements.stop() }    // ← optional: clean up
    }
}

// MARK: - Biometrics Helper
private enum Biometrics {
    static func requireAuth(completion: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        var error: NSError?
        let reason = "Confirm it’s you to enable biometric protection for Insights."

        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false)
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}
