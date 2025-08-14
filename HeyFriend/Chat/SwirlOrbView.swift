//
//  SwirlOrbView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/13/25.
//

import Foundation
import SwiftUI

struct SwirlOrbView: View {
    private let size: CGFloat = 176

    // Palette (muted amber by default—swap to your lavender/blue if you prefer)
//    private let fill1 = HF.amber       // or Color(red:0.85, green:0.84, blue:0.97)
//    private let fill2 = HF.amberMid    // or Color(red:0.80, green:0.88, blue:0.98)
//    private let halo  = HF.amberSoft
    
    private let fill1 = Color(red: 1.0, green: 0.78, blue: 0.28)   // warm golden yellow
    private let fill2 = Color(red: 1.0, green: 0.55, blue: 0.0)    // deep orange
    private let halo  = Color(red: 1.0, green: 0.68, blue: 0.2)    // softer glow



    var body: some View {
        ZStack {
            // Soft outer halo
            Circle()
                .fill(RadialGradient(colors: [halo.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: size))
                .blur(radius: 24)
                .opacity(0.18)
                .blendMode(.plusLighter)

            // Orb body + internal swirl
            Circle()
                .fill(RadialGradient(colors: [fill1, fill2.opacity(0.85)],
                                     center: .center, startRadius: 0, endRadius: size*0.48))
                .overlay(internalSwirl.mask(Circle()))
                .overlay(
                    // Glassy highlight
                    RadialGradient(colors: [.white.opacity(0.25), .clear],
                                   center: .topLeading, startRadius: 6, endRadius: size*0.7)
                        .blendMode(.screen)
                )
                .overlay(Circle().stroke(halo.opacity(0.45), lineWidth: 0.8))
                .shadow(color: halo.opacity(0.25), radius: 30, x: 0, y: 10)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - Swirl (metaball glow points that orbit smoothly)
    private var internalSwirl: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, sz in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: sz.width/2, y: sz.height/2)
                let R = min(sz.width, sz.height) * 0.35     // orbit radius
                let count = 9                                // number of glow points

                for i in 0..<count {
                    // Stable pseudo-random per index for variety
                    let base = hash01(i)                     // 0…1
                    let phase = Double(i) * (.pi * 2 / Double(count))
                    // Smooth orbital angular speed (two layers for parallax)
                    let w = 0.18 + 0.06 * cos(phase * 1.7)
                    let angle = phase + w * t

                    // Slight radial breathing per particle
                    let rJitter = 1 + 0.06 * sin(t * 0.6 + Double(i)*0.9)

                    // Position
                    let cx = center.x + (R * rJitter) * cos(angle)
                    let cy = center.y + (R * rJitter) * sin(angle)

                    // Size (varies by index)
                    let radius = CGFloat(10 + 12 * base)     // 10–22 pt

                    // Color mix (subtle)
                    let c1 = fill1.opacity(0.90)
                    let c2 = fill2.opacity(0.75)
                    let grad = Gradient(colors: [c1, c2, .clear])

                    let shading = GraphicsContext.Shading.radialGradient(
                        grad,
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: radius
                    )

                    let rect = CGRect(x: cx - radius, y: cy - radius,
                                      width: radius*2, height: radius*2)
                    ctx.fill(Path(ellipseIn: rect), with: shading)
                }

                // Super‑subtle inner mist to unify the liquid
                let mist = GraphicsContext.Shading.radialGradient(
                    Gradient(colors: [fill2.opacity(0.15), .clear]),
                    center: center, startRadius: 0, endRadius: R * 1.4
                )
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - R*1.4,
                                                y: center.y - R*1.4,
                                                width: R*2.8, height: R*2.8)), with: mist)
            }
        }
    }

    // Stable hash for per-index variation (no state needed)
    private func hash01(_ i: Int) -> Double {
        let x = sin(Double(i) * 12.9898) * 43758.5453
        return x - floor(x)
    }
}
