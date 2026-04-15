import Foundation

@MainActor
class AIManager: ObservableObject {
    private let store: TranscriptionStore

    init(store: TranscriptionStore) {
        self.store = store
    }

    /// Called when a silence-delimited utterance is finalized.
    /// `text` is exactly the just-completed sentence — no accumulation needed.
    func onNewSegment(text: String) {
        guard !text.isEmpty, ConfigManager.apiKey != nil else { return }
        Task { await process(text: text) }
    }

    // MARK: - Private

    private func process(text: String) async {
        guard let key = ConfigManager.apiKey else { return }

        store.isAIProcessing = true
        defer { store.isAIProcessing = false }

        do {
            let result = try await callClaude(transcript: text, apiKey: key, language: store.selectedLanguage)
            if result.hasPrefix("Q:") {
                store.aiResponse = result
            }
        } catch {
            // Silently fail — AI is non-critical
        }
    }

    private func callClaude(transcript: String, apiKey: String, language: RecognitionLanguage) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let responseLang: String
        switch language {
        case .chinese: responseLang = "Respond in Chinese (简体中文)."
        case .english: responseLang = "Respond in English."
        case .auto:    responseLang = "Respond in the same language as the transcript."
        }

        let system = """
        You are a real-time meeting assistant analyzing live speech transcripts.

        QUESTION DETECTION — treat any of these as a question:
        - Explicit questions (ends with ？ or ?)
        - Implicit questions ("你觉得…", "怎么看", "有没有", "能不能", "是否", "可不可以", "多少", "什么时候", "为什么", "谁来")
        - Requests for input or decisions ("大家有什么想法", "有没有建议", "下一步怎么办")
        - English equivalents ("what do you think", "how should we", "any thoughts on")

        If the transcript contains a question (explicit or implicit), respond in this EXACT format:
        Q: <core question, concise>
        • <key point 1, 1-2 sentences>
        • <key point 2, 1-2 sentences>
        • <key point 3, 1-2 sentences>

        If there is NO question, respond with one concise summary sentence.

        Language rule: \(responseLang) No extra text. No explanations.
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 400,
            "system": system,
            "messages": [
                ["role": "user", "content": transcript]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.badResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String
        else { throw AIError.parseError }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AIError: Error {
    case badResponse
    case parseError
}
