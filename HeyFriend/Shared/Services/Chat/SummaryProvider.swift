//
//  SummaryProvider.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/20/25.
//

import Foundation

protocol SummaryProvider {
    func generateSummary(for transcript: String, sessionId: String) async throws -> SessionSummary
}

// Works instantly without any API
struct MockSummaryProvider: SummaryProvider {
    func generateSummary(for transcript: String, sessionId: String) async throws -> SessionSummary {
        let bullets = [
            "Talked about balancing work and rest",
            "Noted gratitude for support from a friend",
            "Chose one small step for tonight"
        ]
        return SessionSummary(
            id: sessionId,
            summary: Array(bullets.prefix(2 + Int.random(in: 0...1))), // 2–3 bullets
            tone: "Calm and thoughtful overall.",
            createdAt: Date()
        )
    }
}

// Swap this to your real LLM call later
struct LLMSummaryProvider: SummaryProvider {
    let modelName: String

    func generateSummary(for transcript: String, sessionId: String) async throws -> SessionSummary {
        // TODO: Replace with your real API call.
        // Keep the contract: return 2–3 bullets + one-sentence tone.
        // Tip: Truncate transcript to last 4,000 chars of USER messages before calling.
        throw NSError(domain: "LLMSummaryProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented yet"])
    }
}
