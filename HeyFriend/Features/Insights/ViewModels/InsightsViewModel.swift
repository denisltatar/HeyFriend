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
    // ✅ Radar state (must be in the main type, not an extension)
    @Published var radarPoints: [TonePoint] = []
    @Published var isLoadingRadar: Bool = false
    @Published var radarError: String?
    
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

// MARK: - Tone taxonomy (6 buckets)
enum ToneBucket: String, CaseIterable {
    case calm = "Calm"
    case hopeful = "Hopeful"
    case reflective = "Reflective"
    case anxious = "Anxious"
    case stressed = "Stressed"
    case sad = "Sad"

    static func map(raw: String) -> ToneBucket? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["calm","peaceful","grounded","steady"].contains(s) { return .calm }
        if ["hopeful","supportive","encouraging","optimistic","uplifting","motivating"].contains(s) { return .hopeful }
        if ["reflective","thoughtful","analytical","practical"].contains(s) { return .reflective }
        if ["anxious","worried","uneasy","nervous"].contains(s) { return .anxious }
        if ["stressed","overwhelmed","pressured","tense"].contains(s) { return .stressed }
        if ["sad","down","low","disappointed"].contains(s) { return .sad }
        return nil
    }
}

// MARK: - DTOs (decode from snapshots when loading radar)
struct SessionDocDTO {
    var createdAt: Date?
    var tone: String?
    var supportingTones: [String]?
    init(_ data: [String: Any]) {
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        self.tone = data["tone"] as? String
        self.supportingTones = data["supportingTones"] as? [String]
    }
}
struct InsightSummaryDTO {
    var createdAt: Date?
    var topTones: [String]?
    init(_ data: [String: Any]) {
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        self.topTones = data["topTones"] as? [String]
    }
}

// MARK: - Aggregation logic
private enum RadarWeight {
    static let primaryTone: Double = 1.0
    static let supportingTone: Double = 0.5
    static let summaryTopTone: Double = 0.5
}

enum RadarScaleMode {
    case rawMax
    case temperedProportion(gamma: Double = 1.0, floor: Double = 0.08, contrast: Double = 1.0)
}

private func normalizeScores(_ scores: [ToneBucket: Double], mode: RadarScaleMode) -> [TonePoint] {
    let buckets = ToneBucket.allCases

    switch mode {
    case .rawMax:
        let maxVal = max(scores.values.max() ?? 0, 1)
        return buckets.map { b in
            TonePoint(label: b.rawValue, value: scores[b, default: 0] / maxVal)
        }

    case .temperedProportion(let gamma, let floor, let contrast):
        let total = scores.values.reduce(0,+)
        guard total > 0 else { return buckets.map { TonePoint(label: $0.rawValue, value: 0) } }

        // proportions -> temper (p^γ) -> renormalize
        let tempered = buckets.map { pow(scores[$0, default: 0] / total, gamma) }
        let sumT = max(tempered.reduce(0,+), .leastNonzeroMagnitude)
        let norm = tempered.map { $0 / sumT }

        // rescale to [floor, 1] then apply optional contrast around 0.5
        let maxNorm = max(norm.max() ?? 0, 1)
        let withFloor = norm.map { floor + (1 - floor) * ($0 / maxNorm) }

        // contrast: >1 stretches from 0.5, <1 compresses toward 0.5
        let contrasted = withFloor.map { v in
            let c = max(contrast, 0)
            let out = 0.5 + (v - 0.5) * c
            return min(max(out, 0), 1)
        }

        return zip(buckets, contrasted).map { TonePoint(label: $0.rawValue, value: $1) }
    }
}


private func aggregateRadar(sessions: [SessionDocDTO], summaries: [InsightSummaryDTO]) -> [TonePoint] {
    var scores: [ToneBucket: Double] = [:]
    ToneBucket.allCases.forEach { scores[$0] = 0 }

    for s in sessions {
        if let t = s.tone, let b = ToneBucket.map(raw: t) {
            scores[b, default: 0] += RadarWeight.primaryTone
        }
        for t in s.supportingTones ?? [] {
            if let b = ToneBucket.map(raw: t) {
                scores[b, default: 0] += RadarWeight.supportingTone
            }
        }
    }
    for sum in summaries {
        for t in sum.topTones ?? [] {
            if let b = ToneBucket.map(raw: t) {
                scores[b, default: 0] += RadarWeight.summaryTopTone
            }
        }
    }

//    let maxScore = max(scores.values.max() ?? 0, 1) // avoid /0
//    return ToneBucket.allCases.map { b in
//        TonePoint(label: b.rawValue, value: (scores[b]! / maxScore))
//    }
    
    // (balanced scaling)
//    return normalizeScores(scores, mode: .temperedProportion(gamma: 0.6, floor: 0.12))
    
    // NEW: tempered scaling with extra spread
    return normalizeScores(
        scores,
        mode: .temperedProportion(
            // gamma: Controls flattening vs peaking of tone shares.
            //        <1 (e.g. 0.6–0.8) lifts smaller tones and reduces dominant ones,
            //        =1 keeps proportions unchanged, >1 exaggerates dominance.
            gamma: 0.9,    // closer to 1.0 = more contrast
            
            // floor: Sets the minimum visible radius for any tone.
            //        Ensures no axis disappears entirely (e.g. 0.10 = 10% minimum).
            floor: 0.40,   // THE HIGHER THE MORE SPREAD (with current setup)
            
            // contrast: Adjusts overall spread around the midpoint.
            //        >1 stretches values apart for more visible differences,
            //        <1 compresses them closer together, =1 leaves as-is.
            contrast: 1.25 // gentle extra stretch away from 0.5
        )
    )
}

// MARK: - Loader
extension InsightsViewModel {
    // Helping with refreshing all data when pulling down on insights page
    func refreshAll(rangeDays: Int) async {
        async let a: Void = loadHistory()
        async let b: Void = loadRadar(rangeDays: rangeDays)
        _ = await (a, b)
    }
    
    // Loading our tone radar
    func loadRadar(rangeDays: Int) async {
        guard let uid = AuthService.shared.userId else {
            self.radarError = "Not signed in."
            self.radarPoints = []
            return
        }

        isLoadingRadar = true
        radarError = nil
        defer { isLoadingRadar = false }

        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -rangeDays, to: end) else { return }

        do {
            async let sDocs = FirestoreService.shared.listSessionsInRange(uid: uid, start: start, end: end)
            async let iDocs = FirestoreService.shared.listInsightSummariesInRange(uid: uid, start: start, end: end)

            let (sessionsRaw, summariesRaw) = try await (sDocs, iDocs)
            let sessions = sessionsRaw.map { SessionDocDTO($0.data()) }
            let summaries = summariesRaw.map { InsightSummaryDTO($0.data()) }

            self.radarPoints = aggregateRadar(sessions: sessions, summaries: summaries)
        } catch {
            self.radarError = error.localizedDescription
            self.radarPoints = []
        }
    }
}

