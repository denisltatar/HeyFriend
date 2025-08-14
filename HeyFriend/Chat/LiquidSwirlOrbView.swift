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
    enum Mode: Equatable { case listening, responding }
    var mode: Mode = .listening
    var size: CGFloat = 176      // ~20% smaller than 220

    var body: some View {
        LiquidSwirlRepresentable(mode: mode, size: size)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - UIViewRepresentable

private struct LiquidSwirlRepresentable: UIViewRepresentable {
    let mode: LiquidSwirlOrbView.Mode
    let size: CGFloat

    func makeUIView(context: Context) -> LiquidSwirlView {
        let v = LiquidSwirlView(frame: .init(origin: .zero, size: .init(width: size, height: size)))
        v.configure(size: size)
        v.apply(mode: mode, animated: false)
        return v
    }

    func updateUIView(_ uiView: LiquidSwirlView, context: Context) {
        uiView.apply(mode: mode, animated: true)
    }
}

// MARK: - CALayer-backed view

final class LiquidSwirlView: UIView {

    // Layers
    private let halo = CAGradientLayer()
    private let orbFill = CAGradientLayer()
    private let rim = CAShapeLayer()
    private let brightnessOverlay = CAGradientLayer()

    // Cloud
    private let emitterContainer = CALayer()     // we rotate this to swirl
    private let cloudEmitter = CAEmitterLayer()

    // State
    private var currentMode: LiquidSwirlOrbView.Mode = .listening
    private var orbRadius: CGFloat = 88

    override class var layerClass: AnyClass { CALayer.self }

    // MARK: Configure

    func configure(size: CGFloat) {
        isUserInteractionEnabled = false
        backgroundColor = .clear
        orbRadius = size * 0.5

        // -------- Ambient halo (very subtle, breathing) --------
        halo.type = .radial
        halo.colors = [
            UIColor(red: 0.60, green: 0.70, blue: 1.00, alpha: 0.28).cgColor,
            UIColor.clear.cgColor
        ]
        halo.locations = [0, 1]
        halo.frame = bounds.insetBy(dx: -size*0.35, dy: -size*0.35)
        layer.addSublayer(halo)
        startHaloBreathing()

        // -------- Orb body (lavender → pale blue) --------
        orbFill.type = .radial
        orbFill.colors = [
            UIColor(red: 0.78, green: 0.52, blue: 1.00, alpha: 1.0).cgColor, // inner lavender
            UIColor(red: 0.35, green: 0.60, blue: 1.00, alpha: 0.95).cgColor // outer blue
        ]
        orbFill.locations = [0, 1]
        orbFill.frame = bounds
        orbFill.cornerRadius = orbRadius
        orbFill.masksToBounds = true
        layer.addSublayer(orbFill)

        // -------- Cloud emitter (masked by orbFill) --------
        emitterContainer.frame = bounds
        orbFill.addSublayer(emitterContainer)

        setupCloudEmitter(in: emitterContainer.bounds)
        emitterContainer.addSublayer(cloudEmitter)

        // -------- Subtle “wet” brightness overlay --------
        brightnessOverlay.type = .radial
        brightnessOverlay.colors = [UIColor.white.withAlphaComponent(0.20).cgColor,
                                    UIColor.clear.cgColor]
        brightnessOverlay.locations = [0, 1]
        brightnessOverlay.frame = bounds
        brightnessOverlay.cornerRadius = orbRadius
        brightnessOverlay.masksToBounds = true
        brightnessOverlay.compositingFilter = "screenBlendMode"
        layer.addSublayer(brightnessOverlay)

        // -------- Rim --------
        rim.frame = bounds
        rim.path = UIBezierPath(ovalIn: bounds).cgPath
        rim.strokeColor = UIColor(red: 0.60, green: 0.70, blue: 1.00, alpha: 0.45).cgColor
        rim.fillColor = UIColor.clear.cgColor
        rim.lineWidth = 0.8
        layer.addSublayer(rim)

        // default animation
        startSwirl(secondsPerRotation: 4.0) // calm listening loop
    }

    // MARK: - Public apply

    func apply(mode: LiquidSwirlOrbView.Mode, animated: Bool) {
        guard mode != currentMode else { return }
        currentMode = mode

        let duration: CFTimeInterval = animated ? 0.32 : 0.0
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(.easeInOut)

        switch mode {
        case .listening:
            startSwirl(secondsPerRotation: 4.0)   // 3–5s loop
            adjustCloud(density: 1.0, alpha: 0.12) // calmer
            brightness(to: 1.0)
        case .responding:
            startSwirl(secondsPerRotation: 1.6)   // ~1.5–2s loop
            adjustCloud(density: 1.25, alpha: 0.16) // slightly richer / brighter
            brightness(to: 1.06)
        }
        CATransaction.commit()
    }

    // MARK: - Cloud emitter

    private func setupCloudEmitter(in rect: CGRect) {
        cloudEmitter.emitterShape = .circle
        cloudEmitter.emitterMode = .surface
        cloudEmitter.emitterPosition = CGPoint(x: rect.midX, y: rect.midY)
        cloudEmitter.emitterSize = CGSize(width: rect.width * 0.65, height: rect.height * 0.65)
        cloudEmitter.renderMode = .additive

        // A large, blurred “cloudlet” image
        cloudEmitter.emitterCells = [makeCloudCell(alpha: 0.12)]
    }

    private func makeCloudCell(alpha: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = makeSoftCircleImage(diameter: 140, blur: 28, alpha: 1.0)?.cgImage
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

    private func adjustCloud(density: CGFloat, alpha: CGFloat) {
        guard let cell = cloudEmitter.emitterCells?.first?.copy() as? CAEmitterCell else { return }
        cell.birthRate = Float(8 * density)
        cell.color = UIColor(white: 1.0, alpha: alpha).cgColor
        cloudEmitter.emitterCells = [cell]
    }

    // MARK: - Swirl & Halo

    private func startSwirl(secondsPerRotation: Double) {
        emitterContainer.removeAnimation(forKey: "rotateCloud")
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2
        spin.duration = max(0.3, secondsPerRotation)
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        emitterContainer.add(spin, forKey: "rotateCloud")
    }

    private func startHaloBreathing() {
        halo.removeAnimation(forKey: "breath")
        let breath = CABasicAnimation(keyPath: "opacity")
        breath.fromValue = 0.10
        breath.toValue = 0.13      // <3% shift
        breath.duration = 3.0
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = .easeInOut
        halo.add(breath, forKey: "breath")
    }

    private func brightness(to factor: CGFloat) {
        brightnessOverlay.removeAnimation(forKey: "brightness")
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = (brightnessOverlay.presentation() ?? brightnessOverlay).value(forKeyPath: "transform.scale") ?? 1.0
        anim.toValue = factor
        anim.duration = 0.30
        anim.timingFunction = .easeInOut
        brightnessOverlay.setValue(factor, forKeyPath: "transform.scale")
        brightnessOverlay.add(anim, forKey: "brightness")
    }

    // MARK: - Utilities

    private func makeSoftCircleImage(diameter: CGFloat, blur: CGFloat, alpha: CGFloat) -> UIImage? {
        let scale = UIScreen.main.scale
        let size = CGSize(width: diameter, height: diameter)
        let rect = CGRect(origin: .zero, size: size)

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        // Draw a soft, radial alpha disc
        let colors = [UIColor(white: 1, alpha: alpha).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0,1])!
        ctx.drawRadialGradient(gradient,
                               startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0,
                               endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: diameter/2,
                               options: .drawsAfterEndLocation)

        // Light blur via shadow trick around alpha (keeps it fast)
        ctx.setShadow(offset: .zero, blur: blur, color: UIColor(white: 1, alpha: alpha).cgColor)
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.001).cgColor)
        ctx.fillEllipse(in: rect)

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}

// MARK: - Timing helpers
private extension CAMediaTimingFunction {
    static var easeInOut: CAMediaTimingFunction { .init(name: .easeInEaseOut) }
}
