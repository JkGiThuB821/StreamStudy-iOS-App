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
    var filteredOutCount: Int = 0
    var failureMessages: [String] = []
    var searchPlan: SearchPlan?

    var hasPartialFailure: Bool { !failureMessages.isEmpty }
}

enum ResourceDiscoveryService {

    // How many results to keep from each source after relevance filtering.
    private static let maxVideos = 4
    private static let maxArticles = 4

    static func discoverResources(for topic: Topic, modelContext: ModelContext) async -> DiscoveryOutcome {
        var outcome = DiscoveryOutcome()

        // 1. Work out what to search for from the title, description and subject.
        let (plan, planWarning) = await SearchPlanner.plan(for: topic)
        outcome.searchPlan = plan
        if let planWarning { outcome.failureMessages.append(planWarning) }

        var existingURLs = Set(topic.resources.map(\.urlString))

        // 2. Fetch from every source at once. One YouTube search (100 quota units)
        //    returns 8 candidates so there's room to drop irrelevant ones.
        async let videos: Result<[YouTubeVideoResult], Error> = attempt {
            try await YouTubeService.searchVideos(query: plan.youtubeQuery, maxResults: 8)
        }
        async let articles: Result<[DevToArticleResult], Error> = attempt {
            try await fetchDevToArticles(tags: plan.devToTags)
        }
        let curated = plan.curatedTags.flatMap(CuratedResourceManifest.links(for:))

        // 3. Keep only the most relevant results from each source.
        switch await videos {
        case .success(let results):
            let ranked = rank(results, keywords: plan.keywords, keepAtLeast: 2) {
                "\($0.title) \($0.description)"
            }
            outcome.filteredOutCount += results.count - min(ranked.count, maxVideos)

            for video in ranked.prefix(maxVideos) {
                let urlString = "https://www.youtube.com/watch?v=\(video.id)"
                guard existingURLs.insert(urlString).inserted else { continue }
                let resource = LearningResource(
                    title: video.title,
                    urlString: urlString,
                    sourceName: "YouTube — \(video.channelTitle)",
                    type: .video,
                    durationMinutes: max(video.durationMinutes, 1),
                    resourceDescription: String(video.description.prefix(400)),
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
            // dev.to tag feeds are broad, so articles must match at least one keyword.
            let ranked = rank(results, keywords: plan.keywords, keepAtLeast: 0) {
                "\($0.title) \($0.description) \($0.tags)"
            }
            outcome.filteredOutCount += results.count - min(ranked.count, maxArticles)

            for article in ranked.prefix(maxArticles) {
                guard existingURLs.insert(article.url).inserted else { continue }
                let resource = LearningResource(
                    title: article.title,
                    urlString: article.url,
                    sourceName: "dev.to — \(article.author)",
                    type: .article,
                    durationMinutes: article.readingTimeMinutes,
                    resourceDescription: article.description,
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
            guard existingURLs.insert(link.url).inserted else { continue }
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

        // Mark as searched regardless of partial failure, so a flaky network
        // call doesn't cause YouTube's search.list to be hit again on every
        // subsequent visit to this topic — the student can still add
        // resources manually (Stage 2's AddResourceView), or use "Search
        // Again" after fixing the tag, as a fallback.
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

    // MARK: - Helpers

    // Popular articles for each tag, merged and de-duplicated.
    private static func fetchDevToArticles(tags: [String]) async throws -> [DevToArticleResult] {
        var merged: [DevToArticleResult] = []
        var lastError: Error?

        for tag in tags {
            do {
                merged += try await DevToService.fetchArticles(tag: tag, maxResults: 20, topDays: 365)
            } catch {
                lastError = error
            }
        }

        if merged.isEmpty, let lastError { throw lastError }

        var seen = Set<Int>()
        return merged.filter { seen.insert($0.id).inserted }
    }

    // Sorts by keyword relevance (ties keep the source's own order) and drops
    // anything with no keyword match, keeping at least `keepAtLeast` items.
    private static func rank<T>(
        _ items: [T],
        keywords: [String],
        keepAtLeast: Int,
        text: (T) -> String
    ) -> [T] {
        guard !keywords.isEmpty else { return items }

        var scored: [Scored<T>] = []
        for (index, item) in items.enumerated() {
            let score = SearchPlanner.relevance(of: text(item), keywords: keywords)
            scored.append(Scored(index: index, item: item, score: score))
        }
        scored.sort { lhs, rhs in
            lhs.score == rhs.score ? lhs.index < rhs.index : lhs.score > rhs.score
        }

        let relevant = scored.filter { $0.score > 0 }
        let kept: [Scored<T>] = relevant.count >= keepAtLeast ? relevant : Array(scored.prefix(keepAtLeast))
        return kept.map { $0.item }
    }

    private struct Scored<T> {
        let index: Int
        let item: T
        let score: Int
    }

    private static func attempt<T>(_ work: () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await work())
        } catch {
            return .failure(error)
        }
    }
}
