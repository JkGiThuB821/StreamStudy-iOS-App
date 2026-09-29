//
//  ResourceDiscoveryService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 29/9/2026.
//

import Foundation
import SwiftData

struct DiscoveryOutcome {
    var addedCount: Int = 0
    var failureMessages: [String] = []

    var hasPartialFailure: Bool { !failureMessages.isEmpty }
}

enum ResourceDiscoveryService {
    static func discoverResources(for topic: Topic, modelContext: ModelContext) async -> DiscoveryOutcome {
        let query = topic.title
        let tag = self.tag(for: topic)

        async let videos: Result<[YouTubeVideoResult], Error> = attempt { try await YouTubeService.searchVideos(query: query) }
        async let articles: Result<[DevToArticleResult], Error> = attempt { try await DevToService.fetchArticles(tag: tag) }
        let curated = CuratedResourceManifest.links(for: tag)

        var outcome = DiscoveryOutcome()

        switch await videos {
        case .success(let results):
            for video in results {
                let resource = LearningResource(
                    title: video.title,
                    urlString: "https://www.youtube.com/watch?v=\(video.id)",
                    sourceName: "YouTube — \(video.channelTitle)",
                    type: .video,
                    durationMinutes: max(video.durationMinutes, 1),
                    thumbnailURLString: video.thumbnailURL
                )
                resource.topic = topic
                modelContext.insert(resource)
                outcome.addedCount += 1
            }
        case .failure(let error):
            outcome.failureMessages.append("YouTube: \(error.localizedDescription)")
        }

        switch await articles {
        case .success(let results):
            for article in results {
                let resource = LearningResource(
                    title: article.title,
                    urlString: article.url,
                    sourceName: "dev.to — \(article.author)",
                    type: .article,
                    durationMinutes: article.readingTimeMinutes,
                    thumbnailURLString: article.coverImageURL
                )
                resource.topic = topic
                modelContext.insert(resource)
                outcome.addedCount += 1
            }
        case .failure(let error):
            outcome.failureMessages.append("dev.to: \(error.localizedDescription)")
        }

        for link in curated {
            let resource = LearningResource(
                title: link.title,
                urlString: link.url,
                sourceName: link.sourceName,
                type: .documentation,
                durationMinutes: link.estimatedMinutes
            )
            resource.topic = topic
            modelContext.insert(resource)
            outcome.addedCount += 1
        }

        topic.hasSearchedForResources = true

        return outcome
    }

    static func tag(for topic: Topic) -> String {
        if !topic.searchTag.trimmingCharacters(in: .whitespaces).isEmpty {
            return topic.searchTag.lowercased()
        }
        return topic.title
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func attempt<T>(_ work: () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await work())
        } catch {
            return .failure(error)
        }
    }
}
