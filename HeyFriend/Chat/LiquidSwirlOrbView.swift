//
//  LiquidSwirlOrbView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/13/25.
//

import Foundation
// LiquidSwirlOrbView — Remake v1 (single‑liquid, richer motion)
// Goal: match a "liquid cream in coffee" vibe with richer motion but no visible rings.
// - Listening: calm, clockwise swirl with organic drift, soft parallax
// - Responding: same swirl, faster + soft core pulse (no ring outline)
// - Optional `level` (0..1) subtly stirs speed/density with voice energy
// Drop-in compatible with your ChatView usage.

import SwiftUI
import QuartzCore
import UIKit

public struct LiquidSwirlOrbView: View {
    public enum Mode { case listening, responding }
    public var mode: Mode = .listening
    public var size: CGFloat = 176
    public var level: CGFloat = 0 // optional 0..1

    public init(mode: Mode = .listening, size: CGFloat = 176, level: CGFloat = 0) {
        self.mode = mode
        self.size = size
        self.level = level
    }

    public var body: some View {
        Representable(mode: mode, size: size, level: level)
            .frame(width: size, height: size)
    }
}

// MARK: - Bridge
private struct Representable: UIViewRepresentable {
    let mode: LiquidSwirlOrbView.Mode
    let size: CGFloat
    let level: CGFloat

    func makeUIView(context: Context) -> LiquidSwirlView {
        let v = LiquidSwirlView(frame: .init(x: 0, y: 0, width: size, height: size))
        v.configure(size: size)
        v.apply(mode: mode, animated: false)
        v.setLevel(level)
        return v
    }

    func updateUIView(_ uiView: LiquidSwirlView, context: Context) {
        uiView.apply(mode: mode, animated: true)
        uiView.setLevel(level)
    }
}

// MARK: - Core View
final class LiquidSwirlView: UIView {
    // MARK: Palette
    private let inner = UIColor(red: 1.00, green: 0.72, blue: 0.34, alpha: 1.0) // amber
    private let outer = UIColor(red: 1.00, green: 0.45, blue: 0.00, alpha: 0.95) // orange
    private let haloC  = UIColor(red: 1.00, green: 0.65, blue: 0.20, alpha: 1.0)

    // Direction personality: +1 clockwise, -1 counter
    private let swirlDirection: CGFloat = 1.0

    private var current: LiquidSwirlOrbView.Mode = .listening
    private var radius: CGFloat = 88

    // Layers
    private let halo = CAGradientLayer()
    private let orbFill = CAGradientLayer()

    private let liquidContainer = CALayer() // main swirl container
    private let liquidA = CAEmitterLayer()  // base cloud
    private let liquidB = CAEmitterLayer()  // subtle parallax cloud (slightly different params)

    private let brightness = CAGradientLayer() // off-center, subtle
    private let centerShade = CAGradientLayer() // gentle center darken
    private let tintSpin = CAGradientLayer() // rotating tint to fake color swirl

    private let rim = CAShapeLayer()

    // Dynamics
    private var baseRotation: Double = 5.8 // seconds per rotation
    private var lastLevel: CGFloat = 0

    override class var layerClass: AnyClass { CALayer.self }

