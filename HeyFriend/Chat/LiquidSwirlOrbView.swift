//
//  LiquidSwirlOrbView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/13/25.
//

import Foundation
import SwiftUI
import QuartzCore
import UIKit

struct LiquidSwirlOrbView: View {
    enum Mode { case listening, responding }
    var mode: Mode = .listening
    var size: CGFloat = 176 // ~20% smaller than 220

    var body: some View {
        LiquidSwirlRepresentable(mode: mode, size: size)
            .frame(width: size, height: size)
    }
}

private struct LiquidSwirlRepresentable: UIViewRepresentable {
    let mode: LiquidSwirlOrbView.Mode
    let size: CGFloat
    func makeUIView(context: Context) -> LiquidSwirlView {
        let v = LiquidSwirlView(frame: .init(x: 0, y: 0, width: size, height: size))
        v.configure(size: size)
        v.apply(mode: mode, animated: false)
        return v
    }
    func updateUIView(_ uiView: LiquidSwirlView, context: Context) {
        uiView.apply(mode: mode, animated: true)
    }
}

final class LiquidSwirlView: UIView {
    // 🎛️ KNOBS
    private let inner = UIColor(red: 1.00, green: 0.72, blue: 0.34, alpha: 1.0) // amber
    private let outer = UIColor(red: 1.00, green: 0.45, blue: 0.00, alpha: 0.95) // orange
    private let haloC = UIColor(red: 1.00, green: 0.65, blue: 0.20, alpha: 1.0)

    private let halo = CAGradientLayer()
    private let orbFill = CAGradientLayer()
    private let brightness = CAGradientLayer()
    private let rim = CAShapeLayer()

    private let emitterContainer = CALayer() // rotates (swirl)
    private let cloud = CAEmitterLayer()

    private var current: LiquidSwirlOrbView.Mode = .listening
    private var radius: CGFloat = 88

    override class var layerClass: AnyClass { CALayer.self }

    func configure(size: CGFloat) {
        backgroundColor = .clear
        radius = size * 0.5

        // Halo
        halo.type = .radial
        halo.colors = [haloC.withAlphaComponent(0.28).cgColor, UIColor.clear.cgColor]
        halo.locations = [0, 1]
        halo.frame = bounds.insetBy(dx: -size*0.35, dy: -size*0.35)
        layer.addSublayer(halo)
        breathHalo()

        // Orb fill (amber → orange)
        orbFill.type = .radial
        orbFill.colors = [inner.cgColor, outer.cgColor]
        orbFill.locations = [0, 1]
        orbFill.frame = bounds
        orbFill.cornerRadius = radius
        orbFill.masksToBounds = true
        layer.addSublayer(orbFill)

        // Cloud (big blurred “cloudlets” that overlap → one mist)
        emitterContainer.frame = bounds
        orbFill.addSublayer(emitterContainer)
        setupCloud(in: emitterContainer.bounds)
        emitterContainer.addSublayer(cloud)

        // Subtle wet highlight
        brightness.type = .radial
        brightness.colors = [UIColor.white.withAlphaComponent(0.20).cgColor, UIColor.clear.cgColor]
        brightness.locations = [0, 1]
        brightness.frame = bounds
        brightness.cornerRadius = radius
        brightness.masksToBounds = true
        brightness.compositingFilter = "screenBlendMode"
        layer.addSublayer(brightness)

        // Rim
        rim.frame = bounds
        rim.path = UIBezierPath(ovalIn: bounds).cgPath
        rim.strokeColor = haloC.withAlphaComponent(0.45).cgColor
        rim.fillColor = UIColor.clear.cgColor
        rim.lineWidth = 0.8
        layer.addSublayer(rim)

        // Default motion
        spinCloud(secondsPerRotation: 4.0) // calm
    }

    func apply(mode: LiquidSwirlOrbView.Mode, animated: Bool) {
        guard mode != current else { return }
        current = mode
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.32 : 0.0)
        CATransaction.setAnimationTimingFunction(.init(name: .easeInEaseOut))

        switch mode {
        case .listening:
            spinCloud(secondsPerRotation: 4.0)     // ~4s loop
            tuneCloud(density: 1.0, alpha: 0.12)   // calmer
            setBrightness(scale: 1.0)
        case .responding:
            spinCloud(secondsPerRotation: 1.6)     // ~1.6s loop
            tuneCloud(density: 1.25, alpha: 0.16)  // a bit richer
            setBrightness(scale: 1.06)
        }
        CATransaction.commit()
    }

    // MARK: Cloud setup/tuning
    private func setupCloud(in rect: CGRect) {
        cloud.emitterShape = .circle
        cloud.emitterMode = .surface
        cloud.emitterPosition = CGPoint(x: rect.midX, y: rect.midY)
        cloud.emitterSize = CGSize(width: rect.width * 0.65, height: rect.height * 0.65)
        cloud.renderMode = .additive
        cloud.emitterCells = [makeCloudCell(alpha: 0.12)]
    }
    private func tuneCloud(density: CGFloat, alpha: CGFloat) {
        guard let cell = cloud.emitterCells?.first?.copy() as? CAEmitterCell else { return }
        cell.birthRate = Float(8 * density)
        cell.color = UIColor(white: 1.0, alpha: alpha).cgColor
        cloud.emitterCells = [cell]
    }
    private func makeCloudCell(alpha: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = softDisc(diameter: 160, blur: 32)?.cgImage
        cell.birthRate = 8
        cell.lifetime = 8
        cell.lifetimeRange = 2
        cell.velocity = 8
        cell.velocityRange = 6
        cell.scale = 0.35
        cell.scaleRange = 0.10
        cell.alphaSpeed = -0.02
        cell.color = UIColor(white: 1.0, alpha: alpha).cgColor
        cell.emissionRange = .pi * 2
        cell.spin = 0.5
        cell.spinRange = 0.3
        return cell
    }

    // MARK: Motion / effects
    private func spinCloud(secondsPerRotation: Double) {
        emitterContainer.removeAnimation(forKey: "spin")
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2
        spin.duration = max(0.3, secondsPerRotation)
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        emitterContainer.add(spin, forKey: "spin")
    }
    private func breathHalo() {
        halo.removeAnimation(forKey: "breath")
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 0.10; a.toValue = 0.13
        a.duration = 3.0; a.autoreverses = true; a.repeatCount = .infinity
        a.timingFunction = .init(name: .easeInEaseOut)
        halo.add(a, forKey: "breath")
    }
    private func setBrightness(scale: CGFloat) {
        brightness.removeAnimation(forKey: "bright")
        let a = CABasicAnimation(keyPath: "transform.scale")
        a.fromValue = (brightness.presentation() ?? brightness).value(forKeyPath: "transform.scale") ?? 1.0
        a.toValue = scale
        a.duration = 0.30
        a.timingFunction = .init(name: .easeInEaseOut)
        brightness.setValue(scale, forKeyPath: "transform.scale")
        brightness.add(a, forKey: "bright")
    }

    // MARK: Util
    private func softDisc(diameter: CGFloat, blur: CGFloat) -> UIImage? {
        let scale = UIScreen.main.scale
        let size = CGSize(width: diameter, height: diameter)
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        let colors = [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,1])!
        let r = diameter / 2
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: r, y: r), startRadius: 0, endCenter: CGPoint(x: r, y: r), endRadius: r, options: .drawsAfterEndLocation)
        ctx.setShadow(offset: .zero, blur: blur, color: UIColor(white: 1, alpha: 1).cgColor)
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.001).cgColor)
        ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}
