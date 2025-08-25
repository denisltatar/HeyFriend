//
//  OrbView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/14/25.
//

import Foundation
import SwiftUI

public struct OrbView: View {
    private let config: OrbConfiguration
    private let amplitude: CGFloat  // 0…1 mic/tts amplitude
    
    public init(configuration: OrbConfiguration = OrbConfiguration(), amplitude: CGFloat = 0) {
        self.config = configuration
        self.amplitude = amplitude
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate * max(0.1, config.offsetSpeed))

            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)

                ZStack {
                    if config.showBackground { background }
                    baseDepthGlows(size: size)

                    if config.showWavyBlobs {
                        wavyBlob
                        wavyBlobTwo
                    }

                    if config.showGlowEffects {
                        coreGlowEffects(size: size)
                    }

                    if config.showParticles {
                        particleView
                            .frame(maxWidth: size, maxHeight: size)
                    }
                }
                .overlay { realisticInnerGlows }
                .mask { Circle() }
                .aspectRatio(1, contentMode: .fit)
                .modifier(
                    RealisticShadowModifier(
                        colors: config.showShadow ? config.backgroundColors : [.clear],
                        radius: size * 0.08
                    )
                )
                // NEW: breathe + nudge
                .scaleEffect(1.0 + config.maxScaleBoost * amplitude, anchor: .center)
                .offset(x: offsetX(t: t), y: offsetY(t: t))
                .animation(.easeOut(duration: 0.08), value: amplitude) // snappy level response
            }
        }
    }

    private func offsetX(t: CGFloat) -> CGFloat {
        // small Lissajous-ish path; magnitude scales with amplitude
        let base = sin(t) * cos(t * 0.7)
        return base * config.maxOffset * amplitude
    }

    private func offsetY(t: CGFloat) -> CGFloat {
        let base = cos(t * 0.9)
        return base * config.maxOffset * amplitude
    }


    private var background: some View {
        LinearGradient(colors: config.backgroundColors,
                       startPoint: .bottom,
                       endPoint: .top)
    }

    private var orbOutlineColor: LinearGradient {
        LinearGradient(colors: [.white, .clear],
                       startPoint: .bottom,
                       endPoint: .top)
    }
    
    private var particleView: some View {
        // Added multiple particle effects since the blurring amounts are different
        ZStack {
            ParticlesView(
                color: config.particleColor,
                speedRange: 10...20,
                sizeRange: 0.5...1,
                particleCount: 10,
                opacityRange: 0...0.3
            )
            .blur(radius: 1)
            
            ParticlesView(
                color: config.particleColor,
                speedRange: 20...30,
                sizeRange: 0.2...1,
                particleCount: 10,
                opacityRange: 0.3...0.8
            )
        }
        .blendMode(.plusLighter)
    }

    private var wavyBlob: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            RotatingGlowView(color: .white.opacity(0.75),
                           rotationSpeed: config.speed * 1.5,
                           direction: .clockwise)
                .mask {
                    WavyBlobView(color: .white, loopDuration: 60 / config.speed * 1.75)
                        .frame(maxWidth: size * 1.875)
                        .offset(x: 0, y: size * 0.31)
                }
                .blur(radius: 1)
                .blendMode(.plusLighter)
        }
    }

    private var wavyBlobTwo: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            RotatingGlowView(color: .white,
                           rotationSpeed: config.speed * 0.75,
                           direction: .counterClockwise)
                .mask {
                    WavyBlobView(color: .white, loopDuration: 60 / config.speed * 2.25)
                        .frame(maxWidth: size * 1.25)
                        .rotationEffect(.degrees(90))
                        .offset(x: 0, y: size * -0.31)
                }
                .opacity(0.5)
                .blur(radius: 1)
                .blendMode(.plusLighter)
        }
    }

    private func coreGlowEffects(size: CGFloat) -> some View {
        ZStack {
            RotatingGlowView(color: config.glowColor,
                          rotationSpeed: config.speed * 3,
                          direction: .clockwise)
                .blur(radius: size * 0.08)
                .opacity(config.coreGlowIntensity)

            RotatingGlowView(color: config.glowColor,
                          rotationSpeed: config.speed * 2.3,
                          direction: .clockwise)
                .blur(radius: size * 0.06)
                .opacity(config.coreGlowIntensity)
                .blendMode(.plusLighter)
        }
        .padding(size * 0.08)
    }

    // New combined function replacing outerGlow and outerRing
    private func baseDepthGlows(size: CGFloat) -> some View {
        ZStack {
            // Outer glow (previously outerGlow function)
            RotatingGlowView(color: config.glowColor,
                          rotationSpeed: config.speed * 0.75,
                          direction: .counterClockwise)
                .padding(size * 0.03)
                .blur(radius: size * 0.06)
                .rotationEffect(.degrees(180))
                .blendMode(.destinationOver)
            
            // Outer ring (previously outerRing function)
            RotatingGlowView(color: config.glowColor.opacity(0.5),
                          rotationSpeed: config.speed * 0.25,
                          direction: .clockwise)
                .frame(maxWidth: size * 0.94)
                .rotationEffect(.degrees(180))
                .padding(8)
                .blur(radius: size * 0.032)
        }
    }

    private var realisticInnerGlows: some View {
        ZStack {
            // Outer stroke with heavy blur
            Circle()
                .stroke(orbOutlineColor, lineWidth: 8)
                .blur(radius: 32)
                .blendMode(.plusLighter)

            // Inner stroke with light blur
            Circle()
                .stroke(orbOutlineColor, lineWidth: 4)
                .blur(radius: 12)
                .blendMode(.plusLighter)
            
            Circle()
                .stroke(orbOutlineColor, lineWidth: 1)
                .blur(radius: 4)
                .blendMode(.plusLighter)
        }
        .padding(1)
    }
}

//#Preview {
//    let config = OrbConfiguration()
//    OrbView(configuration: config)
//        .aspectRatio(1, contentMode: .fit)
//        .frame(maxWidth: 120)
//}
