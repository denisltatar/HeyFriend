//
//  SessionSummary.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/20/25.
//

import Foundation

struct SessionSummary: Codable, Identifiable, Equatable {
    var id: String              // usually your sessionId
    var summary: [String]       // 2–3 bullets
    var tone: String            // one short sentence
    var createdAt: Date
}
