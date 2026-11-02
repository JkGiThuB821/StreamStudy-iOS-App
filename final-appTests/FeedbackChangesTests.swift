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
        let deadlines = try context.fetch(FetchDescriptor<Deadline>())
        let digests = try context.fetch(FetchDescriptor<WeeklyDigest>())

        // Worked out before #expect: closures passed to allSatisfy/contains inside
        // #expect are treated as throwing by Xcode 26 and don't compile.
        let allHavePlans = topics.allSatisfy { $0.lessonPlan != nil }
        let allTagged = topics.flatMap(\.resources).allSatisfy(\.isTagged)
        let hasTurnaround = topics.contains { SignalPipeline.wasTurnedAround($0) }
        let noneOverdue = deadlines.allSatisfy { !$0.isOverdue }

        #expect(topics.count == 5)
        #expect(allHavePlans)                                                   // lesson plans
        #expect(allTagged)                                                      // tags
        #expect(hasTurnaround)                                                  // rating history
        #expect(noneOverdue)
        #expect(digests.count == 3)                                             // past drops
    }

    @Test("Loading demo data twice doesn't duplicate it")
    func demoDataIdempotent() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        DemoDataService.load(into: context)
        let secondTime = DemoDataService.load(into: context)

        #expect(secondTime == 0)
        let subjects = try context.fetch(FetchDescriptor<Subject>())
        #expect(subjects.count == 2)
    }

    @Test("Demo data fills an empty subject of the same name (e.g. picked in onboarding)")
    func demoDataFillsOnboardingSubject() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        // Onboarding suggests "iOS Development", so a new account may already have it, empty.
        context.insert(Subject(name: "iOS Development"))
        try context.save()

        let added = DemoDataService.load(into: context)

        #expect(added == 2)
        let subjects = try context.fetch(FetchDescriptor<Subject>())
        let iosTopicCount = subjects.first { $0.name == "iOS Development" }?.topics.count
        #expect(subjects.count == 2)                                            // no duplicate
        #expect(iosTopicCount == 3)
    }

    @Test("Demo data gives the Season Recap a full story")
    func demoRecap() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        DemoDataService.load(into: context)

        let subjects = try context.fetch(FetchDescriptor<Subject>())
        let iosSubject = subjects.first { $0.name == "iOS Development" }
        let subject = try #require(iosSubject)
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
