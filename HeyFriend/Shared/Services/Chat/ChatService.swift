//
//  ChatService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import Foundation

final class ChatService {
    static let shared = ChatService()
    
    // 👇 Allow tests to inject a custom session. Default is .shared for the app.
    var session: URLSession = .shared

    private(set) var messages: [[String: String]] = [
        ["role": "system", "content": "You are a supportive, concise conversational partner. Acknowledge feelings, ask brief clarifying questions when useful, and keep responses under ~120 words unless asked for more."]
    ]

    func reset() {
        messages = [
            ["role": "system", "content": "You are a supportive, concise conversational partner. Acknowledge feelings, ask brief clarifying questions when useful, and keep responses under ~120 words unless asked for more."]
        ]
    }

    func sendMessage(_ user: String, completion: @escaping (String?) -> Void) {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            completion("I’m missing my API key on this device.")
            return
        }

        messages.append(["role": "user", "content": user])

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.7
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: req) { data, _, error in
            if let error = error {
                completion("Network error: \(error.localizedDescription)")
                return
            }
            guard
                let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let msg = choices.first?["message"] as? [String: Any],
                let content = msg["content"] as? String
            else {
                completion("Sorry, I didn’t catch that.")
                return
            }

            let reply = content.trimmingCharacters(in: .whitespacesAndNewlines)
            self.messages.append(["role": "assistant", "content": reply])
            completion(reply)
        }
        .resume()
    }
}

extension ChatService {
    // JSON you expect back from the model
    struct RawSummary: Codable {
        let summary: [String]
        let tone: String
        let supporting_tones: [String]?
        let tone_note: String?
        
        struct Language: Codable {
            let repeated_words: [String]
            let thinking_style: String
            let emotional_indicators: String
        }
        
        let language: Language?
        let recommendation: String?
        let gratitude_mentions: Int?
    }
    
    // Commpiling transcript
    var conversationTranscript: String {
        messages
            .compactMap { msg in
                guard let role = msg["role"], let content = msg["content"] else { return nil }
                return "\(role.capitalized): \(content)"
            }
            .joined(separator: "\n")
    }
    
    func generateSummary(sessionId: String, transcript: String, completion: @escaping (SessionSummary?) -> Void) {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            print("Missing API key.")
            completion(nil)
            return
        }

