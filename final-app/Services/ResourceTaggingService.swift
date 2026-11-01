//
//  ResourceTaggingService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 22/10/2026.
//

import Foundation

// AI-assisted tagging (Season Pass). Gives each resource a few topic tags and a
// 0...1 relevance score for its topic, so the Weekly Digest and Season Recap
// can feature well-matched episodes rather than just the next one due.
//
// It is a background enrichment step and never a dependency: callers don't
// wait on it, and if Gemini is unavailable, slow or returns bad data, resources
// are tagged from their own metadata instead.
@MainActor
enum ResourceTaggingService {

    enum TagSource: String {
        case gemini, metadata
    }

    // Tags every untagged resource in the topic, one Gemini call per topic.
    static func tagUntaggedResources(in topic: Topic) async {
        let untagged = topic.resources
            .filter { !$0.isTagged }
            .sorted { $0.addedAt < $1.addedAt }
        guard !untagged.isEmpty else { return }

        if GeminiService.isAvailable, let tags = try? await aiTags(for: topic, resources: untagged) {
            apply(tags, to: untagged, source: .gemini)
            // Any the model skipped still get metadata tags.
            tagFromMetadata(untagged.filter { !$0.isTagged }, topic: topic)
        } else {
            tagFromMetadata(untagged, topic: topic)
        }
    }

    // Catches up on resources added before tagging existed. Limited per launch
    // so it stays well inside the Gemini free-tier rate limits.
    static func backfill(topics: [Topic], maxTopics: Int = 5) async {
        let pending = topics.filter { topic in topic.resources.contains { !$0.isTagged } }
        for topic in pending.prefix(maxTopics) {
            await tagUntaggedResources(in: topic)
        }
    }

    // MARK: - Fallback: tags from metadata

    static func tagFromMetadata(_ resources: [LearningResource], topic: Topic) {
        let keywords = Array(
            (SearchPlanner.significantWords(in: topic.title)
                + SearchPlanner.significantWords(in: topic.topicDescription))
                .uniqued()
                .prefix(8)
        )

        for resource in resources {
            let text = "\(resource.title) \(resource.resourceDescription)"
            let words = SearchPlanner.significantWords(in: text).uniqued()
            let matching = keywords.filter { keyword in words.contains { SearchPlanner.sharesStem($0, keyword) } }

            resource.aiTags = Array((matching + words).uniqued().prefix(4))
            // A resource matching most of the topic's keywords scores close to 1.
            resource.relevanceScore = keywords.isEmpty
                ? 0.5
                : min(1, 0.3 + Double(matching.count) / Double(min(keywords.count, 3)) * 0.7)
            resource.tagSourceRaw = TagSource.metadata.rawValue
        }
    }

    // MARK: - Gemini

    struct AITagResponse: Decodable {
        let resources: [Item]

        struct Item: Decodable {
            let index: Int
            let tags: [String]
            let relevance: Double
        }
    }

    private static func aiTags(for topic: Topic, resources: [LearningResource]) async throws -> AITagResponse {
        let list = resources.enumerated().map { index, resource -> String in
            let description = resource.resourceDescription
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(200)
            return "[\(index)] \(resource.type.displayName) · \"\(resource.title)\" — \(description)"
        }
        .joined(separator: "\n")

        let prompt = """
        You tag study resources for a university student.

        Topic: \(topic.title)
        What the student needs to learn: \(topic.topicDescription.isEmpty ? "(not given)" : topic.topicDescription)
        Subject: \(topic.subject?.name ?? "Unknown")

        Resources (refer to them ONLY by their [index]):
        \(list)

        For EVERY resource return:
        - index: its number
        - tags: 2 to 4 short lowercase concept tags (1-2 words each) describing what it teaches
        - relevance: a number from 0 to 1 for how closely it matches what the student needs
          to learn (1 = exactly this topic, 0.5 = related background, 0 = off-topic)
        """

        return try await GeminiService.generateJSON(
            AITagResponse.self,
            prompt: prompt,
            schema: schema,
            temperature: 0.2
        )
    }

    private static let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "resources": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "index": ["type": "INTEGER"],
                        "tags": ["type": "ARRAY", "items": ["type": "STRING"]],
                        "relevance": ["type": "NUMBER"],
                    ],
                    "required": ["index", "tags", "relevance"],
                ],
            ],
        ],
        "required": ["resources"],
    ]

    // Validates the model's answer: unknown indexes are ignored, tags cleaned,
    // relevance clamped to 0...1.
    static func apply(_ response: AITagResponse, to resources: [LearningResource], source: TagSource) {
        for item in response.resources where resources.indices.contains(item.index) {
            let resource = resources[item.index]
            let tags = item.tags
                .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.replacingOccurrences(of: ",", with: " ") }
                .filter { !$0.isEmpty }
                .uniqued()

            resource.aiTags = Array(tags.prefix(4))
            resource.relevanceScore = min(max(item.relevance, 0), 1)
            resource.tagSourceRaw = source.rawValue
        }
    }
}
