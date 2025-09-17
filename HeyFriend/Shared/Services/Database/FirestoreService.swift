//
//  FirestoreService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/28/25.
//

import Foundation
import FirebaseFirestore

enum SessionStartError: Error {
    case notSignedIn
    case freeLimitReached
}

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private init() {}

    // MARK: - Paths
    private func userRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }
    private func sessionsRef(_ uid: String) -> CollectionReference {
        userRef(uid).collection("sessions")
    }
    private func sessionRef(_ uid: String, _ sid: String) -> DocumentReference {
        sessionsRef(uid).document(sid)
    }
    private func insightSummariesRef(_ uid: String) -> CollectionReference {
        userRef(uid).collection("insight_summaries")
    }
    
    private func entitlementsRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid).collection("meta").document("entitlements")
    }

    // MARK: - Lifecycle
    func startSession(uid: String) async throws -> String {
        let doc = sessionsRef(uid).document()
        try await doc.setData([
            "startedAt": FieldValue.serverTimestamp()
        ], merge: true)
        return doc.documentID
    }

    func updateTranscript(uid: String, sid: String, transcript: String) async throws {
        try await sessionRef(uid, sid).setData([
            "transcriptText": transcript
        ], merge: true)
    }
    
    // MARK: - Gratitude counting (user utterances preferred)
