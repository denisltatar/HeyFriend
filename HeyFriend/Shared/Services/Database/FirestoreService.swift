//
//  FirestoreService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/28/25.
//

import Foundation
import FirebaseFirestore

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
}

