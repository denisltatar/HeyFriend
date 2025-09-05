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

// MARK: - App Config / Keys
private enum AppConfig {
    static let appStoreID = "1234567890" // <-- replace with real numeric ID
}

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

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
                    Button {
                        // TODO: Present paywall / Plus screen
                        // e.g., show a sheet or navigate to a PaywallView()
                        // For now, just haptic feedback or placeholder
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showPaywall = true
                    } label: {
                        Label("Upgrade to Plus", systemImage: "sparkles")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
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
