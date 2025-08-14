//
//  OrbView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/13/25.
//

import Foundation
import SwiftUI

struct OrbView: View {
    enum OrbPhase {
        case idle
        case listening                // mic on, no amplitude
        case userSpeaking(level: CGFloat) // level 0...1
        case thinking                 // after user finishes, before TTS
        case aiSpeaking               // during TTS playback
        case paused
    }

    var state: OrbPhase

    // Visual tokens
    private let core = HF.amber
    private let haloMid = HF.amberMid
    private let haloOuter = HF.amberSoft

    @State private var baseScale: CGFloat = 1
    @State private var yHover: CGFloat = 0
    @State private var rotation: Angle = .degrees(0)

    var body: some View {
        ZStack {
            // Outer ambient halo
            Circle()
                .fill(radialHalo)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)
                .blur(radius: 22)
                .blendMode(.plusLighter)

            // Core orb with subtle light sweep
            Circle()
                .fill(coreGradient)
                .overlay(lightSweep.mask(Circle()))
                .scaleEffect(coreScale)
                .shadow(color: haloOuter.opacity(0.25), radius: 40, x: 0, y: 12)
        }
        .frame(width: 220, height: 220)
        .offset(y: yHover)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                baseScale = 1.02
            }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                yHover = 2
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = .degrees(360)
            }
        }
    }

    // MARK: - Drawing

    private var coreScale: CGFloat {
        switch state {
        case .idle: return baseScale
        case .listening: return baseScale * 1.01
        case .userSpeaking(let lvl): return baseScale * (1.0 + 0.03 * min(lvl, 1))
        case .thinking: return baseScale * 1.0
        case .aiSpeaking: return baseScale * 1.04
        case .paused: return baseScale
        }
    }

    private var haloScale: CGFloat {
        switch state {
        case .userSpeaking(let lvl): return 1.2 + 0.2 * min(lvl, 1)
        case .aiSpeaking: return 1.25
        case .listening: return 1.15
        case .thinking: return 1.1
        case .idle: return 1.1
        case .paused: return 1.05
        }
    }

    private var haloOpacity: Double {
        switch state {
        case .paused: return 0.10
        case .thinking: return 0.18
        case .idle: return 0.20
        case .listening: return 0.25
        case .userSpeaking(let lvl): return 0.20 + 0.15 * Double(min(lvl, 1))
        case .aiSpeaking: return 0.28
        }
    }

    private var radialHalo: RadialGradient {
        RadialGradient(colors: [haloMid, haloOuter.opacity(0.0)],
                       center: .center, startRadius: 10, endRadius: 170)
    }

    private var coreGradient: RadialGradient {
        RadialGradient(colors: [core, core.opacity(0.7)],
                       center: .center, startRadius: 0, endRadius: 110)
    }

    private var lightSweep: some View {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .white.opacity(0.0),  location: 0.00),
                .init(color: .white.opacity(0.35), location: 0.08),
                .init(color: .white.opacity(0.0),  location: 0.16),
                .init(color: .white.opacity(0.0),  location: 1.00),
            ]),
            center: .center,
            angle: rotation
        )
    }
}
