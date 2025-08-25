//
//  SessionSummary.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/20/25.
//

import Foundation

struct SessionSummary: Codable, Identifiable, Equatable {
    var id: String              // usually your sessionId
    var summary: [String]       // bullet point format
    var tone: String            // one short sentence
    var createdAt: Date
    
    var supportingTones: [String]?     // e.g., ["Gratitude", "Contentment"]
    var toneNote: String?              // 1–2 lines explaining the tone

    struct LanguagePatterns: Codable, Equatable {
        var repeatedWords: [String]        // e.g., ["maybe","probably","should"]
        var thinkingStyle: String          // e.g., "Future‑focused, analytical"
        var emotionalIndicators: String    // e.g., "Cautious optimism"
    }
    var language: LanguagePatterns?     // "could", "should", "have to"

    var recommendation: String?         // ≤ ~300 tokens, friendly and actionable
}
