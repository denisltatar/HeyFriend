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

        try await sessionRef(uid, sid).setData(write, merge: true)

        // Lightweight Insights list row
        var tones = [mapped.tone]
        if let extra = mapped.supportingTones { tones.append(contentsOf: extra) }
        try await insightSummariesRef(uid).document(sid).setData([
            "createdAt": FieldValue.serverTimestamp(),
            "summary": mapped.summary.first ?? mapped.tone,
            "topTones": tones,
            "durationSec": durationSec
        ], merge: true)
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
    
    
    // MARK: - Entitlements
    struct EntitlementsDTO: Codable {
        var plan: String = "free"      // "free" or "plus"
        var freeSessionsUsed: Int = 0
        var freeLimit: Int = 4
        var updatedAt: Timestamp = Timestamp(date: Date())
    }

    private func entitlementsRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid).collection("meta").document("entitlements")
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
        entitlementsRef(uid).addSnapshotListener { snap, _ in
            guard let data = try? snap?.data(as: EntitlementsDTO.self) else {
                onChange(nil)
                return
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


    func setPlus(uid: String) async throws {
        try await entitlementsRef(uid).setData([
            "plan": "plus",
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


}

