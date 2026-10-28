//
//  DemoDataService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/10/2026.
//

import Foundation
import SwiftData

// Week 12 feedback: realistic sample data that shows every feature during a
// demo: subjects, topics with descriptions, real learning resources, study
// history over the past month, Swipe-to-Revise ratings, lesson plans,
// upcoming deadlines and past weekly drops (so the Season Recap has a story).
//
// Best loaded on a separate demo account. Subjects that already exist (by
// name) are skipped, so loading twice doesn't duplicate anything.
enum DemoDataService {

    private struct DemoResource {
        let title: String
        let url: String
        let source: String
        let type: ResourceType
        let minutes: Int
        let completedWeeksAgo: Int?   // nil = not finished yet
    }

    private struct DemoTopic {
        let title: String
        let description: String
        let resources: [DemoResource]
        // Swipe ratings, oldest first: (weeks ago, rating)
        let ratings: [(Int, DifficultyRating)]
    }

    private struct DemoSubject {
        let name: String
        let description: String
        let icon: String
        let colorHex: String
        let topics: [DemoTopic]
        let deadlines: [(title: String, daysFromNow: Int, priority: DeadlinePriority)]
    }

    private static let subjects: [DemoSubject] = [
        DemoSubject(
            name: "iOS Development",
            description: "Swift, SwiftUI and building apps",
            icon: "iphone",
            colorHex: "#E50914",
            topics: [
                DemoTopic(
                    title: "SwiftUI Layout",
                    description: "Stacks, spacers and adaptive layouts that work with Dynamic Type and rotation",
                    resources: [
                        DemoResource(title: "Introducing SwiftUI", url: "https://developer.apple.com/tutorials/swiftui", source: "Apple Developer", type: .documentation, minutes: 25, completedWeeksAgo: 3),
                        DemoResource(title: "100 Days of SwiftUI", url: "https://www.hackingwithswift.com/100/swiftui", source: "Hacking with Swift", type: .article, minutes: 20, completedWeeksAgo: 2),
                    ],
                    ratings: [(3, .needsRevision), (1, .understood)]
                ),
                DemoTopic(
                    title: "SwiftData Relationships",
                    description: "Assignment 2: model a one-to-many relationship in SwiftData and query it with #Predicate",
                    resources: [
                        DemoResource(title: "SwiftData documentation", url: "https://developer.apple.com/documentation/swiftdata", source: "Apple Developer", type: .documentation, minutes: 20, completedWeeksAgo: 1),
                        DemoResource(title: "SwiftData by Example", url: "https://www.hackingwithswift.com/quick-start/swiftdata", source: "Hacking with Swift", type: .article, minutes: 15, completedWeeksAgo: nil),
                    ],
                    ratings: [(1, .needsRevision)]
                ),
                DemoTopic(
                    title: "Swift Concurrency",
                    description: "async/await, actors and how Swift prevents data races",
                    resources: [
                        DemoResource(title: "Concurrency: The Swift Programming Language", url: "https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/", source: "Swift.org", type: .documentation, minutes: 25, completedWeeksAgo: nil),
                        DemoResource(title: "Swift by Sundell", url: "https://www.swiftbysundell.com/", source: "Swift by Sundell", type: .article, minutes: 15, completedWeeksAgo: nil),
                    ],
                    ratings: []
                ),
            ],
            deadlines: [
                ("Assignment 3: Final App", 5, .high),
                ("Quiz 4", 12, .medium),
            ]
        ),
        DemoSubject(
            name: "Algorithms & Data Structures",
            description: "Big O, sorting, trees and graphs",
            icon: "cpu",
            colorHex: "#3498DB",
            topics: [
                DemoTopic(
                    title: "Big O Notation",
                    description: "Compare the time and space efficiency of algorithms for the exam",
                    resources: [
                        DemoResource(title: "Big O Notation Explained", url: "https://www.freecodecamp.org/news/big-o-notation-why-it-matters-and-why-it-doesnt-1674cfa8a23c/", source: "freeCodeCamp", type: .article, minutes: 12, completedWeeksAgo: 2),
                    ],
                    ratings: [(2, .understood)]
                ),
                DemoTopic(
                    title: "Sorting Algorithms",
                    description: "Merge sort and quicksort: how they work and their time complexity",
                    resources: [
                        DemoResource(title: "Merge sort", url: "https://en.wikipedia.org/wiki/Merge_sort", source: "Wikipedia", type: .article, minutes: 15, completedWeeksAgo: 0),
                        DemoResource(title: "Quicksort", url: "https://en.wikipedia.org/wiki/Quicksort", source: "Wikipedia", type: .article, minutes: 15, completedWeeksAgo: nil),
                    ],
                    ratings: [(0, .needsRevision)]
                ),
            ],
            deadlines: [
                ("Mid-semester Exam", 9, .high),
            ]
        ),
    ]

