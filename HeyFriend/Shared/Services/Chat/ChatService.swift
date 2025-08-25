//
//  ChatService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import Foundation

final class ChatService {
    static let shared = ChatService()

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

        URLSession.shared.dataTask(with: req) { data, _, error in
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

        // Keep the transcript small & user-only
        let clipped = String(transcript.suffix(4000))

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
                "repeated_words": ["<distinct words the speaker uses repeatedly>"], // see rules
                "thinking_style": "<short phrase>",                                 // see rules, e.g. "Future‑focused, analytical"
                "emotional_indicators": "<short phrase>"                            // see rules, e.g. "Cautious optimism"
              },
              "recommendation": "<≤300 tokens of friendly, actionable advice that ideally are CBT-DBT-aligned micro-steps, grounded based on what was discussed>"
            }
            
            RULES
            - Work ONLY from the transcript; never include examples or placeholders.
            - Keep writing neutral, kind, non‑clinical.
            - SUMMARY: concise, factual bullets (no duplicates).
            - TONE: pick a single best‑fit tone actually reflected in the transcript (e.g., Calm, Anxious, Hopeful).
            - SUPPORTING_TONES: 0–3 additional tones present (short nouns only).
            - TONE_NOTE: one sentence explaining tone choice with reference to speaker content (no quotes needed).
            - LANGUAGE.repeated_words:
              • Identify the speaker’s repeated lexical items (unigrams), case‑insensitive.
              • Exclude common stopwords and filler (e.g., i, me, the, and, uh, um, like, you know).
              • Consider word stems (e.g., “probable/probably” → “probably”).
              • Include up to 5 items that appear ≥3 times or feel noticeably frequent; otherwise return "none".
            - LANGUAGE.thinking_style: short phrase drawn from linguistic cues (e.g., temporal focus, modality, reasoning).
            - LANGUAGE.emotional_indicators: short phrase (e.g., “cautious optimism”, “frustrated but determined”) only if supported.
            - If LANGUAGE has no clear signals, omit the whole "language" object.
            - RECOMMENDATION: ≤300 tokens, concrete and doable (CBT/DBT‑aligned micro‑steps), grounded in what was discussed.
            - If there are signs of imminent self‑harm/harm-to-others, instead return:
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
            \(clipped)
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

        URLSession.shared.dataTask(with: req) { data, _, error in
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

            // Sometimes models wrap JSON with backticks—strip them if present
            let cleaned = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let rawData = cleaned.data(using: .utf8),
                  let raw = try? JSONDecoder().decode(RawSummary.self, from: rawData)
            else { completion(nil); return }

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
                recommendation: raw.recommendation
            )
            completion(mapped)
        }.resume()
    }
}
