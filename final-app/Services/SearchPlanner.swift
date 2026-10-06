//
//  SearchPlanner.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 6/10/2026.
//

import Foundation

// What to search for, built from the topic's title, description and subject.
struct SearchPlan {
    var youtubeQuery: String
    var devToTags: [String]
    var curatedTags: [String]
    // Important terms used to score how relevant each fetched resource is.
    var keywords: [String]
    var usedAI: Bool
}

enum SearchPlanner {

    // MARK: - Plan

    // Uses Gemini when a key is configured, otherwise (or if the call fails)
    // falls back to on-device keyword extraction.
    static func plan(for topic: Topic) async -> (plan: SearchPlan, warning: String?) {
        let local = localPlan(for: topic)
        guard GeminiService.isConfigured else { return (local, nil) }

        do {
            let ai = try await GeminiService.generateJSON(
                AISearchPlan.self,
                prompt: prompt(for: topic),
                schema: schema,
                temperature: 0.2
            )
            return (merge(ai: ai, local: local, topic: topic), nil)
        } catch {
            return (local, "AI search planning unavailable, used keyword search instead. (\(error.localizedDescription))")
        }
    }

    // MARK: - Relevance

    // Number of keywords that appear in the text. Higher = more relevant.
    nonisolated static func relevance(of text: String, keywords: [String]) -> Int {
        let haystack = text.lowercased()
        return keywords.reduce(0) { score, keyword in
            haystack.contains(keyword.lowercased()) ? score + 1 : score
        }
    }

    // MARK: - Local (no AI) planning

    static func localPlan(for topic: Topic) -> SearchPlan {
        let titleWords = significantWords(in: topic.title)
        let descriptionWords = significantWords(in: topic.topicDescription)
        let subjectWords = significantWords(in: topic.subject?.name ?? "")

        // Title words count double; description words add the detail.
        var frequency: [String: Int] = [:]
        titleWords.forEach { frequency[$0, default: 0] += 2 }
        descriptionWords.forEach { frequency[$0, default: 0] += 1 }

        let keywords = frequency
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(8)
            .map(\.key)

        // Title + the most useful description terms + subject context.
        let extraDetail: [String] = Array(
            descriptionWords
                .filter { !titleWords.contains($0) }
                .uniqued()
                .prefix(3)
        )
        let subjectContext: [String] = Array(
            subjectWords
                .filter { !titleWords.contains($0) && !extraDetail.contains($0) }
                .prefix(1)
        )
        let queryParts: [String] = [topic.title] + extraDetail + subjectContext + ["tutorial"]
        let youtubeQuery = queryParts.joined(separator: " ")

        let tag = ResourceDiscoveryService.tag(for: topic)
        let candidateTags = ([tag] + keywords + subjectWords)
            .map(normalisedTag)
            .filter { !$0.isEmpty }
            .uniqued()

        return SearchPlan(
            youtubeQuery: youtubeQuery,
            devToTags: Array(candidateTags.prefix(3)),
            curatedTags: candidateTags.filter { CuratedResourceManifest.knownTags.contains($0) },
            keywords: keywords,
            usedAI: false
        )
    }

    nonisolated private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "into", "how", "what", "why",
        "when", "are", "was", "were", "will", "can", "use", "using", "used", "about", "your",
        "you", "our", "their", "its", "it's", "has", "have", "had", "not", "but", "all", "any",
        "need", "needs", "learn", "learning", "understand", "know", "able", "also", "more",
        "some", "such", "than", "then", "them", "they", "which", "who", "week", "lecture",
        "lab", "tutorial", "assignment", "assessment", "topic", "unit", "intro", "introduction",
        "basics", "part", "via", "each", "between", "make", "build", "building", "create",
    ]

    nonisolated static func significantWords(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) && !$0.allSatisfy(\.isNumber) }
    }

    nonisolated private static func normalisedTag(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - Gemini

    private struct AISearchPlan: Decodable {
        let youtubeQuery: String
        let devToTags: [String]
        let curatedTags: [String]
        let keywords: [String]
    }

    private static func merge(ai: AISearchPlan, local: SearchPlan, topic: Topic) -> SearchPlan {
        let query = ai.youtubeQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        // Keep the student's own search tag first if they set one.
        var tags = ai.devToTags.map(normalisedTag).filter { !$0.isEmpty }
        if !topic.searchTag.trimmingCharacters(in: .whitespaces).isEmpty {
            tags.insert(normalisedTag(topic.searchTag), at: 0)
        }

        let curated = (ai.curatedTags + tags)
            .map(normalisedTag)
            .filter { CuratedResourceManifest.knownTags.contains($0) }

        let keywords = (ai.keywords.map { $0.lowercased() } + local.keywords).uniqued()

        return SearchPlan(
            youtubeQuery: query.isEmpty ? local.youtubeQuery : query,
            devToTags: Array(tags.uniqued().prefix(3)),
            curatedTags: curated.uniqued(),
            keywords: Array(keywords.prefix(10)),
            usedAI: true
        )
    }

    private static func prompt(for topic: Topic) -> String {
        """
        You help a university student find learning resources for one study topic.

        Subject: \(topic.subject?.name ?? "Unknown")
        Subject description: \(topic.subject?.subjectDescription ?? "")
        Topic title: \(topic.title)
        Topic description (what the student needs to learn or do): \(topic.topicDescription.isEmpty ? "(none given)" : topic.topicDescription)
        Student's own search tag: \(topic.searchTag.isEmpty ? "(none)" : topic.searchTag)

        Return JSON with:
        - youtubeQuery: one specific YouTube search query (max 10 words) that would find a clear
          educational video covering exactly what the description asks for. Include the technology
          or language name so results aren't ambiguous.
        - devToTags: 1 to 3 existing, popular dev.to tags (lowercase, letters/numbers only, no spaces)
          most relevant to this topic, most specific first.
        - curatedTags: any of these known tags that fit the topic: \(CuratedResourceManifest.knownTags.sorted().joined(separator: ", ")). Empty if none fit.
        - keywords: 4 to 8 short lowercase terms (1-2 words each) that a relevant resource's
          title or description would contain. Use specific concepts from the description.
        """
    }

    private static let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "youtubeQuery": ["type": "STRING"],
            "devToTags": ["type": "ARRAY", "items": ["type": "STRING"]],
            "curatedTags": ["type": "ARRAY", "items": ["type": "STRING"]],
            "keywords": ["type": "ARRAY", "items": ["type": "STRING"]],
        ],
        "required": ["youtubeQuery", "devToTags", "curatedTags", "keywords"],
    ]
}

extension Sequence where Element: Hashable {
    // Removes duplicates while keeping the original order.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
