//
//  DevToService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 29/9/2026.
//

import Foundation

struct DevToArticleResult: Identifiable {
    let id: Int
    let title: String
    let url: String
    let description: String
    let tags: String
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
    // `topDays` returns the most popular articles from the last N days instead of
    // just the newest ones, which gives a better pool to filter for relevance.
    static func fetchArticles(tag: String, maxResults: Int = 5, topDays: Int? = nil) async throws -> [DevToArticleResult] {
        var components = URLComponents(string: "https://dev.to/api/articles")!
        components.queryItems = [
            URLQueryItem(name: "tag", value: tag),
            URLQueryItem(name: "per_page", value: String(maxResults)),
        ]
        if let topDays {
            components.queryItems?.append(URLQueryItem(name: "top", value: String(topDays)))
        }

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse else { throw DevToServiceError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw DevToServiceError.httpError(http.statusCode) }

        let decoded = try JSONDecoder().decode([DevToArticle].self, from: data)
        return decoded.map {
            DevToArticleResult(
                id: $0.id,
                title: $0.title,
                url: $0.url,
                description: $0.description ?? "",
                tags: $0.tags ?? "",
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
    let description: String?
    let tags: String?
    let readingTimeMinutes: Int
    let coverImage: String?
    let user: User

    enum CodingKeys: String, CodingKey {
        case id, title, url, description, tags
        case readingTimeMinutes = "reading_time_minutes"
        case coverImage = "cover_image"
        case user
    }

    struct User: Decodable {
        let name: String
    }
}
