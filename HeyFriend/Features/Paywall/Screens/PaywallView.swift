//
//  PaywallView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/5/25.
//

import Foundation
import SwiftUI

private enum Brand {
    static let amber  = Color(red: 1.00, green: 0.72, blue: 0.34)
    static let orange = Color(red: 1.00, green: 0.45, blue: 0.00) // use this for the stroke/tint
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var errorText: String?
    @State private var selectedPlan: String = "yearly" // "yearly" or "monthly"

    var body: some View {
        ZStack {
            // Background: soft warm gradient to match your theme
//            LinearGradient(
//                colors: [
//                    Color.orange.opacity(0.25),
//                    Color(red: 1.0, green: 0.75, blue: 0.45).opacity(0.25)
//                ],
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
//            )
//            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header / Hero
                    VStack(spacing: 8) {
                        (
                            Text("Upgrade to ") +
                            Text("Plus")
                                .italic()
                                .foregroundStyle(Brand.orange)   // or .foregroundColor(Brand.orange)
                        )
                        .font(.system(size: 32, weight: .bold))
                        .multilineTextAlignment(.center)
//                        Text("Faster replies, longer sessions, and deeper insights—designed to help you build lasting habits.")
//                            .font(.callout)
//                            .foregroundStyle(.secondary)
//                            .multilineTextAlignment(.center)
                        
                    }
                    .padding(.top, 30)

                    // Optional: your orb/glow background element if you want
                    // OrbView(configuration: .init.presetWarmSunset)
                    //     .frame(height: 120)
                    //     .padding(.vertical, 8)

                    FeatureList()

                    PricingPicker(selected: $selectedPlan)

                    CTASection(
                        selectedPlan: selectedPlan,
                        isPurchasing: isPurchasing,
                        errorText: errorText,
                        purchaseAction: purchaseSelected
//                        restoreAction: restorePurchases
                    )
                    .padding(.top, 6)

                    LegalLinks()
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
//            .overlay(alignment: .topTrailing) {
//                Button {
//                    dismiss()
//                } label: {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.system(size: 26, weight: .semibold))
//                        .foregroundStyle(.secondary)
//                        .padding(16)
//                }
//                .accessibilityLabel("Close")
//            }
        }
    }

    // MARK: - Actions (temporary stubs)
    private func purchaseSelected(_ plan: String) {
        // TODO: Map plan -> productID and call StoreKit when products are ready.
        // For now, simulate a successful purchase and dismiss.
        isPurchasing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isPurchasing = false
            print("Purchased plan: \(plan == "yearly" ? "Yearly ($59.99)" : "Monthly ($9.99)")")
            dismiss()
        }
    }

    private func restorePurchases() {
        // TODO: Hook up to StoreKit restore flow later.
        print("Restore purchases tapped")
    }
}

// MARK: - Components

private struct FeatureList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            (
                Text("What you get with ") +
                Text("Plus").italic().foregroundStyle(Brand.orange) // or .foregroundColor(Brand.orange)
            )
            .font(.title3.weight(.semibold))

            VStack(spacing: 10) {
//                BulletRow(icon: "bolt.fill", title: "Faster responses")
//                BulletRow(icon: "timer", title: "Longer, deeper sessions")
                BulletRow(icon: "timer", title: "Unlimited sessions up to 45 min per session")
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
                .symbolRenderingMode(.monochrome) // force single-color symbols
                .renderingMode(.template)         // ensure it uses our color
                .foregroundStyle(Brand.orange)    // <-- only the icon is orange
                .imageScale(.medium)

            Text(title)
                .foregroundStyle(.primary)        // keep text default color
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}

private struct PricingPicker: View {
    @Binding var selected: String  // "monthly" or "yearly"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a plan")
                .font(.title3.weight(.semibold))

            VStack(spacing: 12) {
                PricingOption(
                    title: "Yearly",
                    subtitle: "Best value • Save 50%",
                    price: "$59.99 / year (~$5/mo)",
                    isSelected: selected == "yearly"
                )
                .onTapGesture { selected = "yearly" }

                PricingOption(
                    title: "Monthly",
                    subtitle: "Cancel anytime",
                    price: "$9.99 / month",
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
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(price)
                .font(.headline)
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
//    let restoreAction: () -> Void

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
            .controlSize(.large)
            .disabled(isPurchasing)

//            Button("Restore purchases", action: restoreAction)
//                .buttonStyle(.plain)
//                .foregroundStyle(.secondary)

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
        VStack(spacing: 4) {
            Text("Recurring billing. Cancel anytime in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
//                Link("Terms", destination: URL(string: "https://heyfriend-website.vercel.app/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://heyfriend-website.vercel.app/privacy")!)
//                Link("Restore", destination: URL(string: "https://support.apple.com/en-us/HT202039")!)
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
                        Color(red: 1.00, green: 0.72, blue: 0.34), // amber
                        Color(red: 1.00, green: 0.45, blue: 0.00)  // orange
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .shadow(color: Color(red: 1.00, green: 0.65, blue: 0.20).opacity(0.35),
                    radius: 10, x: 0, y: 6)
            .opacity(isEnabled ? 1.0 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

