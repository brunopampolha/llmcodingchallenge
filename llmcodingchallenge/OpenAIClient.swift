//
//  OpenAIClient.swift
//  llmcodingchallenge
//
//  Created by Bruno Pampolha on 11/08/25.
//

import Foundation

/// Minimal OpenAI client for iOS 14 / Swift 5.3 (no async/await).
final class OpenAIClient {

    struct ChatMessage: Encodable { let role: String; let content: String }

    private let apiKey: String
    private let session: URLSession
    private let model: String

    init?(apiKey: String?, model: String = "gpt-4o-mini") {
        guard let key = apiKey, key.isEmpty == false else { return nil }
        self.apiKey = key
        self.model = model
        let conf = URLSessionConfiguration.ephemeral
        conf.timeoutIntervalForRequest = 30
        conf.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: conf)
    }

    /// Calls Chat Completions with Structured Outputs (JSON Schema).
    func layoutInstruction(
        for userPrompt: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // System prompt keeps the model "on the rails".
        let system = """
        You convert natural-language UI requests into STRICT JSON that matches the provided JSON Schema.
        Do not add backticks or commentary. Only return the JSON object.
        For color references always use hexadecimal.
        """

        // Chat messages
        let messages: [ChatMessage] = [
            .init(role: "system", content: system),
            .init(role: "user", content: userPrompt)
        ]

        // JSON Schema matching our LayoutInstruction type
        let schema: [String: Any] = [
            "name": "layout_instruction",
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "properties": [
                    "background": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "color": ["type": "string"]
                        ]
                    ],
                    "title": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "text": ["type": "string"],
                            "color": ["type": "string"],
                            "fontSize": ["type": "number"]
                        ]
                    ],
                    "fields": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "color": ["type": "string"],
                            "textColor": ["type": "string"],
                            "cornerRadius": ["type": "number"]
                        ]
                    ],
                    "button": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "text": ["type": "string"],
                            "color": ["type": "string"],
                            "outline": ["type": "boolean"],
                            "fontSize": ["type": "number"],
                            "padding": ["type": "number"],
                            "accentColor": ["type": "string"]
                        ]
                    ],
                    "layout": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "spacing": ["type": "number"]
                        ]
                    ]
                ]
            ]
        ]

        // Request body
        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0,
            "response_format": [
                "type": "json_schema",
                "json_schema": schema
            ]
        ]

        // Build request
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        let task = session.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "OpenAIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                if let s = String(bytes: data, encoding: .utf8) {
                    print(s)
                }
                // Minimal decode of { choices[0].message.content }
                let root = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let choices = root?["choices"] as? [[String: Any]]
                let message = choices?.first?["message"] as? [String: Any]
                if let content = message?["content"] as? String {
                    completion(.success(content))
                } else {
                    let text = String(data: data, encoding: .utf8) ?? "?"
                    completion(.failure(NSError(domain: "OpenAIClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unexpected response: \(text)"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
