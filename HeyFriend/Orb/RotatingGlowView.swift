//
//  RotatingGlowView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/14/25.
//

import Foundation
import SwiftUI

enum RotationDirection {
    case clockwise
    case counterClockwise

    var multiplier: Double {
        switch self {
        case .clockwise: return 1
        case .counterClockwise: return -1
        }
    }
}

struct RotatingGlowView: View {
    @State private var rotation: Double = 0

    private let color: Color
    private let rotationSpeed: Double
    private let direction: RotationDirection

    init(color: Color,
         rotationSpeed: Double = 30,
         direction: RotationDirection)
    {
        self.color = color
        self.rotationSpeed = rotationSpeed
        self.direction = direction
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            Circle()
                .fill(color)
                .mask {
                    ZStack {
                        Circle()
                            .frame(width: size, height: size)
                            .blur(radius: size * 0.16)
                        Circle()
                            .frame(width: size * 1.31, height: size * 1.31)
                            .offset(y: size * 0.31)
                            .blur(radius: size * 0.16)
                            .blendMode(.destinationOut)
                    }
                }
                .rotationEffect(.degrees(rotation))
                .onAppear { startSpin() }
                .onChange(of: rotationSpeed) { _, _ in restartSpin() }
                .onChange(of: direction.multiplier) { _, _ in restartSpin() } // reacts if you flip direction
        }
    }
    
    
    private var duration: Double { max(0.1, 360 / max(1, rotationSpeed)) }

    private func startSpin() {
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            rotation = 360 * direction.multiplier
        }
    }

    private func restartSpin() {
        rotation = 0
        startSpin()
    }

}

#Preview {
    RotatingGlowView(color: .purple,
                   rotationSpeed: 30,
                   direction: .counterClockwise)
        .frame(width: 128, height: 128)
}
