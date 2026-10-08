//
//  RecommendationEngineTests.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 8/10/2026.
//

import Foundation
import Testing
import SwiftData
@testable import final_app

@MainActor
@Suite("Next Watch recommendations")
struct RecommendationEngineTests {

    @Test("A topic with a deadline tomorrow outranks one with no deadline")
    func deadlineProximityWins() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let urgent = makeTopic(in: context, title: "Urgent", subjectName: "FIT3178")
        addResource(to: urgent, in: context, title: "A", type: .video, minutes: 10)
        let deadline = Deadline(title: "Assignment", dueDate: .now.addingTimeInterval(24 * 60 * 60))
        deadline.subject = urgent.subject
        context.insert(deadline)

        let relaxed = makeTopic(in: context, title: "Relaxed", subjectName: "FIT2004")
        addResource(to: relaxed, in: context, title: "B", type: .video, minutes: 10)
        try context.save()

        let ranked = RecommendationEngine.rank(topics: [relaxed, urgent])

        #expect(ranked.first?.topic.id == urgent.id)
    }

    @Test("'Needs revision' outranks 'Understood' when deadlines are equal")
    func difficultyMatters() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let hard = makeTopic(in: context, title: "Hard")
        hard.difficulty = .needsRevision
        addResource(to: hard, in: context, title: "A", type: .video, minutes: 10)

        let easy = makeTopic(in: context, title: "Easy")
        easy.difficulty = .understood
        addResource(to: easy, in: context, title: "B", type: .video, minutes: 10)
        try context.save()

        let ranked = RecommendationEngine.rank(topics: [easy, hard])

        #expect(ranked.map(\.topic.title) == ["Hard", "Easy"])
    }

    @Test("Completed topics and topics with nothing left are not recommended")
    func finishedTopicsExcluded() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let done = makeTopic(in: context, title: "Done")
        let resource = addResource(to: done, in: context, title: "A", type: .video, minutes: 10)
        done.toggleCompletion(of: resource, modelContext: context)

        let empty = makeTopic(in: context, title: "Empty")
        try context.save()

        #expect(RecommendationEngine.rank(topics: [done, empty]).isEmpty)
    }
}
