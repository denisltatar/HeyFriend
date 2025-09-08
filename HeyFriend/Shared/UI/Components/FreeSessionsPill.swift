//
//  FreeSessionsPill.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/8/25.
//

import SwiftUI

struct FreeSessionsPill: View {
    let isPlus: Bool
    let remaining: Int
    let limit: Int            // NEW: pass entitlements.freeLimit
    var onUpgradeTap: (() -> Void)?

    // Brand colors
    private let brandStart = Color(red: 1.00, green: 0.72, blue: 0.34) // amber
    private let brandEnd   = Color(red: 1.00, green: 0.45, blue: 0.00) // orange

    private var used: Int { max(limit - remaining, 0) }
    private var progress: CGFloat {
        guard limit > 0 else { return 0 }
        return CGFloat(min(max(Double(used) / Double(limit), 0), 1))
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(brandStart.opacity(0.18))
                Image(systemName: isPlus ? "infinity" : "gift.fill")
                    .font(.headline)
                    .foregroundStyle(LinearGradient(colors: [brandStart, brandEnd],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                if isPlus {
                    Text("Plus • Unlimited sessions")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("\(remaining) free session\(remaining == 1 ? "" : "s") left")
                        .font(.subheadline.weight(.semibold))

                    // Tiny progress bar (used / limit)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        GeometryReader { geo in
                            Capsule()
                                .fill(LinearGradient(colors: [brandStart, brandEnd],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                    .animation(.easeOut(duration: 0.25), value: progress)

                    Text("Used \(used) of \(limit)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !isPlus {
                Button(action: { onUpgradeTap?() }) {
                    Text("Upgrade")
                        .font(.footnote.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(LinearGradient(colors: [brandStart, brandEnd],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .foregroundStyle(.white)
                        .shadow(color: brandEnd.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain) // <- prevents system blue styling
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
