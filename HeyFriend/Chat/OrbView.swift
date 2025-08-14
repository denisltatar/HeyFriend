//
//  OrbView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/13/25.
//

import Foundation
import SwiftUI

struct OrbView: View {
    enum OrbPhase: Equatable {
        case listening
        case responding
    }

    var state: OrbPhase

    // Appearance
    private let gradientColors = [
        Color(red: 0.85, green: 0.84, blue: 0.97), // soft lavender
        Color(red: 0.80, green: 0.88, blue: 0.98)  // pale blue
    ]
    
    @State private var time: Double = 0
    @State private var rippleScale: CGFloat = 0.95
    @State private var rippleOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Outer halo
            Circle()
                .fill(RadialGradient(colors: [gradientColors[1].opacity(0.2), .clear],
                                     center: .center, startRadius: 0, endRadius: 140))
                .blur(radius: 12)
                .opacity(0.03 + 0.02 * sin(time * 0.5)) // subtle breathing
            
            // Orb body
            Circle()
                .fill(RadialGradient(colors: gradientColors,
                                     center: .center, startRadius: 0, endRadius: 88))
                .overlay(
                    // Internal swirling particles
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let particleCount = 8
                        let swirlRadius: CGFloat = size.width * 0.35
                        let speedMultiplier = (state == .responding) ? 1.5 : 1.0
                        
                        for i in 0..<particleCount {
                            let angle = time * 0.15 * speedMultiplier + Double(i) * (Double.pi * 2 / Double(particleCount))
                            let x = center.x + swirlRadius * cos(angle)
                            let y = center.y + swirlRadius * sin(angle)
                            let particleRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                            
                            context.fill(Path(ellipseIn: particleRect),
                                         with: .color(.white.opacity(0.08)))
                        }
                    }
                )
                .overlay(
                    // Gentle ripple for responding state
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                )
        }
        .frame(width: 176, height: 176) // ~20% smaller
        .onAppear { startAnimations() }
        .onChange(of: state) { _ in handleStateChange() }
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 0.016).repeatForever(autoreverses: false)) {
            time += 1
        }
        handleStateChange()
    }
    
    private func handleStateChange() {
        switch state {
        case .listening:
            withAnimation(.easeInOut(duration: 0.4)) {
                rippleOpacity = 0.0
            }
        case .responding:
            withAnimation(.easeInOut(duration: 0.4)) {
                rippleOpacity = 1.0
            }
            // ripple pulse
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                rippleScale = 1.1
            }
        }
    }
}
