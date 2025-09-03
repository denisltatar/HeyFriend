//
//  InsightsViewModel.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/3/25.
//

import Foundation

import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
final class InsightsViewModel: ObservableObject {
    struct HistoryRow: Identifiable, Equatable {
        let id: String          // sessionId
        let title: String       // short summary snippet
        let subtitle: String    // e.g., tones or duration
        let createdAt: Date
    }

    @Published var rows: [HistoryRow] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedSummary: SessionSummary?   // for navigation/sheet

    // Load recent insight_summaries (already created in writeSummaryBundle)
    func loadHistory(limit: Int = 50) async {
        guard let uid = AuthService.shared.userId else {
            error = "Not signed in."; return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let docs = try await FirestoreService.shared.listInsightSummaries(uid: uid, limit: limit)
            self.rows = docs.compactMap { snap in
                let sid = snap.documentID
                let data = snap.data()
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let summaryLine = (data["summary"] as? String) ?? "Session summary"
                let tones = (data["topTones"] as? [String]) ?? []
                let duration = data["durationSec"] as? Int
                let subtitle: String = {
                    let toneStr = tones.isEmpty ? "" : tones.prefix(2).joined(separator: ", ")
                    if let d = duration, d > 0 {
                        let mins = Int((Double(d) / 60.0).rounded())
                        return toneStr.isEmpty ? "\(mins)m" : "\(toneStr) • \(mins)m"
                    }
                    return toneStr
                }()
                return HistoryRow(id: sid, title: summaryLine, subtitle: subtitle, createdAt: createdAt)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // On tap, fetch the full session doc and map it into SessionSummary for the detail screen
    func openSessionDetail(for sessionId: String) async {
        guard let uid = AuthService.shared.userId else { return }
        do {
            let snap = try await FirestoreService.shared.getSession(uid: uid, sid: sessionId)
            guard let data = snap.data() else { return }

            // Map Firestore -> SessionSummary (matches what writeSummaryBundle stores)
            let summary = (data["summary"] as? [String]) ?? []
            let tone = (data["tone"] as? String) ?? "—"
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

            var supportingTones: [String]? = data["supportingTones"] as? [String]
            var toneNote: String? = data["toneNote"] as? String

            var language: SessionSummary.LanguagePatterns?
            if let lang = data["language"] as? [String: Any] {
                let repeated = (lang["repeatedWords"] as? [String]) ?? []
                let thinking = (lang["thinkingStyle"] as? String) ?? ""
                let emotional = (lang["emotionalIndicators"] as? String) ?? ""
                language = .init(repeatedWords: repeated, thinkingStyle: thinking, emotionalIndicators: emotional)
            }

            let recommendation = data["recommendation"] as? String

            self.selectedSummary = SessionSummary(
                id: sessionId,
                summary: summary,
                tone: tone,
                createdAt: createdAt,
                supportingTones: supportingTones,
                toneNote: toneNote,
                language: language,
                recommendation: recommendation
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}
