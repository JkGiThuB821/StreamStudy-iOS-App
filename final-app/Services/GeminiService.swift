//
//  GeminiService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 6/10/2026.
//

import Foundation

enum GeminiServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Gemini API key configured: add GEMINI_API_KEY to Secrets.xcconfig."
        case .invalidResponse:
            return "Gemini returned an unexpected response."
        case .emptyResponse:
            return "Gemini returned no content."
        case .apiError(let message):
            return message
        }
    }
}

// Thin wrapper around the Gemini generateContent REST endpoint that asks for
// JSON matching a schema (structured output) and decodes it into a Swift type.
enum GeminiService {

    // "flash-latest" always points at Google's current Flash model, which is on
    // the free tier. Swap for a pinned model name (see aistudio.google.com) if needed.
    static let model = "gemini-flash-latest"

    private static let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    static var isConfigured: Bool {
        APIKeys.geminiAPIKey != nil
    }

    static func generateJSON<T: Decodable>(
        _ type: T.Type,
        prompt: String,
        schema: [String: Any],
        temperature: Double = 0.4
    ) async throws -> T {
        guard let key = APIKeys.geminiAPIKey else { throw GeminiServiceError.missingAPIKey }
        guard let url = URL(string: "\(baseURL)/\(model):generateContent") else {
            throw GeminiServiceError.invalidResponse
        }

        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": temperature,
                "responseMimeType": "application/json",
                "responseSchema": schema,
            ],
        ]

        var request = URLRequest(url: url, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GeminiServiceError.invalidResponse }

        guard (200...299).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data) {
                throw GeminiServiceError.apiError("Gemini: \(envelope.error.message) (HTTP \(http.statusCode))")
            }
            throw GeminiServiceError.apiError("Gemini request failed (HTTP \(http.statusCode)).")
        }

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        let text = decoded.candidates?.first?.content?.parts?
            .compactMap(\.text)
            .joined() ?? ""

        let json = stripCodeFences(text)
        guard !json.isEmpty, let jsonData = json.data(using: .utf8) else {
            throw GeminiServiceError.emptyResponse
        }
        return try JSONDecoder().decode(T.self, from: jsonData)
    }

    // Structured output should be raw JSON, but strip ```json fences just in case.
    private static func stripCodeFences(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```") {
            result = result
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }
}

// MARK: - Response shapes

private struct GenerateContentResponse: Decodable {
    let candidates: [Candidate]?

    struct Candidate: Decodable {
        let content: Content?
    }
    struct Content: Decodable {
        let parts: [Part]?
    }
    struct Part: Decodable {
        let text: String?
    }
}

private struct GeminiErrorEnvelope: Decodable {
    let error: Detail
    struct Detail: Decodable {
        let message: String
    }
}
