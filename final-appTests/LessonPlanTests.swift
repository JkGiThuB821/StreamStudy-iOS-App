//
//  LessonPlanTests.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 8/10/2026.
//

import Foundation
import Testing
import SwiftData
@testable import final_app

@MainActor
@Suite("Lesson plans")
struct LessonPlanTests {

    @Test("On-device plan mixes reading and video, then practice and review")
    func localPlanStructure() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context, description: "Assignment 2: one-to-many relationships")
        let doc = addResource(to: topic, in: context, title: "Docs", type: .documentation, minutes: 20)
        let article = addResource(to: topic, in: context, title: "Article", type: .article, minutes: 5)
        let video1 = addResource(to: topic, in: context, title: "Video 1", type: .video, minutes: 12)
        let video2 = addResource(to: topic, in: context, title: "Video 2", type: .video, minutes: 8)

        let plan = LessonPlanService.localPlan(for: topic, resources: [doc, article, video1, video2])

        #expect(plan.source == .local)
        #expect(plan.steps.map(\.kind) == [.read, .watch, .read, .watch, .practice, .review])
        #expect(plan.steps[0].resourceIDs == [doc.id])
        #expect(plan.steps[1].resourceIDs == [video1.id])
        #expect(plan.steps.last?.resourceIDs.isEmpty == true)
        #expect(plan.steps[4].activity.contains("Assignment 2"))   // practice uses the description
        #expect(plan.steps[0].estimatedMinutes == 20)
    }

    @Test("A topic with no resources still gets practice and review steps")
    func localPlanWithoutResources() throws {
        let container = try makeTestContainer()
        let topic = makeTopic(in: container.mainContext)

        let plan = LessonPlanService.localPlan(for: topic, resources: [])

        #expect(plan.steps.map(\.kind) == [.practice, .review])
    }

    @Test("Malformed AI JSON is validated before it's used")
    func aiPlanValidation() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context)
        let doc = addResource(to: topic, in: context, title: "Docs", type: .documentation, minutes: 20)
        let video = addResource(to: topic, in: context, title: "Video", type: .video, minutes: 12)

        // Index 7 doesn't exist, index 0 is used twice, step 2 has only invalid
        // indexes and no activity, and the times are wrong.
        let json = """
        {
          "summary": "Plan",
          "steps": [
            { "title": "Read", "objective": "o", "kind": "read", "resourceIndexes": [0, 7],
              "estimatedMinutes": 999, "activity": "", "checkpointQuestion": "q" },
            { "title": "Bad", "objective": "o", "kind": "watch", "resourceIndexes": [42],
              "estimatedMinutes": 5, "activity": "", "checkpointQuestion": "q" },
            { "title": "Watch", "objective": "o", "kind": "WATCH", "resourceIndexes": [0, 1],
              "estimatedMinutes": 1, "activity": "", "checkpointQuestion": "q" },
            { "title": "Practice", "objective": "o", "kind": "nonsense", "resourceIndexes": [],
              "estimatedMinutes": 500, "activity": "Build it", "checkpointQuestion": "q" }
          ]
        }
        """
        let ai = try JSONDecoder().decode(LessonPlanService.AILessonPlan.self, from: json.utf8Data)

        let plan = LessonPlanService.convert(ai, resources: [doc, video])

        #expect(plan.source == .gemini)
        #expect(plan.steps.map(\.title) == ["Read", "Watch", "Practice"])   // "Bad" dropped
        #expect(plan.steps[0].resourceIDs == [doc.id])                        // 7 removed
        #expect(plan.steps[0].estimatedMinutes == 20)                         // real duration, not 999
        #expect(plan.steps[1].resourceIDs == [video.id])                      // duplicate 0 removed
        #expect(plan.steps[1].kind == .watch)                                 // case-insensitive
        #expect(plan.steps[2].kind == .practice)                              // unknown kind -> practice
        #expect(plan.steps[2].estimatedMinutes == 90)                         // clamped
    }

    @Test("Plan survives a save/load round trip and tracks step progress")
    func planStorageAndProgress() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context)
        let longDoc = addResource(to: topic, in: context, title: "Long docs", type: .documentation, minutes: 30)
        let shortVideo = addResource(to: topic, in: context, title: "Short video", type: .video, minutes: 3)

        topic.lessonPlan = LessonPlanService.localPlan(for: topic, resources: [longDoc, shortVideo])
        try context.save()

        let stored = try #require(topic.lessonPlan)
        #expect(stored.steps.count == 4)   // read, watch, practice, review

        // Follows the plan order (docs first), not "shortest resource first".
        #expect(topic.nextPlannedResource?.id == longDoc.id)
        #expect(topic.nextLessonStep?.id == stored.steps[0].id)

        topic.toggleCompletion(of: longDoc, modelContext: context)
        #expect(topic.isStepCompleted(stored.steps[0]))
        #expect(topic.nextLessonStep?.id == stored.steps[1].id)

        // Practice steps have no resources, so they're ticked off manually.
        let practice = stored.steps[2]
        #expect(!topic.isStepCompleted(practice))
        topic.toggleManualCompletion(of: practice)
        let updatedPractice = try #require(topic.lessonPlan?.steps[2])
        #expect(topic.isStepCompleted(updatedPractice))
    }

    @Test("Completing a resource logs study time; undoing removes it")
    func studyTimeLogging() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let topic = makeTopic(in: context)
        let resource = addResource(to: topic, in: context, title: "Video", type: .video, minutes: 15)
        try context.save()

        topic.toggleCompletion(of: resource, modelContext: context)
        try context.save()
        #expect(topic.progressEntries.map(\.minutesSpent) == [15])
        #expect(topic.isCompleted)

        topic.toggleCompletion(of: resource, modelContext: context)
        try context.save()
        let remaining = try context.fetch(FetchDescriptor<StudyProgress>())
        #expect(remaining.isEmpty)
        #expect(!topic.isCompleted)
    }
}