    // Returns how many subjects were added (0 if they all existed already).
    @discardableResult
    static func load(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> Int {
        let existingNames = Set(((try? context.fetch(FetchDescriptor<Subject>())) ?? []).map { $0.name.lowercased() })
        var addedTopics: [Topic] = []
        var addedCount = 0

        for demo in subjects where !existingNames.contains(demo.name.lowercased()) {
            let subject = Subject(name: demo.name, subjectDescription: demo.description, colorHex: demo.colorHex, iconName: demo.icon)
            context.insert(subject)
            addedCount += 1

            for (index, demoTopic) in demo.topics.enumerated() {
                let topic = Topic(title: demoTopic.title, topicDescription: demoTopic.description, orderIndex: index)
                topic.subject = subject
                topic.hasSearchedForResources = true
                context.insert(topic)

                var resources: [LearningResource] = []
                for (position, item) in demoTopic.resources.enumerated() {
                    let resource = LearningResource(
                        title: item.title, urlString: item.url, sourceName: item.source,
                        type: item.type, durationMinutes: item.minutes
                    )
                    // Keep the listed order stable.
                    resource.addedAt = now.addingTimeInterval(TimeInterval(-40 * 24 * 3600 + position))
                    resource.topic = topic
                    context.insert(resource)
                    resources.append(resource)

                    if let weeksAgo = item.completedWeeksAgo {
                        resource.isCompleted = true
                        let session = StudyProgress(date: date(weeksAgo: weeksAgo, now: now, calendar: calendar), minutesSpent: item.minutes)
                        session.topic = topic
                        context.insert(session)
                    }
                }
                topic.isCompleted = !resources.isEmpty && resources.allSatisfy(\.isCompleted)

                for (weeksAgo, rating) in demoTopic.ratings {
                    SignalPipeline.recordRating(
                        rating, for: topic, source: .episode, in: context,
                        at: date(weeksAgo: weeksAgo, now: now, calendar: calendar)
                    )
                }

                ResourceTaggingService.tagFromMetadata(resources, topic: topic)
                topic.lessonPlan = LessonPlanService.localPlan(for: topic, resources: resources)
                addedTopics.append(topic)
            }

            for deadline in demo.deadlines {
                let item = Deadline(
                    title: deadline.title,
                    dueDate: calendar.date(byAdding: .day, value: deadline.daysFromNow, to: now) ?? now,
                    priority: deadline.priority
                )
                item.subject = subject
                context.insert(item)
            }
        }

        if !addedTopics.isEmpty {
            addPastWeeklyDrops(for: addedTopics, into: context, now: now, calendar: calendar)
        }
        try? context.save()
        return addedCount
    }

    // Three past weekly drops, so the Season Recap has a history to look back on.
    private static func addPastWeeklyDrops(for topics: [Topic], into context: ModelContext, now: Date, calendar: Calendar) {
        let existingWeeks = ((try? context.fetch(FetchDescriptor<WeeklyDigest>())) ?? []).map(\.weekStart)
        let thisWeek = WeeklyDigestService.weekStart(for: now, calendar: calendar)

        for weeksAgo in 1...3 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeek),
                  !existingWeeks.contains(where: { calendar.isDate($0, inSameDayAs: weekStart) })
            else { continue }

            // Rotate through the topics so each drop features a different mix.
            let featured = (0..<min(3, topics.count)).map { topics[($0 + weeksAgo) % topics.count] }
            let episodes = featured.compactMap { $0.resources.min { $0.addedAt < $1.addedAt } }

            context.insert(WeeklyDigest(
                weekStart: weekStart,
                headline: "\(featured.count) episodes picked for you this week.",
                topicIDs: featured.map(\.id),
                resourceIDs: episodes.map(\.id),
                minutesLastWeek: [25, 32, 20][weeksAgo - 1],
                episodesLastWeek: [1, 2, 1][weeksAgo - 1]
            ))
        }
    }

    // A weekday afternoon in the given past week.
    private static func date(weeksAgo: Int, now: Date, calendar: Calendar) -> Date {
        let base = calendar.date(byAdding: .day, value: -7 * weeksAgo - 1, to: now) ?? now
        return calendar.date(bySettingHour: 16, minute: 0, second: 0, of: base) ?? base
    }
}
