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
