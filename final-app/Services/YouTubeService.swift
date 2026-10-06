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
    let description: String
    let channelTitle: String
    let thumbnailURL: String?
    let durationMinutes: Int
}

enum YouTubeServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(reason: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No YouTube API key configured — see README \"YouTube Data API setup\"."
        case .invalidResponse:
            return "YouTube returned an unexpected response."
        case .apiError(let reason):
            return reason
        }
    }
}

enum YouTubeService {
    private static let baseURL = "https://www.googleapis.com/youtube/v3"

    static func searchVideos(query: String, maxResults: Int = 5) async throws -> [YouTubeVideoResult] {
        guard let key = APIKeys.youTubeDataAPIKey, !key.isEmpty else {
            throw YouTubeServiceError.missingAPIKey
        }

        let videoIds = try await search(query: query, maxResults: maxResults, key: key)
        guard !videoIds.isEmpty else { return [] }
        return try await videoDetails(ids: videoIds, key: key)
    }

    private static func search(
        query: String, maxResults: Int, key: String
    ) async throws -> [(id: String, title: String, description: String, channel: String, thumb: String?)] {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "relevanceLanguage", value: "en"),
            URLQueryItem(name: "key", value: key),
        ]

        let (data, response) = try await send(components.url!)
        try validate(response, data: data)

        let decoded = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
        return decoded.items.compactMap { item in
            guard let videoId = item.id.videoId else { return nil }
            return (
                id: videoId,
                title: item.snippet.title,
                description: item.snippet.description ?? "",
                channel: item.snippet.channelTitle,
                thumb: item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.defaultThumb?.url
            )
        }
    }

    private static func videoDetails(
        ids: [(id: String, title: String, description: String, channel: String, thumb: String?)], key: String
    ) async throws -> [YouTubeVideoResult] {
        var components = URLComponents(string: "\(baseURL)/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails"),
            URLQueryItem(name: "id", value: ids.map(\.id).joined(separator: ",")),
            URLQueryItem(name: "key", value: key),
        ]

        let (data, response) = try await send(components.url!)
        try validate(response, data: data)

        let decoded = try JSONDecoder().decode(YouTubeVideosResponse.self, from: data)
        let durationsById = Dictionary(uniqueKeysWithValues: decoded.items.map {
            ($0.id, Self.minutes(fromISO8601Duration: $0.contentDetails.duration))
        })

        return ids.map { entry in
            YouTubeVideoResult(
                id: entry.id,
                title: decodeHTMLEntities(entry.title),
                description: decodeHTMLEntities(entry.description),
                channelTitle: entry.channel,
                thumbnailURL: entry.thumb,
                durationMinutes: durationsById[entry.id] ?? 0
            )
        }
    }

    private static func send(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        return try await URLSession.shared.data(for: request)
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw YouTubeServiceError.invalidResponse }
        guard !(200...299).contains(http.statusCode) else { return }

        if let googleError = try? JSONDecoder().decode(GoogleAPIErrorEnvelope.self, from: data) {
            let reason = googleError.error.errors?.first?.reason ?? "unknown"
            throw YouTubeServiceError.apiError(reason: "\(googleError.error.message) (HTTP \(http.statusCode), reason: \(reason))")
        }
        throw YouTubeServiceError.apiError(reason: "YouTube API request failed (HTTP \(http.statusCode)).")
    }

    // search.list returns titles with HTML entities (e.g. &#39; for an apostrophe).
    private static func decodeHTMLEntities(_ text: String) -> String {
        [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">")]
            .reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
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
        let description: String?
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

private struct GoogleAPIErrorEnvelope: Decodable {
    let error: GoogleAPIError
    struct GoogleAPIError: Decodable {
        let message: String
        let errors: [ErrorDetail]?
        struct ErrorDetail: Decodable {
            let reason: String
        }
    }
}
