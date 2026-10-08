//
//  NetworkServiceTests.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 8/10/2026.
//
//  "API pull" tests: each service runs against StubURLProtocol, which returns
//  a canned API response, so success AND failure paths can be tested
//  reliably, offline, and without spending real YouTube / Gemini quota.
//

import Foundation
import Testing
@testable import final_app

// Serialized because the stub handler and API key overrides are shared state.
@MainActor
@Suite("API pulls (stubbed network)", .serialized)
struct NetworkServiceTests {

    // Swift Testing creates a fresh instance per test, so this resets
    // all shared state before every test.
    init() {
        StubURLProtocol.handler = nil
        StubURLProtocol.lastRequest = nil
        YouTubeService.session = StubURLProtocol.session
        DevToService.session = StubURLProtocol.session
        GeminiService.session = StubURLProtocol.session
        APIKeys.youTubeKeyOverride = nil
        APIKeys.geminiKeyOverride = nil
    }

    // MARK: - dev.to

    @Test("dev.to: a successful pull is parsed into articles")
    func devToSuccess() async throws {
        StubURLProtocol.handler = { _ in
            (200, """
            [{ "id": 1, "title": "SwiftData relationships", "url": "https://dev.to/a/1",
               "description": "One-to-many with #Predicate", "tags": "swift, swiftdata",
               "reading_time_minutes": 0, "cover_image": null, "user": { "name": "Ada" } }]
            """.utf8Data)
        }

        let articles = try await DevToService.fetchArticles(tag: "swiftdata", maxResults: 20, topDays: 365)

        #expect(articles.count == 1)
        #expect(articles[0].title == "SwiftData relationships")
        #expect(articles[0].author == "Ada")
        #expect(articles[0].readingTimeMinutes == 1)   // 0 is clamped to 1 minute
        let query = StubURLProtocol.lastRequest?.url?.query ?? ""
        #expect(query.contains("tag=swiftdata"))
        #expect(query.contains("top=365"))
    }

    @Test("dev.to: a server error is reported, not crashed on")
    func devToServerError() async {
        StubURLProtocol.handler = { _ in (500, Data()) }

        await #expect(throws: DevToServiceError.self) {
            try await DevToService.fetchArticles(tag: "swift")
        }
    }

    // MARK: - YouTube

    @Test("YouTube: search + video details are combined, with durations")
    func youTubeSuccess() async throws {
        APIKeys.youTubeKeyOverride = "test-key"
        StubURLProtocol.handler = { request in
            if request.url!.path.hasSuffix("/search") {
                return (200, """
                { "items": [{ "id": { "videoId": "abc" },
                  "snippet": { "title": "SwiftData &amp; Relationships", "description": "Learn it",
                               "channelTitle": "Sean", "thumbnails": { "medium": { "url": "https://img" } } } }] }
                """.utf8Data)
            }
            return (200, """
            { "items": [{ "id": "abc", "contentDetails": { "duration": "PT12M40S" } }] }
            """.utf8Data)
        }

        let videos = try await YouTubeService.searchVideos(query: "swiftdata relationships")

        #expect(videos.count == 1)
        #expect(videos[0].title == "SwiftData & Relationships")   // HTML entity decoded
        #expect(videos[0].durationMinutes == 13)                 // 12m40s rounds up
        #expect(videos[0].thumbnailURL == "https://img")
    }

    @Test("YouTube: quota exceeded gives a readable error")
    func youTubeQuotaExceeded() async {
        APIKeys.youTubeKeyOverride = "test-key"
        StubURLProtocol.handler = { _ in
            (403, """
            { "error": { "message": "The request cannot be completed because you have exceeded your quota.",
                         "errors": [{ "reason": "quotaExceeded" }] } }
            """.utf8Data)
        }

        do {
            _ = try await YouTubeService.searchVideos(query: "swift")
            Issue.record("Expected an error")
        } catch {
            #expect(error.localizedDescription.contains("quotaExceeded"))
            #expect(error.localizedDescription.contains("403"))
        }
    }

    @Test("YouTube: a missing API key fails before any request is made")
    func youTubeMissingKey() async {
        APIKeys.youTubeKeyOverride = ""

        await #expect(throws: YouTubeServiceError.self) {
            try await YouTubeService.searchVideos(query: "swift")
        }
        #expect(StubURLProtocol.lastRequest == nil)
    }

    @Test("ISO 8601 durations convert to minutes", arguments: [
        ("PT12M40S", 13), ("PT1H2M10S", 62), ("PT45S", 1), ("PT10S", 0), ("P0D", 0),
    ])
    func durations(input: String, minutes: Int) {
        #expect(YouTubeService.minutes(fromISO8601Duration: input) == minutes)
    }

    // MARK: - Gemini

    private struct Sample: Decodable, Equatable {
        let youtubeQuery: String
        let keywords: [String]
    }

    @Test("Gemini: structured JSON output is decoded (even inside ```json fences)")
    func geminiSuccess() async throws {
        APIKeys.geminiKeyOverride = "test-key"
        StubURLProtocol.handler = { _ in
            (200, #"""
            { "candidates": [{ "content": { "parts": [{ "text":
              "```json\n{\"youtubeQuery\": \"swiftdata relationships\", \"keywords\": [\"predicate\"]}\n```" }] } }] }
            """#.utf8Data)
        }

        let result = try await GeminiService.generateJSON(Sample.self, prompt: "test", schema: ["type": "OBJECT"])

        #expect(result == Sample(youtubeQuery: "swiftdata relationships", keywords: ["predicate"]))
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "x-goog-api-key") == "test-key")
        #expect(StubURLProtocol.lastRequest?.httpMethod == "POST")
    }

    @Test("Gemini: rate limiting (HTTP 429) surfaces Google's message")
    func geminiRateLimited() async {
        APIKeys.geminiKeyOverride = "test-key"
        StubURLProtocol.handler = { _ in
            (429, #"{ "error": { "message": "Resource has been exhausted" } }"#.utf8Data)
        }

        do {
            _ = try await GeminiService.generateJSON(Sample.self, prompt: "test", schema: [:])
            Issue.record("Expected an error")
        } catch {
            #expect(error.localizedDescription.contains("Resource has been exhausted"))
            #expect(error.localizedDescription.contains("429"))
        }
    }

    @Test("Gemini: an empty reply is an error, not a crash")
    func geminiEmptyReply() async {
        APIKeys.geminiKeyOverride = "test-key"
        StubURLProtocol.handler = { _ in (200, #"{ "candidates": [] }"#.utf8Data) }

        await #expect(throws: GeminiServiceError.self) {
            try await GeminiService.generateJSON(Sample.self, prompt: "test", schema: [:])
        }
    }

    @Test("Gemini: with no key the app knows to use its on-device fallback")
    func geminiMissingKey() {
        APIKeys.geminiKeyOverride = ""
        #expect(GeminiService.isConfigured == false)
    }
}