        Task {
            // ⬇️ Build a full-coverage source from the ENTIRE chat session
            let summarySource = await self.buildSummarySource(from: transcript, apiKey: apiKey)

            let system =
            """
            You are a supportive reflection assistant. You must base every field ONLY on the provided transcript.
            Return STRICT, MINIFIED JSON that matches the schema. Do not add commentary or code fences. Do not invent content that isn’t grounded
            in the transcript. Keep facts neutral and kind.
            """

            let user =
            """
            From the transcript below, extract fields. Output JSON ONLY with this schema:

            {
              "summary": ["<5 bullets, each ≤20 words>"],
              "tone": "<primary tone, 1–3 words>",
              "supporting_tones": ["<0–3 short tones>"],
              "tone_note": "<1 short sentence explaining the tone>",
              "language": {
                "repeated_words": ["<distinct words the USER uses repeatedly>"], // see rules
                "thinking_style": "<short phrase>",                                 // see rules, e.g. "Future-focused, analytical"
                "emotional_indicators": "<short phrase>"                            // see rules, e.g., "Cautious optimism"
              },
              "recommendation": "<≤300 tokens of friendly, actionable advice that ideally are CBT-DBT-aligned micro-steps, grounded based on what was discussed>"
              "gratitude_mentions": <integer count of times user expressed gratitude>
            }
            
            RULES
            - Work ONLY from the transcript; never include examples or placeholders.
            - Keep writing neutral, kind, non-clinical.
            - SUMMARY: concise, factual bullets (no duplicates). Use USER-centric phrasing. If an action/idea originated from the assistant, include it only if the USER explicitly agreed or considered it; phrase as “User is considering…”.
            - TONE: pick a single best-fit tone actually reflected in the transcript (e.g., Calm, Anxious, Hopeful).
            - SUPPORTING_TONES: 0–3 additional tones present (short nouns only).
            - TONE_NOTE: one sentence explaining tone choice with reference to speaker content (no quotes needed).
            - LANGUAGE.repeated_words:
              • Identify the speaker’s repeated lexical items (unigrams), case-insensitive.
              • Exclude common stopwords and filler (e.g., i, me, the, and, uh, um, like, you know, really, think, just, kind of, sorta, sort of).
              • Consider only USER utterances for repeated_words.
              • Consider word stems (e.g., “probable/probably” → “probably”).
              • Include up to 5 items that appear ≥3 times or feel noticeably frequent; otherwise return "none".
            - LANGUAGE.thinking_style: short phrase drawn from linguistic cues (e.g., temporal focus, modality, reasoning).
            - LANGUAGE.emotional_indicators: short phrase (e.g., “cautious optimism”, “frustrated but determined”) only if supported.
            - If LANGUAGE has no clear signals, omit the whole "language" object.
            - RECOMMENDATION: ≤300 tokens, concrete and doable (CBT/DBT-aligned micro-steps), grounded in what was discussed.
            - GRATITUDE_MENTIONS: - Count every separate sentence or phrase where the USER expresses gratitude or appreciation. Examples that count: "I'm grateful for...", "Thanks...", "I appreciate...", even if about different things. Count **each** occurrence, not just unique topics.
            - If there are signs of imminent self-harm/harm-to-others, instead return:
                {
                  "summary": ["We can’t summarize right now."],
                  "tone": "Please review support options and consider immediate help.",
                  "supporting_tones": [],
                  "tone_note": "",
                  "language": { "repeated_words": [], 
                                "thinking_style": "",
                                "emotional_indicators": "" },
                  "recommendation": "We noticed signs of imminent self-harm/harm-to-others. Please reachout to someone, anyone. Your life is valuable. You are worth it. You deserve to have an amazing and successfull life. There are things still in store for you! We love you!"
                }

            Transcript:
            \(summarySource)
            """

            var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "model": "gpt-4o",
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user",   "content": user]
                ],
                "temperature": 0.3
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)

            session.dataTask(with: req) { data, _, error in
                if let error = error {
                    print("Summary error: \(error)")
                    completion(nil); return
                }
                guard
                    let data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]],
                    let msg = choices.first?["message"] as? [String: Any],
                    let content = msg["content"] as? String
                else { completion(nil); return }

                let cleaned = content
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard let rawData = cleaned.data(using: .utf8),
                      let raw = try? JSONDecoder().decode(RawSummary.self, from: rawData)
                else { completion(nil); return }

                // Gratitude guard on FULL transcript
                let modelCount = raw.gratitude_mentions ?? 0
                let heuristicCount = self.fallbackGratitudeCount(in: transcript)
                let finalCount = max(modelCount, heuristicCount)
                
                let mapped = SessionSummary(
                    id: sessionId,
                    summary: Array(raw.summary.prefix(3)),
                    tone: raw.tone,
                    createdAt: Date(),
                    supportingTones: raw.supporting_tones,
                    toneNote: raw.tone_note,
                    language: raw.language.map {
                        .init(
                            repeatedWords: $0.repeated_words,
                            thinkingStyle: $0.thinking_style,
                            emotionalIndicators: $0.emotional_indicators
                        )
                    },
                    recommendation: raw.recommendation,
                    gratitudeMentions: finalCount
                )
                print("🔎 ChatService: model returned gratitude_mentions= \(modelCount), heuristic found gratitude_mentions= \(heuristicCount) → final = \(finalCount)")
                completion(mapped)
            }.resume()
        }
    }
    
    // MARK: - Map–Reduce helpers (full-session coverage)

    /// Parse "You:" / "HeyFriend:" lines into structured turns.
    private func extractTurns(from transcript: String) -> [(speaker: String, text: String)] {
        transcript
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                if let idx = line.firstIndex(of: ":") {
                    let spk = String(line[..<idx]).trimmingCharacters(in: .whitespaces).lowercased()
                    let txt = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                    return (spk, txt)
                } else {
                    return ("you", line) // default: user
                }
            }
    }

    /// Chunk turns without dropping anything. Chunks keep requests reliable but all content is processed.
    /// This is NOT a "limit" — it's a coverage guarantee across any session length.
    private func chunkTurns(_ turns: [(speaker: String, text: String)],
                            maxCharsPerChunk: Int = 8000) -> [[(speaker: String, text: String)]] {
        var chunks: [[(speaker: String, text: String)]] = []
        var current: [(speaker: String, text: String)] = []
        var currentLen = 0

        for t in turns {
            // rough cost: "You: " + newline + text
            let addLen = t.text.count + t.speaker.count + 7
            if currentLen + addLen > maxCharsPerChunk, !current.isEmpty {
                chunks.append(current)
                current.removeAll(keepingCapacity: true)
                currentLen = 0
            }
            current.append(t)
            currentLen += addLen
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.isEmpty ? [turns] : chunks
    }

    /// Render a chunk back into a compact transcript with role prefixes.
    private func renderChunk(_ chunk: [(speaker: String, text: String)]) -> String {
        chunk.map { spk, txt in
            if spk.hasPrefix("assistant") || spk.hasPrefix("bot") || spk.hasPrefix("heyfriend") {
                return "HeyFriend: \(txt)"
            } else {
                return "You: \(txt)"
            }
        }.joined(separator: "\n")
    }

    /// Light normalizer to help de-duplicate near-identical bullets.
    private func normalizeBullet(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
         .replacingOccurrences(of: #"[\s]+"#, with: " ", options: .regularExpression)
         .lowercased()
    }

    /// Per-chunk output model
    private struct ChunkOut: Decodable {
        struct Lang: Decodable {
            let repeated_words: [String]
            let thinking_style: String
            let emotional_indicators: String
        }
        let bullets: [String]
        let gratitude_mentions: Int
        let local_tone: String
        let language: Lang
    }

    /// Call the model for one chunk → 2–3 bullets + local counts/signals.
    /// Reuse your existing OpenAI request plumbing.
    private func summarizeChunk(_ text: String,
                                apiKey: String) async -> ChunkOut? {
        let prompt = """
        You are analyzing a portion of a user–assistant conversation.

        RULES:
        - JSON ONLY (no markdown/code fences).
        - "bullets": up to 3 short bullets for key USER topics in THIS chunk (fewer is fine; never invent).
        - "gratitude_mentions": integer count of USER gratitude utterances in THIS chunk (USER-only).
        - "local_tone": ONE of ["Calm","Hopeful","Reflective","Anxious","Stressed","Sad"] for the USER in THIS chunk.
        - "language": { "repeated_words": up to 5 single words the USER repeats (exclude filler: really, think, just, kinda, sort of, like, you know, uh/um), "thinking_style": short phrase, "emotional_indicators": short phrase }

        Chunk:
        ---
        \(text)
        ---

        JSON schema:
        {
          "bullets": ["string", ...],
          "gratitude_mentions": 0,
          "local_tone": "Calm",
          "language": {
            "repeated_words": ["string", ...],
            "thinking_style": "string",
            "emotional_indicators": "string"
          }
        }
        """

        // Build request (same style as your current generateSummary)
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": "Return ONLY valid, minified JSON that matches the requested schema."],
                ["role": "user", "content": prompt]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        return await withCheckedContinuation { cont in
            session.dataTask(with: req) { data, _, _ in
                guard
                    let data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]],
                    let msg = choices.first?["message"] as? [String: Any],
                    let content = msg["content"] as? String
                else { cont.resume(returning: nil); return }

                let cleaned = content
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard let rawData = cleaned.data(using: .utf8),
                      let out = try? JSONDecoder().decode(ChunkOut.self, from: rawData) else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: out)
            }.resume()
        }
    }

    /// Merge many bullets into 1–6 across the full session without fabricating content.
    private func finalizeSummary(allBullets: [String],
                                 apiKey: String) async -> [String] {
        guard !allBullets.isEmpty else { return [] }

        let prompt = """
        Create a concise, user-friendly session summary that reflects the ENTIRE conversation.
        Input bullets (unordered, possibly overlapping):
        ---
        \(allBullets.joined(separator: "\n"))
        ---

        RULES:
        - Return JSON ONLY: { "bullets": ["string", ...] }
        - 1–6 bullets total, covering ALL major topics across the whole session.
        - If there are <3 meaningful topics, return fewer (do NOT invent).
        - Remove duplicates and merge near-duplicates.
        """

        struct FinalOut: Decodable { let bullets: [String] }

        // Build request
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": "gpt-4o",
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": "Return ONLY valid, minified JSON that matches the requested schema."],
                ["role": "user", "content": prompt]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        return await withCheckedContinuation { cont in
            session.dataTask(with: req) { data, _, _ in
                guard
                    let data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]],
                    let msg = choices.first?["message"] as? [String: Any],
                    let content = msg["content"] as? String
                else { cont.resume(returning: []); return }

                let cleaned = content
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let data = cleaned.data(using: .utf8),
                   let out = try? JSONDecoder().decode(FinalOut.self, from: data) {
                    cont.resume(returning: Array(out.bullets.prefix(6)))
                } else {
                    // Fallback: deterministic de-dupe
                    var seen = Set<String>(), merged: [String] = []
                    for b in allBullets {
                        let k = self.normalizeBullet(b)
                        if !k.isEmpty, !seen.contains(k) {
                            seen.insert(k); merged.append(b)
                        }
                        if merged.count >= 6 { break }
                    }
                    cont.resume(returning: merged)
                }
            }.resume()
        }
    }
    
    // Evenly sample N elements across an array without losing boundaries.
    private func stratifiedSample<T>(_ arr: [T], take n: Int) -> [T] {
        guard n > 0, !arr.isEmpty else { return [] }
        if arr.count <= n { return arr }
        let step = Double(arr.count - 1) / Double(n - 1)
        return (0..<n).map { arr[Int(round(Double($0) * step))] }
    }

    /// Build a full-session source for the existing summary prompt:
    /// - map step: per-chunk bullets → merged 1–6 bullets across whole session
    /// - plus representative user/assistant snippets spanning start→mid→end
    private func buildSummarySource(from transcript: String, apiKey: String) async -> String {
        let turns = extractTurns(from: transcript)
        guard !turns.isEmpty else { return transcript }

        // 1) Chunk the full session (you already have chunkTurns/renderChunk)
        let chunks = chunkTurns(turns, maxCharsPerChunk: 8000)

        // 2) Per-chunk bullets (re-uses your summarizeChunk)
        var allBullets: [String] = []
        for c in chunks {
            let block = renderChunk(c)
            if let out = await summarizeChunk(block, apiKey: apiKey) {
                allBullets.append(contentsOf: out.bullets)
            }
        }
        let mergedBullets = await finalizeSummary(allBullets: allBullets, apiKey: apiKey)  // 1–6; no invention

        // 3) Representative snippets across the ENTIRE session (user-focused + a light assistant sprinkle)
        let userLines = turns
            .filter { !$0.speaker.hasPrefix("assistant") && !$0.speaker.hasPrefix("heyfriend") }
            .map(\.text)
        let assistantLines = turns
            .filter {  $0.speaker.hasPrefix("assistant") || $0.speaker.hasPrefix("heyfriend") }
            .map(\.text)

        let sampleUser = stratifiedSample(userLines, take: 12).map { "• \($0)" }.joined(separator: "\n")
        let sampleAsst = stratifiedSample(assistantLines, take: 6).map { "• \($0)" }.joined(separator: "\n")

        // 4) Compose the source that your current prompt will read
        var sections: [String] = []
        if !mergedBullets.isEmpty {
            sections.append("""
            Session-wide topic bullets (prep, de-duplicated):
            \(mergedBullets.map { "• \($0)" }.joined(separator: "\n"))
            """)
        }
        sections.append("""
        Representative USER snippets (start→mid→end):
        \(sampleUser.isEmpty ? "—" : sampleUser)
        """)
        if !sampleAsst.isEmpty {
            sections.append("""
            Light ASSISTANT context (sparse):
            \(sampleAsst)
            """)
        }
        return sections.joined(separator: "\n\n")
    }


    
    // MARK: Updated Gratitude Counter
    
    /// Extracts likely USER-only utterances from a transcript where lines may be prefixed,
    /// and counts gratitude-related expressions with a small negation guard.
    private func fallbackGratitudeCount(in transcript: String) -> Int {
        // 1) Pull out user-only lines
        let lines = transcript
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                let lower = line.lowercased()
                // Drop assistant/bot lines outright
                if lower.hasPrefix("assistant:") || lower.hasPrefix("bot:") || lower.hasPrefix("heyfriend:") {
                    return false
                }
                return true
            }
            .map { line -> String in
                // Strip common user prefixes like "You:", "User:", "Me:"
                if let idx = line.firstIndex(of: ":"), line[..<idx].lowercased().trimmingCharacters(in: .whitespaces) ~= "you|user|me" {
                    return String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                }
                return line
            }

        // 2) Patterns to count (occurrence-based, not just per-line)
        let patterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: #"\bi'?m\s+grateful\b"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"\bgrateful\b"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"\bgratitude\b"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"\bthank\s+you\b"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"\bthanks\b"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"\bthankful\b"#, options: [.caseInsensitive]),   // 👈 added
            try! NSRegularExpression(pattern: #"\bappreciate(?:\b|\s)"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"\bappreciation\b"#, options: [.caseInsensitive])
        ]
        // Very light negation guard in the same line
        let negation = try! NSRegularExpression(pattern: #"\b(?:not|nothing|don'?t|didn'?t|isn'?t|ain'?t)\b"#, options: [.caseInsensitive])

        var total = 0
        for raw in lines {
            let s = raw.lowercased()
            let range = NSRange(s.startIndex..<s.endIndex, in: s)

            // If a negator appears in the same line, discount one hit
            let negated = negation.firstMatch(in: s, options: [], range: range) != nil

            var count = 0
            for re in patterns {
                count += re.numberOfMatches(in: s, options: [], range: range)
            }
            if negated, count > 0 { count -= 1 }

            total += max(0, count)
        }
        return total
    }


    
    // MARK: - Language Patterns Cache Response
    
    // Struct for language patterns found on Insights page!
    struct LanguageThemesResponse: Codable {
        let themes: [String]           // 2–4 short tags, e.g., ["Growth mindset","Future planning"]
        let focus_title: String        // e.g., "Distortion Awareness"
        let focus_description: String  // ≤ ~2 sentences, supportive; NOT an action plan
    }
    
    // Generating theme and focus on Language Patterns
    func generateLanguageThemesAndFocus(
        bullets: [String],
        signals: [[String: Any]]
    ) async -> LanguageThemesResponse? {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            print("Missing API key.")
            return nil
        }

        // Keep input small
        let joinedBullets = bullets.prefix(24).map { "• \($0)" }.joined(separator: "\n")
        let trimmedSignals: [[String: Any]] = signals.prefix(24).map { s in
            var out: [String: Any] = [:]
            if let r = s["repeated"] as? [String], !r.isEmpty { out["repeated"] = Array(r.prefix(5)) }
            if let t = s["thinking"] as? String, !t.isEmpty { out["thinking"] = t }
            if let e = s["emotional"] as? String, !e.isEmpty { out["emotional"] = e }
            return out
        }

        let system =
        """
        You are a careful summarizer. Extract compact themes and a brief focus snippet from short bullets and language signals.
        Keep it neutral, supportive, non-clinical. Output STRICT minified JSON only.
        """

        let user =
        """
        DATA
        - Bullets:
        \(joinedBullets)

        - Language signals (each item may include repeated words, thinking style, emotional indicators):
        \(trimmedSignals)

        TASK
        1) THEMES: Return 2–4 concise tags that capture recurring subject matter or approach (e.g., "Growth mindset", "Future planning", "Relationships", etc...).
           - Avoid clinical terms; avoid verbs; keep each ≤ 2–3 words.
        2) FOCUS: A short, helpful spotlight (NOT an action plan and NOT the per-session personalized recommendation).
           - Provide a title (≤ 4 words) and a 1–2 sentence supportive description that normalizes and gently orients attention.

        JSON SHAPE
        {
          "themes": ["<2–4 short tags>"],
          "focus_title": "<short title>",
          "focus_description": "<1–2 sentences>"
        }
        """

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": user]
            ],
            "temperature": 0.2
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await session.data(for: req)
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let msg = choices.first?["message"] as? [String: Any],
                var content = msg["content"] as? String
            else { return nil }

            content = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
            guard let raw = content.data(using: .utf8) else { return nil }
            let parsed = try JSONDecoder().decode(LanguageThemesResponse.self, from: raw)
            return parsed
        } catch {
            print("generateLanguageThemesAndFocus error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Personal Recommendation Cache Response
    
    struct RecommendationResponse: Codable { let title: String; let body: String }
        func generatePersonalizedRecommendation(
            bullets: [String],
            signals: [[String: Any]],
            gratitudeTotal: Int,
            topTone: String,
            lastTitle: String
        ) async -> RecommendationResponse? {
            guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else { return nil }

            let system = """
            You produce short, supportive, non-clinical, *actionable* recommendations.
            Output ONLY minified JSON.
            """

            let user = """
            CONTEXT
            - Bullets (recent insights): \(bullets.prefix(16))
            - Language signals: \(signals.prefix(16))
            - GratitudeTotal: \(gratitudeTotal)
            - TopTone: \(topTone)
            - Avoid repeating previous title: \(lastTitle)

            REQUIREMENTS
            - Title ≤ 5 words, imperative or encouraging.
            - Body 1–2 sentences, specific and time-boxed (e.g., "2 minutes tonight…").
            - Friendly, non-judgmental, no therapy/diagnosis terms.

            JSON SHAPE: {"title":"...", "body":"..."}
            """

            var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "model": "gpt-4o",
                "temperature": 0.3,
                "messages": [
                    ["role":"system","content":system],
                    ["role":"user","content":user]
                ]
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, _) = try await session.data(for: req)
                guard
                    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = root["choices"] as? [[String: Any]],
                    let msg = choices.first?["message"] as? [String: Any],
                    var content = msg["content"] as? String
                else { return nil }
                content = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                let decoded = try JSONDecoder().decode(RecommendationResponse.self, from: Data(content.utf8))
                return decoded
            } catch { return nil }
        }
    
    
}
