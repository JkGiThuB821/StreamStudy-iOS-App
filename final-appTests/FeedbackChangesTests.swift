//
//  FeedbackChangesTests.swift
//  final-appTests
//
//  Regression tests for changes made in response to Week 11–12 demonstrator feedback.
//

import Foundation
import Testing
import SwiftData
@testable import final_app

@MainActor
@Suite("Week 11–12 feedback changes")
struct FeedbackChangesTests {

    @Test("Demo data loads every feature's sample content")
    func demoDataContents() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let added = DemoDataService.load(into: context)

        #expect(added == 2)
        let subjects = try context.fetch(FetchDescriptor<Subject>())
        let topics = subjects.flatMap(\.topics)
        #expect(topics.count == 5)
        #expect(topics.allSatisfy { $0.lessonPlan != nil })                     // lesson plans
        #expect(topics.flatMap(\.resources).allSatisfy(\.isTagged))             // tags
        #expect(topics.contains { SignalPipeline.wasTurnedAround($0) })        // rating history
        #expect(try context.fetch(FetchDescriptor<Deadline>()).allSatisfy { !$0.isOverdue })
        #expect(try context.fetch(FetchDescriptor<WeeklyDigest>()).count == 3)  // past drops
    }

    @Test("Loading demo data twice doesn't duplicate it")
    func demoDataIdempotent() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        DemoDataService.load(into: context)
        let secondTime = DemoDataService.load(into: context)

        #expect(secondTime == 0)
        #expect(try context.fetch(FetchDescriptor<Subject>()).count == 2)
    }

    @Test("Demo data gives the Season Recap a full story")
    func demoRecap() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        DemoDataService.load(into: context)

        let subject = try #require(try context.fetch(FetchDescriptor<Subject>()).first { $0.name == "iOS Development" })
        let recap = SeasonRecapBuilder.build(for: subject, digests: try context.fetch(FetchDescriptor<WeeklyDigest>()))

        #expect(recap.totalMinutes > 0)
        #expect(recap.dropsFeatured > 0)
        #expect(!recap.themes.isEmpty)
        #expect(RecapCard.cards(for: recap) == RecapCard.allCases)   // no card skipped
    }

    @Test("The onboarding record adds each account once")
    func onboardingRecord() {
        var list = ""
        list = UserPreferences.adding("abc", to: list)
        list = UserPreferences.adding("abc", to: list)
        list = UserPreferences.adding("xyz", to: list)

        #expect(list == "abc,xyz")
        #expect(UserPreferences.hasOnboarded("xyz", in: list))
        #expect(!UserPreferences.hasOnboarded("ab", in: list))
    }

    @Test("Blank text is rejected by validation")
    func blankText() {
        #expect("   \n ".isBlank)
        #expect(!" Quiz 4 ".isBlank)
    }
}
