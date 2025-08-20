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
    struct RawSummary: Codable { let summary: [String]; let tone: String }
    
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

        let system = "You are a supportive reflection assistant. Output only valid JSON with keys 'summary' (2–3 short bullets) and 'tone' (one sentence). No extra text."
        let user = """
        From this transcript, return JSON only:
        {
          "summary": ["<4–6 bullets, each ≤15 words>"],
          "tone": "<one short sentence about overall tone>"
        }

        If transcript indicates imminent self-harm or harm to others, return:
        {
          "summary": ["We can’t summarize right now."],
          "tone": "Please review support options and consider immediate help."
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

            let summary = SessionSummary(
                id: sessionId,
                summary: Array(raw.summary.prefix(3)),
                tone: raw.tone,
                createdAt: Date()
            )
            completion(summary)
        }
        .resume()
    }
}