    // MARK: Setup
    func configure(size: CGFloat) {
        backgroundColor = .clear
        radius = size * 0.5

        // Halo
        halo.type = .radial
        halo.colors = [haloC.withAlphaComponent(0.20).cgColor, UIColor.clear.cgColor]
        halo.locations = [0, 1]
        halo.frame = bounds.insetBy(dx: -size*0.28, dy: -size*0.28)
        layer.addSublayer(halo)
        breathHalo()

        // Orb base gradient
        orbFill.type = .radial
        orbFill.colors = [inner.cgColor, outer.cgColor]
        orbFill.locations = [0, 1]
        orbFill.frame = bounds
        orbFill.cornerRadius = radius
        orbFill.masksToBounds = true
        layer.addSublayer(orbFill)

        // Liquid cloud (volume emission)
        liquidContainer.frame = bounds
        orbFill.addSublayer(liquidContainer)

        // Base cloud A — the main body
        configureCloud(liquidA, emitterSize: 0.68, alpha: 0.075, vel: 10, birth: 20, blobSize: 150, blur: 26, centerAlpha: 0.58)
        liquidContainer.addSublayer(liquidA)

        // Parallax cloud B — fewer, larger, slightly slower to imply depth
        configureCloud(liquidB, emitterSize: 0.70, alpha: 0.060, vel: 8, birth: 12, blobSize: 170, blur: 30, centerAlpha: 0.55)
        liquidB.zPosition = -1 // behind A
        liquidContainer.addSublayer(liquidB)

        // Subtle off‑center highlight (soft light)
        brightness.type = .radial
        brightness.colors = [UIColor.white.withAlphaComponent(0.06).cgColor, UIColor.clear.cgColor]
        brightness.locations = [0, 1]
        brightness.frame = bounds.insetBy(dx: size * 0.10, dy: size * 0.10)
        brightness.cornerRadius = (radius - size * 0.10)
        brightness.startPoint = CGPoint(x: 0.34, y: 0.30)
        brightness.endPoint   = CGPoint(x: 0.50, y: 0.52)
        brightness.compositingFilter = "softLightBlendMode"
        brightness.masksToBounds = true
        layer.addSublayer(brightness)

        // Center shade (multiply) to keep core from blowing out
        centerShade.type = .radial
        centerShade.colors = [UIColor.black.withAlphaComponent(0.16).cgColor, UIColor.clear.cgColor]
        centerShade.locations = [0, 1]
        centerShade.frame = bounds
        centerShade.cornerRadius = radius
        centerShade.compositingFilter = "multiplyBlendMode"
        centerShade.masksToBounds = true
        layer.addSublayer(centerShade)

        // Rotating tint (fake "color swirl" without rings)
        tintSpin.type = .radial
        tintSpin.colors = [outer.withAlphaComponent(0.10).cgColor, UIColor.clear.cgColor]
        tintSpin.locations = [0, 1]
        tintSpin.frame = bounds
        tintSpin.cornerRadius = radius
        tintSpin.compositingFilter = "overlayBlendMode"
        tintSpin.masksToBounds = true
        layer.addSublayer(tintSpin)
        spinTint()

        // Rim
        rim.frame = bounds
        rim.path = UIBezierPath(ovalIn: bounds).cgPath
        rim.strokeColor = haloC.withAlphaComponent(0.30).cgColor
        rim.fillColor = UIColor.clear.cgColor
        rim.lineWidth = 0.8
        layer.addSublayer(rim)

        // Default swirl + organic drift
        spin(container: liquidContainer, secondsPerRotation: baseRotation)
    }

    // MARK: Modes
    func apply(mode: LiquidSwirlOrbView.Mode, animated: Bool) {
        guard mode != current else { return }
        current = mode
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.32 : 0.0)
        CATransaction.setAnimationTimingFunction(.init(name: .easeInEaseOut))

