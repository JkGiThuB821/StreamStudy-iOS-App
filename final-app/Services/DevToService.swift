//
//  DevToService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 29/9/2026.
//

import Foundation

import Foundation

struct DevToArticleResult: Identifiable {
    let id: Int
    let title: String
    let url: String
    let author: String
    let readingTimeMinutes: Int
    let coverImageURL: String?
}

enum DevToServiceError: LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "dev.to returned an unexpected response."
        case .httpError(let code): return "dev.to API request failed (HTTP \(code))."
        }
    }
}

enum DevToService {
    static func fetchArticles(tag: String, maxResults: Int = 5) async throws -> [DevToArticleResult] {
        var components = URLComponents(string: "https://dev.to/api/articles")!
        components.queryItems = [
            URLQueryItem(name: "tag", value: tag),
            URLQueryItem(name: "per_page", value: String(maxResults)),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse else { throw DevToServiceError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw DevToServiceError.httpError(http.statusCode) }

        let decoded = try JSONDecoder().decode([DevToArticle].self, from: data)
        return decoded.map {
            DevToArticleResult(
                id: $0.id,
                title: $0.title,
                url: $0.url,
                author: $0.user.name,
                readingTimeMinutes: max($0.readingTimeMinutes, 1),
                coverImageURL: $0.coverImage
            )
        }
    }
}

private struct DevToArticle: Decodable {
    let id: Int
    let title: String
    let url: String
    let readingTimeMinutes: Int
    let coverImage: String?
    let user: User

    enum CodingKeys: String, CodingKey {
        case id, title, url
        case readingTimeMinutes = "reading_time_minutes"
        case coverImage = "cover_image"
        case user
    }

    struct User: Decodable {
        let name: String
    }
}
