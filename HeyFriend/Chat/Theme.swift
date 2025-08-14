//
//  Theme.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/13/25.
//

import Foundation
import SwiftUI

enum HF {
    // Brand palette (from your swatch)
    static let canvas    = Color(hex: "#FBFBF5")
    static let amber     = Color(hex: "#F3AE3D")
    static let amberMid  = Color(hex: "#F2CA8D")
    static let amberSoft = Color(hex: "#F7E3C5")

    // Handy hex init
    static func color(_ hex: String) -> Color { Color(hex: hex) }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
