//
//  ChatService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import Foundation
import Foundation

class ChatService {
    static let shared = ChatService()

    func sendMessage(_ message: String, completion: @escaping (String?) -> Void) {
        // 🔑 Debug: Check if API key is found
        print("🔑 Found API Key: \(ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "nil")")
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            print("❌ Missing API Key")
            completion(nil)
            return
        }


        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o", // You can use "gpt-3.5-turbo" if you don’t have GPT-4 access
            "messages": [
                ["role": "system", "content": "You are a supportive friend trained in emotional reflection."],
                ["role": "user", "content": message]
            ],
            "temperature": 0.7
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            // ❌ Debug: Catch network error
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion("Sorry, I didn’t catch that. Can you try again?")
                return
            }

            // 🧠 Debug: Show raw GPT response
            if let data = data {
                print("🧠 GPT raw response: \(String(data: data, encoding: .utf8) ?? "No response body")")
            }
            
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let firstChoice = choices.first,
                let message = firstChoice["message"] as? [String: Any],
                let content = message["content"] as? String
            else {
                completion("Sorry, I didn’t catch that. Can you try again?")
                return
            }

            completion(content.trimmingCharacters(in: .whitespacesAndNewlines))
        }.resume()
    }
}
