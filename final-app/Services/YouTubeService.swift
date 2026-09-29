//
//  YouTubeService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 29/9/2026.
//

import Foundation

struct YouTubeVideoResult: Identifiable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: String?
    let durationMinutes: Int
}

enum YouTubeServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No YouTube API key configured (see Config/APIKeys.swift)."
        case .invalidResponse:
            return "YouTube returned an unexpected response."
        case .httpError(let code):
            return "YouTube API request failed (HTTP \(code))."
        }
    }
}

enum YouTubeService {
    private static let baseURL = "https://www.googleapis.com/youtube/v3"

    static func searchVideos(query: String, maxResults: Int = 5) async throws -> [YouTubeVideoResult] {
        guard APIKeys.youTubeDataAPIKey != "YOUR_YOUTUBE_API_KEY_HERE", !APIKeys.youTubeDataAPIKey.isEmpty else {
            throw YouTubeServiceError.missingAPIKey
        }

        let videoIds = try await search(query: query, maxResults: maxResults)
        guard !videoIds.isEmpty else { return [] }
        return try await videoDetails(ids: videoIds)
    }

    private static func search(query: String, maxResults: Int) async throws -> [(id: String, title: String, channel: String, thumb: String?)] {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "relevanceLanguage", value: "en"),
            URLQueryItem(name: "key", value: APIKeys.youTubeDataAPIKey),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        try validate(response)

        let decoded = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
        return decoded.items.compactMap { item in
            guard let videoId = item.id.videoId else { return nil }
            return (
                id: videoId,
                title: item.snippet.title,
                channel: item.snippet.channelTitle,
                thumb: item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.defaultThumb?.url
            )
        }
    }

    private static func videoDetails(ids: [(id: String, title: String, channel: String, thumb: String?)]) async throws -> [YouTubeVideoResult] {
        var components = URLComponents(string: "\(baseURL)/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails"),
            URLQueryItem(name: "id", value: ids.map(\.id).joined(separator: ",")),
            URLQueryItem(name: "key", value: APIKeys.youTubeDataAPIKey),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        try validate(response)

        let decoded = try JSONDecoder().decode(YouTubeVideosResponse.self, from: data)
        let durationsById = Dictionary(uniqueKeysWithValues: decoded.items.map {
            ($0.id, Self.minutes(fromISO8601Duration: $0.contentDetails.duration))
        })

        return ids.map { entry in
            YouTubeVideoResult(
                id: entry.id,
                title: entry.title,
                channelTitle: entry.channel,
                thumbnailURL: entry.thumb,
                durationMinutes: durationsById[entry.id] ?? 0
            )
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw YouTubeServiceError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw YouTubeServiceError.httpError(http.statusCode) }
    }

    private static func minutes(fromISO8601Duration duration: String) -> Int {
        var hours = 0, minutes = 0, seconds = 0
        var numberBuffer = ""
        var isTimeSection = false

        for char in duration {
            if char == "T" { isTimeSection = true; continue }
            if char.isNumber { numberBuffer.append(char); continue }
            let value = Int(numberBuffer) ?? 0
            numberBuffer = ""
            switch char {
            case "H": hours = value
            case "M" where isTimeSection: minutes = value
            case "S": seconds = value
            default: break
            }
        }
        return hours * 60 + minutes + (seconds >= 30 ? 1 : 0)
    }
}

// MARK: - Decodable response shapes

private struct YouTubeSearchResponse: Decodable {
    let items: [Item]
    struct Item: Decodable {
        let id: VideoId
        let snippet: Snippet
    }
    struct VideoId: Decodable {
        let videoId: String?
    }
    struct Snippet: Decodable {
        let title: String
        let channelTitle: String
        let thumbnails: Thumbnails
    }
    struct Thumbnails: Decodable {
        let defaultThumb: Thumbnail?
        let medium: Thumbnail?
        enum CodingKeys: String, CodingKey {
            case defaultThumb = "default"
            case medium
        }
    }
    struct Thumbnail: Decodable {
        let url: String
    }
}

private struct YouTubeVideosResponse: Decodable {
    let items: [Item]
    struct Item: Decodable {
        let id: String
        let contentDetails: ContentDetails
    }
    struct ContentDetails: Decodable {
        let duration: String
    }
}