        switch mode {
        case .listening:
            baseRotation = 5.8
            spin(container: liquidContainer, secondsPerRotation: baseRotation)
            tuneCloud(liquidA, density: 1.00, alpha: 0.075, speed: 10)
            tuneCloud(liquidB, density: 0.95, alpha: 0.060, speed: 8)
            pulseCore(enabled: false)
        case .responding:
            baseRotation = 3.2 // faster, same direction
            spin(container: liquidContainer, secondsPerRotation: baseRotation)
            tuneCloud(liquidA, density: 1.18, alpha: 0.085, speed: 12)
            tuneCloud(liquidB, density: 1.05, alpha: 0.070, speed: 9)
            pulseCore(enabled: true)
        }
        CATransaction.commit()
    }

    // MARK: Level hook (0..1)
    func setLevel(_ level: CGFloat) {
        let l = max(0, min(1, level))
        guard abs(l - lastLevel) > 0.01 else { return }
        lastLevel = l

        let duration = baseRotation * (1.0 - 0.23 * Double(l))
        spin(container: liquidContainer, secondsPerRotation: duration)

        // Slightly richer cloud + velocity with level
        tuneCloud(liquidA, density: 1.00 + 0.28 * l, alpha: 0.075 + 0.02 * l, speed: 10 + 6 * l)
        tuneCloud(liquidB, density: 0.95 + 0.20 * l, alpha: 0.060 + 0.015 * l, speed: 8 + 4 * l)
    }

    // MARK: Cloud config & tuning
    private func configureCloud(_ cloud: CAEmitterLayer,
                                emitterSize: CGFloat,
                                alpha: CGFloat,
                                vel: CGFloat,
                                birth: Float,
                                blobSize: CGFloat,
                                blur: CGFloat,
                                centerAlpha: CGFloat) {
        cloud.emitterShape = .circle
        cloud.emitterMode  = .volume
        cloud.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        cloud.emitterSize   = CGSize(width: bounds.width * emitterSize, height: bounds.height * emitterSize)
        cloud.renderMode    = .additive
        cloud.emitterCells  = [makeLiquidCell(alpha: alpha, diameter: blobSize, blur: blur, centerAlpha: centerAlpha, birth: birth, vel: vel)]
    }

    private func tuneCloud(_ cloud: CAEmitterLayer, density: CGFloat, alpha: CGFloat, speed: CGFloat) {
        guard let proto = cloud.emitterCells?.first?.copy() as? CAEmitterCell else { return }
        proto.birthRate = (cloud == liquidA ? 20 : 12) * Float(density)
        proto.color = UIColor(white: 1.0, alpha: alpha).cgColor
        proto.velocity = speed
        cloud.emitterCells = [proto]
    }

    private func makeLiquidCell(alpha: CGFloat, diameter: CGFloat, blur: CGFloat, centerAlpha: CGFloat, birth: Float, vel: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = softDisc(diameter: diameter, blur: blur, centerAlpha: centerAlpha)?.cgImage
        cell.birthRate = birth
        cell.lifetime = 8
        cell.lifetimeRange = 3
        cell.velocity = vel
        cell.velocityRange = 8
        cell.scale = 0.30
        cell.scaleRange = 0.12
        cell.alphaSpeed = -0.015
        cell.color = UIColor(white: 1.0, alpha: alpha).cgColor
        cell.emissionRange = .pi * 2
        cell.spin = 0.45
        cell.spinRange = 0.35
        return cell
    }

    // MARK: Motion / effects
    private func spin(container: CALayer, secondsPerRotation: Double) {
        // Rotation (the swirl)
        container.removeAnimation(forKey: "spin")
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2 * Double(swirlDirection)
        spin.duration = max(0.3, secondsPerRotation)
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        container.add(spin, forKey: "spin")

        // Organic drift (no rings): emitter center wanders slightly
        container.removeAnimation(forKey: "drift")
        let drift = CAKeyframeAnimation(keyPath: "position")
        let a: CGFloat = bounds.width * 0.018
        let path = UIBezierPath()
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let steps = 72
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = c.x + a * sin(2 * .pi * t)
            let y = c.y + a * sin(2 * .pi * t * 1.35 + .pi/3)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        drift.path = path.cgPath
        drift.duration = secondsPerRotation * 2.0
        drift.repeatCount = .infinity
        drift.calculationMode = .linear
        drift.isAdditive = true
        container.add(drift, forKey: "drift")
    }

    private func breathHalo() {
        halo.removeAnimation(forKey: "breath")
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 0.07; a.toValue = 0.11
        a.duration = 3.2; a.autoreverses = true; a.repeatCount = .infinity
        a.timingFunction = .init(name: .easeInEaseOut)
        halo.add(a, forKey: "breath")
    }

    private func spinTint() {
        tintSpin.removeAnimation(forKey: "tintspin")
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2
        spin.duration = 18.0
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        tintSpin.add(spin, forKey: "tintspin")
    }

    private func pulseCore(enabled: Bool) {
        brightness.removeAnimation(forKey: "corepulse")
        centerShade.removeAnimation(forKey: "shadepulse")
        guard enabled else { return }

        let group = CAAnimationGroup()
        group.duration = 0.9
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.97; scale.toValue = 1.07

        let bFade = CABasicAnimation(keyPath: "opacity")
        bFade.fromValue = 0.65; bFade.toValue = 0.85

        let sFade = CABasicAnimation(keyPath: "opacity")
        sFade.fromValue = 0.20; sFade.toValue = 0.10

        group.animations = [scale, bFade]
        brightness.add(group, forKey: "corepulse")
        centerShade.add(sFade, forKey: "shadepulse")
    }

    // MARK: Util
    private func softDisc(diameter: CGFloat, blur: CGFloat, centerAlpha: CGFloat) -> UIImage? {
        let scale = UIScreen.main.scale
        let size = CGSize(width: diameter, height: diameter)
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        let colors = [UIColor(white: 1, alpha: centerAlpha).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,1])!
        let r = diameter / 2
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: r, y: r), startRadius: 0, endCenter: CGPoint(x: r, y: r), endRadius: r, options: .drawsAfterEndLocation)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Preview (Xcode Canvas)
#if DEBUG
@available(iOS 15.0, *)
private struct OrbPreviewHarness: View {
    @State private var mode: LiquidSwirlOrbView.Mode = .listening
    @State private var size: CGFloat = 200
    @State private var level: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            LiquidSwirlOrbView(mode: mode, size: size, level: level)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(radius: 8)

            Picker("Mode", selection: $mode) {
                Text("Listening").tag(LiquidSwirlOrbView.Mode.listening)
                Text("Responding").tag(LiquidSwirlOrbView.Mode.responding)
            }
            .pickerStyle(.segmented)

            HStack { Text("Size \(Int(size))"); Slider(value: $size, in: 120...280) }
            HStack { Text("Level \(String(format: "%.2f", level))"); Slider(value: $level, in: 0...1) }
        }
        .padding(24)
        .background(Color(white: 0.06))
        .preferredColorScheme(.dark)
    }
}

@available(iOS 15.0, *)
struct LiquidSwirlOrbView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OrbPreviewHarness().previewDisplayName("Controls")
            LiquidSwirlOrbView(mode: .listening, size: 176)
                .preferredColorScheme(.dark)
                .previewDisplayName("Listening")
            LiquidSwirlOrbView(mode: .responding, size: 176)
                .preferredColorScheme(.dark)
                .previewDisplayName("Responding")
        }
        .padding()
        .background(Color.black)
    }
}
#endif
