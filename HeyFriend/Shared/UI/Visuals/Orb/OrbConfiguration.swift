//
//  OrbConfiguration.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/14/25.
//

import Foundation

import SwiftUI

public struct OrbConfiguration {
    public let glowColor: Color
    public let backgroundColors: [Color]
    public let particleColor: Color
    
    public let showBackground: Bool
    public let showWavyBlobs: Bool
    public let showParticles: Bool
    public let showGlowEffects: Bool
    public let showShadow: Bool
    
    public let coreGlowIntensity: Double
    public let speed: Double
    
    // NEW: mic-reactivity knobs
    // How much the orb “breathes” (grows) at peak volume.
    public let maxScaleBoost: CGFloat   // e.g. 0.10 → +10% at full amplitude
    // The biggest distance (in points) the orb is allowed to wander from center while it wiggles.
    public let maxOffset: CGFloat       // e.g. 6pt lateral/vertical nudge
    // A speed multiplier for the wiggle motion (not the size).
    public let offsetSpeed: Double      // how “wiggly” the offset feels

    internal init(
        backgroundColors: [Color],
        glowColor: Color,
        particleColor: Color,
        coreGlowIntensity: Double,
        showBackground: Bool,
        showWavyBlobs: Bool,
        showParticles: Bool,
        showGlowEffects: Bool,
        showShadow: Bool,
        speed: Double,
        maxScaleBoost: CGFloat,
        maxOffset: CGFloat,
        offsetSpeed: Double
    ) {
        self.backgroundColors = backgroundColors
        self.glowColor = glowColor
        self.particleColor = particleColor
        self.showBackground = showBackground
        self.showWavyBlobs = showWavyBlobs
        self.showParticles = showParticles
        self.showGlowEffects = showGlowEffects
        self.showShadow = showShadow
        self.coreGlowIntensity = coreGlowIntensity
        self.speed = speed
        self.maxScaleBoost = maxScaleBoost
        self.maxOffset = maxOffset
        self.offsetSpeed = offsetSpeed
    }
    
    public init(
        backgroundColors: [Color] = [.green, .blue, .pink],
        glowColor: Color = .white,
        coreGlowIntensity: Double = 1.0,
        showBackground: Bool = true,
        showWavyBlobs: Bool = true,
        showParticles: Bool = true,
        showGlowEffects: Bool = true,
        showShadow: Bool = true,
        speed: Double = 60,
        // NEW defaults
        maxScaleBoost: CGFloat = 0.35,
        maxOffset: CGFloat = 3,
        offsetSpeed: Double = 1.15
    ) {
        self.init(
            backgroundColors: backgroundColors,
            glowColor: glowColor,
            particleColor: .white,
            coreGlowIntensity: coreGlowIntensity,
            showBackground: showBackground,
            showWavyBlobs: showWavyBlobs,
            showParticles: showParticles,
            showGlowEffects: showGlowEffects,
            showShadow: showShadow,
            speed: speed,
            maxScaleBoost: maxScaleBoost,
            maxOffset: maxOffset,
            offsetSpeed: offsetSpeed
        )
    }
}
