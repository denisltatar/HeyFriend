//
//  InsightsViewModel.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/3/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI
import CryptoKit

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
    
    // Gratitude mentions
    @Published var gratitudeTotal: Int = 0
    @Published var gratitudeSeries: [Int] = []
    @Published var isLoadingGratitude: Bool = false
    @Published var gratitudeError: String?
    
    // Language Patterns / Focus Snippet
    @Published var commonThemes: [String] = []      // 2–4 short tags like "Growth mindset"
    @Published var focusTitle: String? = nil        // e.g., "Distortion Awareness"
    @Published var focusDescription: String? = nil  // 1–2 sentences, NOT the long 'recommendation'
    @Published var isLoadingLanguage: Bool = true
    @Published var languageError: String? = nil
    private var lastLangFetch: Date?

    // Personal Recommendations
    @Published var recTitle: String? = nil
    @Published var recBody: String? = nil
    @Published var isLoadingRecommendation = true
    

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
            let gratitude = (data["gratitudeMentions"] as? Int) ?? 0

            self.selectedSummary = SessionSummary(
                id: sessionId,
                summary: summary,
                tone: tone,
                createdAt: createdAt,
                supportingTones: supportingTones,
                toneNote: toneNote,
                language: language,
                recommendation: recommendation,
                gratitudeMentions:gratitude
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
        async let c: Void = loadGratitude(rangeDays: rangeDays)
        async let d: Void = loadLanguagePatterns(rangeDays: rangeDays)
        async let rec: Void = loadPersonalRecommendation(rangeDays: rangeDays)
        _ = await (a, b, c, d)
    }
    
    // MARK: - Loading Gratitude Mentions
    
    // Loading our gratitude mentions
    func loadGratitude(rangeDays: Int) async {
        guard let uid = AuthService.shared.userId else {
            self.gratitudeError = "Not signed in."
            self.gratitudeTotal = 0
            self.gratitudeSeries = []
            return
        }

        isLoadingGratitude = true
        gratitudeError = nil
        defer { isLoadingGratitude = false }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard
            let startDay = cal.date(byAdding: .day, value: -(rangeDays - 1), to: todayStart),
            let endExclusive = cal.date(byAdding: .day, value: 1, to: todayStart)
        else { return }

        do {
            // 👇 NOTE the label endExclusive: and the window that includes *today*
            let docs = try await FirestoreService.shared.listInsightSummariesInRange(
                uid: uid,
                start: startDay,
                endExclusive: endExclusive
            )

            var byDay: [Date: Int] = [:]
            for d in docs {
                let data = d.data()
                let created = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let day = cal.startOfDay(for: created)
                let mentions = data["gratitudeMentions"] as? Int ?? 0
                if mentions > 0 { byDay[day, default: 0] += mentions }
            }

            var series: [Int] = []
            var total = 0
            var cursor = startDay
            for _ in 0..<rangeDays {
                let v = byDay[cursor] ?? 0
                series.append(v)
                total += v
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }

            self.gratitudeSeries = series
            self.gratitudeTotal = total
            print("📊 InsightsVM: gratitudeTotal=\(total) over \(rangeDays)d (today included)")
            // TEMP DEBUG: see what we got back
            docs.forEach { d in
                let data = d.data()
                print("🔬 got summary doc",
                      "createdAt=", (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast,
                      "gratitude=", data["gratitudeMentions"] as? Int ?? -1)
            }
        } catch {
            self.gratitudeError = error.localizedDescription
            self.gratitudeSeries = []
            self.gratitudeTotal = 0
        }
    }

    // MARK: - Loading Tone Radar
    
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

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard
            let startDay = cal.date(byAdding: .day, value: -(rangeDays - 1), to: todayStart),
            let endExclusive = cal.date(byAdding: .day, value: 1, to: todayStart)
        else { return }

        do {
            async let sDocs = FirestoreService.shared.listSessionsInRange(
                uid: uid, start: startDay, end: endExclusive
            )
            async let iDocs = FirestoreService.shared.listInsightSummariesInRange(
                uid: uid, start: startDay, endExclusive: endExclusive
            )

            let (sessionsRaw, summariesRaw) = try await (sDocs, iDocs)
            let sessions = sessionsRaw.map { SessionDocDTO($0.data()) }
            let summaries = summariesRaw.map { InsightSummaryDTO($0.data()) }

            self.radarPoints = aggregateRadar(sessions: sessions, summaries: summaries)
        } catch {
            self.radarError = error.localizedDescription
            self.radarPoints = []
        }
    }
    
    // MARK: - Loading Language Patterns
    
    // Important for caching Language Patterns
    func sha256(_ s: String) -> String {
        let d = SHA256.hash(data: Data(s.utf8))
        return d.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Range finder
    private func rangeStartEnd(forDays rangeDays: Int) -> (start: Date, endExclusive: Date) {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(rangeDays - 1), to: todayStart) ?? todayStart
        let endExclusive = cal.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
        return (start, endExclusive)
    }
    
    // Short bullets from insight_summaries (kept tiny for prompt)
    private func fetchBullets(rangeDays: Int) async -> [String] {
        guard let uid = AuthService.shared.userId else { return [] }
        let (start, endEx) = rangeStartEnd(forDays: rangeDays)
        do {
            let docs = try await FirestoreService.shared
                .listInsightSummariesInRange(uid: uid, start: start, endExclusive: endEx)
            var out: [String] = []
            for d in docs {
                let data = d.data()
                if let s = data["summary"] as? String, !s.isEmpty {
                    out.append(s)
                } else if let arr = data["summary"] as? [String], !arr.isEmpty {
                    out.append(contentsOf: arr.prefix(2))
                }
            }
            return Array(out.prefix(24)) // cap for speed/cost
        } catch {
            print("fetchBullets error: \(error)")
            return []
        }
    }

    // Compact language signals from sessions/lang object
    private func fetchSignals(rangeDays: Int) async -> [[String: Any]] {
        guard let uid = AuthService.shared.userId else { return [] }
        let (start, endEx) = rangeStartEnd(forDays: rangeDays)
        do {
            let sessions = try await FirestoreService.shared
                .listSessionsInRange(uid: uid, start: start, end: endEx)

            var out: [[String: Any]] = []
            for s in sessions {
                let data = s.data()
                if let lang = data["language"] as? [String: Any] {
                    var item: [String: Any] = [:]
                    if let r = lang["repeatedWords"] as? [String], !r.isEmpty { item["repeated"] = Array(r.prefix(5)) }
                    if let t = lang["thinkingStyle"] as? String, !t.isEmpty { item["thinking"] = t }
                    if let e = lang["emotionalIndicators"] as? String, !e.isEmpty { item["emotional"] = e }
                    if !item.isEmpty { out.append(item) }
                }
            }
            return Array(out.prefix(24))
        } catch {
            print("fetchSignals error: \(error)")
            return []
        }
    }

    
    // Loading our language patterns
    func loadLanguagePatterns(rangeDays: Int) async {
        // Refresh optionality to look cleaner
        guard Date().timeIntervalSince(lastLangFetch ?? .distantPast) > 45 else { return }
        lastLangFetch = Date()
        isLoadingLanguage = true
        defer { isLoadingLanguage = false }
        
        guard let uid = AuthService.shared.userId else { return }

        isLoadingLanguage = true
        defer { isLoadingLanguage = false }

        // 1) Build the exact, small inputs you’d send to GPT (bullets+signals)
        let bullets = await fetchBullets(rangeDays: rangeDays)   // your existing logic
        let signals = await fetchSignals(rangeDays: rangeDays)   // your existing logic

        // 2) Make a digest that changes only when inputs change
        let inputString = "range:\(rangeDays)\nB:\(bullets.joined(separator: "|"))\nS:\(signals.debugDescription)"
        let digest = sha256(inputString)

        // 3) Try Firestore cache first
        if let cached = try? await FirestoreService.shared.readLanguageCache(uid: uid, rangeDays: rangeDays),
           cached.digest == digest {
            self.commonThemes = cached.themes
            self.focusTitle = cached.focusTitle
            self.focusDescription = cached.focusDescription
            return
        }

        // 4) No valid cache → call GPT
        if let res = await ChatService.shared.generateLanguageThemesAndFocus(
            bullets: bullets,
            signals: signals
        ) {
            self.commonThemes = res.themes
            self.focusTitle = res.focus_title
            self.focusDescription = res.focus_description

            // 5) Write cache
            let toSave = FirestoreService.LanguageCache(
                themes: res.themes,
                focusTitle: res.focus_title,
                focusDescription: res.focus_description,
                digest: digest,
                updatedAt: Timestamp(date: Date())
            )
            try? await FirestoreService.shared.writeLanguageCache(uid: uid, rangeDays: rangeDays, cache: toSave)
        } else {
            // fall back (keep old UI, don’t thrash)
        }
    }
    
    // MARK: - Load Personal Recommendations
    func loadPersonalRecommendation(rangeDays: Int) async {
        guard let uid = AuthService.shared.userId else { return }
        isLoadingRecommendation = true
        defer { isLoadingRecommendation = false }

        // Inputs (keep tiny)
        let bullets = await fetchBullets(rangeDays: rangeDays)
        let signals = await fetchSignals(rangeDays: rangeDays)

        // Optional: simple metrics you likely already have in the VM
        let gratitudeTotal = self.gratitudeTotal
        let toneTop = self.radarPoints.sorted(by: { $0.value > $1.value }).first?.label ?? ""

        // Build digest so we only recompute when inputs change
        let digest = sha256("r:\(rangeDays)|B:\(bullets.joined(separator: "|"))|S:\(signals.debugDescription)|G:\(gratitudeTotal)|T:\(toneTop)")

        // Cache hit?
        if let cached = try? await FirestoreService.shared.readRecommendationCache(uid: uid, rangeDays: rangeDays),
           cached.digest == digest {
            self.recTitle = cached.title
            self.recBody = cached.body
            return
        }

        // Call model
        if let res = await ChatService.shared.generatePersonalizedRecommendation(
            bullets: bullets,
            signals: signals,
            gratitudeTotal: gratitudeTotal,
            topTone: toneTop,
            lastTitle: self.recTitle ?? ""     // avoid repeats
        ) {
            self.recTitle = res.title
            self.recBody = res.body

            // Save cache
            let cache = FirestoreService.RecommendationCache(
                title: res.title,
                body: res.body,
                digest: digest,
                updatedAt: Date()
            )
            try? await FirestoreService.shared.writeRecommendationCache(uid: uid, rangeDays: rangeDays, cache: cache)
        }
    }


    

}

