//
//  SeasonPassTests.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 2/11/2026.
//


//
//  SeasonPassTests.swift
//  final-appTests
//
//  The Season Pass is one system (swipe -> signal pipeline -> digest -> recap),
//  so these tests check the pieces AND that they feed each other correctly.
//

import Foundation
import Testing
import SwiftData
@testable import final_app

@MainActor
@Suite("Season Pass")
struct SeasonPassTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    // MARK: - Signal pipeline + Swipe-to-Revise

    @Test("A swipe records a 0-minute rating and updates the topic")
    func swipeRecordsRating() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context)

        SignalPipeline.recordRating(.needsRevision, for: topic, source: .episode, in: context)
        try context.save()

        #expect(topic.difficulty == .needsRevision)
        let entry = try #require(topic.progressEntries.first)
        #expect(entry.isRating)
        #expect(entry.minutesSpent == 0)          // doesn't inflate study-time charts
        #expect(entry.ratingSource == .episode)
    }

    @Test("Confidence weights recent ratings most")
    func confidenceDecay() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context)

        #expect(SignalPipeline.confidence(for: topic) == nil)

        SignalPipeline.recordRating(.needsRevision, for: topic, source: .episode, in: context, at: date("2026-10-01T10:00:00Z"))
        SignalPipeline.recordRating(.understood, for: topic, source: .digest, in: context, at: date("2026-10-08T10:00:00Z"))
        try context.save()

        // Newest (understood) weight 1, older (needs revision) weight 0.6: 1 / 1.6
        let confidence = try #require(SignalPipeline.confidence(for: topic))
        #expect(abs(confidence - 0.625) < 0.0001)
        #expect(SignalPipeline.wasTurnedAround(topic))
    }

    @Test("Swipe ratings change what Home recommends")
    func ratingsFeedRanking() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let shaky = makeTopic(in: context, title: "Shaky")
        let solid = makeTopic(in: context, title: "Solid")
        addResource(to: shaky, in: context, title: "A", type: .video, minutes: 10)
        addResource(to: solid, in: context, title: "B", type: .video, minutes: 10)

        SignalPipeline.recordRating(.understood, for: solid, source: .episode, in: context)
        SignalPipeline.recordRating(.needsRevision, for: shaky, source: .digest, in: context)
        try context.save()

        #expect(RecommendationEngine.rank(topics: [solid, shaky]).first?.topic.title == "Shaky")
    }

    @Test("Off-topic resources aren't featured while a relevant one is left")
    func bestEpisodeUsesRelevance() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context)
        let offTopic = addResource(to: topic, in: context, title: "Off topic", type: .video, minutes: 2)
        let relevant = addResource(to: topic, in: context, title: "Relevant", type: .video, minutes: 20)
        offTopic.relevanceScore = 0.1
        relevant.relevanceScore = 0.9
        try context.save()

        #expect(SignalPipeline.bestEpisode(for: topic)?.id == relevant.id)
    }

    // MARK: - AI-assisted tagging

    @Test("Metadata fallback tags and scores resources without AI")
    func metadataFallback() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context, title: "SwiftData Relationships", description: "one-to-many relationships with predicates")
        let match = addResource(to: topic, in: context, title: "SwiftData relationships and predicates", type: .video, minutes: 10)
        let other = addResource(to: topic, in: context, title: "Cooking pasta at home", type: .video, minutes: 10)

        ResourceTaggingService.tagFromMetadata([match, other], topic: topic)

        #expect(match.tagSourceRaw == "metadata")
        #expect(!match.aiTags.isEmpty)
        #expect((match.relevanceScore ?? 0) > (other.relevanceScore ?? 1))
    }

    @Test("Bad AI output is validated: unknown indexes ignored, relevance clamped")
    func aiResponseValidation() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context)
        let resource = addResource(to: topic, in: context, title: "Video", type: .video, minutes: 10)

        let json = """
        { "resources": [
            { "index": 0, "tags": [" SwiftData ", "swiftdata", "a,b"], "relevance": 1.7 },
            { "index": 9, "tags": ["ghost"], "relevance": 0.5 }
        ] }
        """
        let response = try JSONDecoder().decode(ResourceTaggingService.AITagResponse.self, from: json.utf8Data)
        ResourceTaggingService.apply(response, to: [resource], source: .gemini)

        #expect(resource.relevanceScore == 1)              // clamped from 1.7
        #expect(resource.aiTags == ["swiftdata", "a b"])   // trimmed, de-duplicated, no commas
        #expect(resource.tagSourceRaw == "gemini")
    }

    // MARK: - Weekly Digest

    @Test("Weeks start on Monday")
    func weekStartsMonday() {
        let wednesday = date("2026-10-21T15:00:00Z")
        #expect(WeeklyDigestService.weekStart(for: wednesday, calendar: calendar) == date("2026-10-19T00:00:00Z"))
    }

    @Test("One digest per week, and a new one when the week changes")
    func digestOncePerWeek() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context)
        addResource(to: topic, in: context, title: "A", type: .video, minutes: 10)
        try context.save()

        let first = WeeklyDigestService.generateIfNeeded(
            topics: [topic], existing: [], progress: [], context: context,
            now: date("2026-10-20T09:00:00Z"), calendar: calendar
        )
        let sameWeek = WeeklyDigestService.generateIfNeeded(
            topics: [topic], existing: [first], progress: [], context: context,
            now: date("2026-10-24T09:00:00Z"), calendar: calendar
        )
        let nextWeek = WeeklyDigestService.generateIfNeeded(
            topics: [topic], existing: [first], progress: [], context: context,
            now: date("2026-10-27T09:00:00Z"), calendar: calendar
        )

        #expect(sameWeek.id == first.id)
        #expect(nextWeek.id != first.id)
        #expect(first.topicIDs == [topic.id])
        #expect(try context.fetch(FetchDescriptor<WeeklyDigest>()).count == 2)
    }

    @Test("A new student still gets a drop: soonest-deadline topics")
    func newStudentDefault() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let later = makeTopic(in: context, title: "Later", subjectName: "A")
        let urgent = makeTopic(in: context, title: "Urgent", subjectName: "B")
        let deadline = Deadline(title: "Quiz", dueDate: .now.addingTimeInterval(2 * 24 * 60 * 60))
        deadline.subject = urgent.subject
        context.insert(deadline)
        try context.save()

        // Neither topic has resources yet, so the ranked list is empty.
        let featured = WeeklyDigestService.featuredTopics(from: [later, urgent])
        #expect(featured.first?.title == "Urgent")
    }

    @Test("An empty digest is refilled once there's something to feature")
    func emptyDigestRefills() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let now = date("2026-10-20T09:00:00Z")

        let empty = WeeklyDigestService.generateIfNeeded(
            topics: [], existing: [], progress: [], context: context, now: now, calendar: calendar
        )
        #expect(empty.topicIDs.isEmpty)

        let topic = makeTopic(in: context)
        try context.save()
        let refilled = WeeklyDigestService.generateIfNeeded(
            topics: [topic], existing: [empty], progress: [], context: context, now: now, calendar: calendar
        )
        #expect(refilled.id == empty.id)
        #expect(refilled.topicIDs == [topic.id])
    }

    @Test("The digest deep link opens the digest")
    func digestDeepLink() {
        let router = DeepLinkRouter()
        router.handle(url: URL(string: "streamstudy://digest")!)
        #expect(router.destination == .digest)
    }

    // MARK: - Season Recap (end to end)

    @Test("The recap combines study time, swipes, drops and tags")
    func recapEndToEnd() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context, title: "Closures")
        let subject = try #require(topic.subject)
        let video = addResource(to: topic, in: context, title: "Closures explained", type: .video, minutes: 20)
        video.aiTags = ["closures", "capture lists"]
        try context.save()

        // Study, rate twice (turned around), and appear in one weekly drop.
        topic.toggleCompletion(of: video, modelContext: context)
        SignalPipeline.recordRating(.needsRevision, for: topic, source: .episode, in: context, at: .now.addingTimeInterval(-3600))
        SignalPipeline.recordRating(.understood, for: topic, source: .digest, in: context)
        let digest = WeeklyDigest(
            weekStart: WeeklyDigestService.weekStart(for: .now), headline: "",
            topicIDs: [topic.id], resourceIDs: [video.id], minutesLastWeek: 0, episodesLastWeek: 0
        )
        context.insert(digest)
        try context.save()

        let recap = SeasonRecapBuilder.build(for: subject, digests: [digest])

        #expect(recap.totalMinutes == 20)              // ratings add no minutes
        #expect(recap.episodesCompleted == 1)
        #expect(recap.ratingsCount == 2)
        #expect(recap.turnedAroundTopics == ["Closures"])
        #expect(recap.dropsFeatured == 1)
        #expect(recap.featuredEpisodesCompleted == 1)
        #expect(recap.themes.contains("closures"))
        #expect(RecapCard.cards(for: recap).contains(.drops))
    }

    @Test("A brand-new subject's recap skips empty cards instead of looking broken")
    func emptyRecap() throws {
        let container = try makeTestContainer()
        let topic = makeTopic(in: container.mainContext)
        let subject = try #require(topic.subject)

        let recap = SeasonRecapBuilder.build(for: subject, digests: [])

        #expect(RecapCard.cards(for: recap) == [.intro, .watchTime, .understanding, .finale])
    }
}