//    private func countGratitudeMentions(userUtterances: [String]?) -> Int {
//        // If we were given explicit user lines, use them; else return 0 and the caller can fallback.
//        guard let lines = userUtterances, !lines.isEmpty else { return 0 }
//
//        let patterns: [NSRegularExpression] = [
//            try! NSRegularExpression(pattern: #"\bthanks?\b"#, options: [.caseInsensitive]),
//            try! NSRegularExpression(pattern: #"\bthank\s+you\b"#, options: [.caseInsensitive]),
//            try! NSRegularExpression(pattern: #"\bi(?:'m| am)?\s+grateful\b"#, options: [.caseInsensitive]),
//            try! NSRegularExpression(pattern: #"\bi\s+appreciate(?:\s+(it|you|that))?\b"#, options: [.caseInsensitive]),
//            try! NSRegularExpression(pattern: #"\bappreciation\b"#, options: [.caseInsensitive])
//        ]
//        let negation = try! NSRegularExpression(pattern: #"\b(not|nothing|don'?t|didn'?t)\b"#, options: [.caseInsensitive])
//
//        var total = 0
//        for raw in lines {
//            let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
//            guard !s.isEmpty else { continue }
//            let full = NSRange(s.startIndex..<s.endIndex, in: s)
//
//            var lineCount = patterns.reduce(0) { acc, re in acc + re.numberOfMatches(in: s, range: full) }
//            if negation.firstMatch(in: s, range: full) != nil {
//                lineCount = max(0, lineCount - 1) // simple negation guard
//            }
//            total += lineCount
//        }
//        return total
//    }

    /// Attempts to extract **user-only** utterances from the session doc.
    /// Preferred: an array field `userUtterances: [String]`.
    /// Fallback: split `transcriptText` by lines and keep those that look like the user (e.g. "You:", "User:")
    private func extractUserUtterances(from sessionData: [String: Any]) -> [String] {
        if let arr = sessionData["userUtterances"] as? [String] {
            return arr
        }
        var userLines: [String] = []
        if let txt = sessionData["transcriptText"] as? String {
            // Heuristic: keep bare lines or lines prefixed as the user; drop assistant/bot lines.
            let lines = txt.components(separatedBy: .newlines)
            for l in lines {
                let t = l.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                let lower = t.lowercased()
                if lower.hasPrefix("assistant:") || lower.hasPrefix("bot:") || lower.hasPrefix("heyfriend:") {
                    continue
                }
                // If transcript prefixes speakers, keep typical user prefixes:
                if lower.hasPrefix("you:") || lower.hasPrefix("user:") || lower.hasPrefix("me:") {
                    userLines.append(String(t.drop(while: { $0 != ":" }).dropFirst()).trimmingCharacters(in: .whitespaces))
                } else {
                    // If no prefixes in transcript, keep the line (best-effort).
                    userLines.append(t)
                }
            }
        }
        return userLines
    }


    /// Persist your SessionSummary (matches your existing struct)
    func writeSummaryBundle(
        uid: String,
        sid: String,
        durationSec: Int,
        mapped: SessionSummary
    ) async throws {
        var write: [String: Any] = [
            "endedAt": FieldValue.serverTimestamp(),
            "durationSec": durationSec,
            "summary": mapped.summary,
            "tone": mapped.tone,
            "createdAt": Timestamp(date: mapped.createdAt)
        ]
        if let st = mapped.supportingTones { write["supportingTones"] = st }
        if let tn = mapped.toneNote { write["toneNote"] = tn }
        if let lang = mapped.language {
            write["language"] = [
                "repeatedWords": lang.repeatedWords,
                "thinkingStyle": lang.thinkingStyle,
                "emotionalIndicators": lang.emotionalIndicators
            ]
        }
        if let rec = mapped.recommendation { write["recommendation"] = rec }
        
        if mapped.gratitudeMentions > 0 {
            write["gratitudeMentions"] = mapped.gratitudeMentions
        }

        try await sessionRef(uid, sid).setData(write, merge: true)

        // Lightweight Insights list row
        var tones = [mapped.tone]
        if let extra = mapped.supportingTones { tones.append(contentsOf: extra) }
        
        let now = Date()
        try await insightSummariesRef(uid).document(sid).setData([
            "createdAt": Timestamp(date: now),
            "createdAtServer": FieldValue.serverTimestamp(),
            "summary": mapped.summary.first ?? mapped.tone,
            "topTones": tones,
            "durationSec": durationSec,
            "gratitudeMentions": mapped.gratitudeMentions
        ], merge: true)
        print("📝 FirestoreService: wrote insight_summaries/\(sid) gratitude=\(mapped.gratitudeMentions)")
    }

    // MARK: - Reads for Insights
    func listInsightSummaries(uid: String, limit: Int = 50) async throws -> [QueryDocumentSnapshot] {
        let snap = try await insightSummariesRef(uid)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snap.documents
    }

    func getSession(uid: String, sid: String) async throws -> DocumentSnapshot {
        try await sessionRef(uid, sid).getDocument()
    }
    
    func writeHello(uid: String) async throws {
        try await db.collection("users").document(uid).setData([
            "hello": "world",
            "ts": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    // MARK: - Range queries for Insights

    func listSessionsInRange(uid: String, start: Date, end: Date) async throws -> [QueryDocumentSnapshot] {
        let snap = try await sessionsRef(uid)
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("createdAt", isLessThanOrEqualTo: Timestamp(date: end))
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return snap.documents
    }

    func listInsightSummariesInRange(uid: String, start: Date, endExclusive: Date) async throws -> [QueryDocumentSnapshot] {
        let db = Firestore.firestore()
        return try await db.collection("users").document(uid)
            .collection("insight_summaries")
            .whereField("createdAt", isGreaterThanOrEqualTo: start)
            .whereField("createdAt", isLessThan: endExclusive)     // 👈 half-open window
            .order(by: "createdAt")
            .getDocuments()
            .documents
//        let snap = try await insightSummariesRef(uid)
//            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: start))
//            .whereField("createdAt", isLessThanOrEqualTo: Timestamp(date: end))
//            .order(by: "createdAt", descending: false)
//            .getDocuments()
//        return snap.documents
    }
    
    
    // MARK: - Entitlements
    struct EntitlementsDTO: Codable {
        var plan: String = "free"      // "free" or "plus"
        var freeSessionsUsed: Int = 0
        var freeLimit: Int = 4
        
        // new fields (all optional so nothing breaks if missing)
        var store: String? = nil                   // e.g., "appstore"
        var productId: String? = nil               // e.g., "com.heyfriend.plus.monthly"
        var originalTransactionId: String? = nil   // stringified
        var expiresAt: Timestamp? = nil            // when sub expires (or nil)
        var updatedAt: Timestamp? = nil            // server-set on writes
    }
    

    // MVP-safe (non-transactional): create entitlements doc if missing.
    func ensureEntitlements(uid: String, defaultLimit: Int = 4) async throws {
        let doc = entitlementsRef(uid)
        let snap = try await doc.getDocument()
        if snap.exists { return }
        let dto = EntitlementsDTO(freeLimit: defaultLimit)
        try await doc.setData(from: dto, merge: true)
    }

    // Listen for entitlement changes (plan/usage).
    func observeEntitlements(uid: String, onChange: @escaping (EntitlementsDTO?) -> Void) -> ListenerRegistration {
        return entitlementsRef(uid).addSnapshotListener { snap, _ in
            guard let data = try? snap?.data(as: EntitlementsDTO.self) else {
                onChange(nil); return
            }
            onChange(data)
        }
    }
    
    // Atomic bump when a FREE user starts a session. No-op for PLUS.
    @discardableResult
    func incrementFreeUsageIfNeeded(uid: String) async throws -> EntitlementsDTO {
        let doc = entitlementsRef(uid)

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<EntitlementsDTO, Error>) in
            db.runTransaction({ (txn, errorPointer) -> Any? in
                do {
                    let snap = try txn.getDocument(doc)
                    var dto = try snap.data(as: EntitlementsDTO.self)

                    if dto.plan == "free" {
                        dto.freeSessionsUsed += 1
                    }
                    dto.updatedAt = Timestamp(date: Date())

                    try txn.setData(from: dto, forDocument: doc, merge: true)
                    return dto   // pass the updated value through
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { result, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let dto = result as? EntitlementsDTO {
                    cont.resume(returning: dto)
                } else {
                    cont.resume(throwing: NSError(domain: "FirestoreService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Transaction completed without a result"
                    ]))
                }
            })
        }
    }

    // When a subscription is ACTIVE
    func setPlus(uid: String,
                 productId: String,
                 originalTransactionId: String,
                 expiresAt: Date?) async throws {
        var payload: [String: Any] = [
            "plan": "plus",
            "store": "appstore",
            "productId": productId,
            "originalTransactionId": originalTransactionId,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let expiresAt {
            payload["expiresAt"] = Timestamp(date: expiresAt)
        } else {
            // remove if previously set
            payload["expiresAt"] = FieldValue.delete()
        }
        try await entitlementsRef(uid).setData(payload, merge: true)
    }
    
    // When there is NO active subscription
    func setFree(uid: String) async throws {
        try await entitlementsRef(uid).setData([
            "plan": "free",
            // clear sub metadata so the document tells the truth
            "store": FieldValue.delete(),
            "productId": FieldValue.delete(),
            "originalTransactionId": FieldValue.delete(),
            "expiresAt": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    @discardableResult
    func startSessionRespectingEntitlements(uid: String) async throws -> String {
        // Read current entitlements (create if missing)
        try await ensureEntitlements(uid: uid)
        let entitlementsDoc = entitlementsRef(uid)
        let snap = try await entitlementsDoc.getDocument()
        let data = snap.data() ?? [:]
        let plan = (data["plan"] as? String) ?? "free"
        let used = (data["freeSessionsUsed"] as? Int) ?? 0
        let limit = (data["freeLimit"] as? Int) ?? 4
        
        if plan == "plus" {
            // Unlimited: just create a session
            return try await startSession(uid: uid)
        } else {
            // Free: block if no remaining
            if used >= limit {
                throw SessionStartError.freeLimitReached
            }
            // Atomic bump THEN create session
            _ = try await incrementFreeUsageIfNeeded(uid: uid)
            return try await startSession(uid: uid)
        }
    }

    
    // MARK: - Insights cache (themes/focus)
    
    private func insightsCacheRef(_ uid: String) -> DocumentReference {
        userRef(uid).collection("meta").document("insights_cache")
    }

    struct LanguageCache: Codable {
        var themes: [String]
        var focusTitle: String
        var focusDescription: String
        var digest: String
        var updatedAt: Timestamp
    }

    // Keep your struct, or switch updatedAt to Date? if you prefer TTL math.
    // struct LanguageCache { var themes:[String]; var focusTitle:String; var focusDescription:String; var digest:String; var updatedAt: Timestamp }
    func readLanguageCache(uid: String, rangeDays: Int) async throws -> LanguageCache? {
        let snap = try await insightsCacheRef(uid).getDocument()
        guard let map = snap.data()?["r\(rangeDays)"] as? [String: Any] else { return nil }

        let themes = map["themes"] as? [String] ?? []
        let focusTitle = map["focusTitle"] as? String ?? ""
        let focusDescription = map["focusDescription"] as? String ?? ""
        let digest = map["digest"] as? String ?? ""
        let updatedAt = (map["updatedAt"] as? Timestamp) ?? Timestamp(date: .distantPast)

        // If required fields are missing, treat as no cache
        guard !themes.isEmpty, !focusTitle.isEmpty, !focusDescription.isEmpty, !digest.isEmpty else { return nil }

        return LanguageCache(
            themes: themes,
            focusTitle: focusTitle,
            focusDescription: focusDescription,
            digest: digest,
            updatedAt: updatedAt
        )
    }

    func writeLanguageCache(uid: String, rangeDays: Int, cache: LanguageCache) async throws {
        // You can still use serverTimestamp inside a nested map.
        let dict: [String: Any] = [
            "themes": cache.themes,
            "focusTitle": cache.focusTitle,
            "focusDescription": cache.focusDescription,
            "digest": cache.digest,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await insightsCacheRef(uid).setData(["r\(rangeDays)": dict], merge: true)
    }

    
    // MARK: - Recommendation cache
    
    private func recCacheRef(_ uid: String) -> DocumentReference {
        userRef(uid).collection("meta").document("recommendation_cache")
    }

    struct RecommendationCache: Codable {
        var title: String
        var body: String
        var digest: String
        var updatedAt: Date?
    }

    func readRecommendationCache(uid: String, rangeDays: Int) async throws -> RecommendationCache? {
        let snap = try await recCacheRef(uid).getDocument()
        guard let map = snap.data()?["r\(rangeDays)"] as? [String: Any] else { return nil }
        guard
            let title = map["title"] as? String,
            let body = map["body"] as? String,
            let digest = map["digest"] as? String
        else { return nil }
        let updatedAt = (map["updatedAt"] as? Timestamp)?.dateValue()
        return RecommendationCache(title: title, body: body, digest: digest, updatedAt: updatedAt)
    }

    func writeRecommendationCache(uid: String, rangeDays: Int, cache: RecommendationCache) async throws {
        let dict: [String: Any] = [
            "title": cache.title,
            "body": cache.body,
            "digest": cache.digest,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await recCacheRef(uid).setData(["r\(rangeDays)": dict], merge: true)
    }

    // MARK: - Session limit
    func markSessionWarning(uid: String, sid: String) async {
        try? await sessionRef(uid, sid).setData([
            "warningIssuedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func endSessionByTimeLimit(uid: String, sid: String) async {
        try? await sessionRef(uid, sid).setData([
            "status": "ended_time_limit",
            "endedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func setMaxDuration(uid: String, sid: String, seconds: Int) async {
        try? await sessionRef(uid, sid).setData([
            "maxDurationSeconds": seconds,
            "status": "active"
        ], merge: true)
    }
    
}

