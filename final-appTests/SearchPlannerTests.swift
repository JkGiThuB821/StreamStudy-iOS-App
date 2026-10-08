//
//  SearchPlannerTests.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 8/10/2026.
//

import Foundation
import Testing
import SwiftData
@testable import final_app

@MainActor
@Suite("Search planning & relevance (no AI)")
struct SearchPlannerTests {

    @Test("Topic description drives the search query and tags")
    func descriptionDrivesQuery() throws {
        let container = try makeTestContainer()
        let topic = makeTopic(
            in: container.mainContext,
            title: "Relationships",
            description: "Model a one-to-many relationship in SwiftData and query it with #Predicate"
        )

        let plan = SearchPlanner.localPlan(for: topic)
        let query = plan.youtubeQuery.lowercased()

        #expect(query.contains("relationships"))
        #expect(query.contains("swiftdata"))
        #expect(query.contains("predicate"))
        #expect(!query.contains("one"))           // filler words are not used
        #expect(plan.devToTags.contains("swiftdata"))
        #expect(plan.curatedTags.contains("swiftdata"))
        #expect(plan.keywords.contains("predicate"))
        #expect(plan.usedAI == false)
    }

    @Test("A title-only topic still produces a usable query")
    func titleOnly() throws {
        let container = try makeTestContainer()
        let topic = makeTopic(in: container.mainContext, title: "SwiftUI Navigation", description: "")

        let plan = SearchPlanner.localPlan(for: topic)

        #expect(plan.youtubeQuery.hasPrefix("SwiftUI Navigation"))
        #expect(!plan.devToTags.isEmpty)
        #expect(plan.keywords.contains("swiftui"))
    }

    @Test("Stop words, short words and numbers are ignored")
    func significantWords() {
        let words = SearchPlanner.significantWords(in: "How to use the 2026 API in an assignment")
        #expect(words == ["api"])
    }

    @Test("Relevance counts how many keywords a resource mentions")
    func relevanceScoring() {
        let keywords = ["swiftdata", "predicate", "relationship"]
        #expect(SearchPlanner.relevance(of: "SwiftData relationships explained", keywords: keywords) == 2)
        #expect(SearchPlanner.relevance(of: "Top 10 JavaScript tips", keywords: keywords) == 0)
        #expect(SearchPlanner.relevance(of: "anything", keywords: []) == 0)
    }

    @Test("Word stems are treated as the same term")
    func stems() {
        #expect(SearchPlanner.sharesStem("relationship", "relationships"))
        #expect(SearchPlanner.sharesStem("query", "querying"))
        #expect(!SearchPlanner.sharesStem("ios", "iosx"))   // too short to stem-match
    }
}
