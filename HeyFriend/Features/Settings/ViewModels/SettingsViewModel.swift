//
//  SettingsModels.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/5/25.
//

import Foundation
import SwiftUI

enum SettingsKeys {
    static let requireBiometricsForInsights = "requireBiometricsForInsights"
    static let appAppearance = "appAppearance"
}

// MARK: - Appearance
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System Default"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
