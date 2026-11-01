//
//  SeasonRecapBuilder.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 22/10/2026.
//

import Foundation

// Everything the Season Recap shows for one subject, worked out up front so
// the view only has to present it.
nonisolated struct SeasonRecap: Identifiable {
    let id = UUID()

    struct WeekMinutes: Identifiable, Equatable {
        let weekStart: Date
        let minutes: Int
        var id: Date { weekStart }
    }

    let subjectName: String
    let colorHex: String
    let iconName: String
    let seasonStart: Date?

    let totalMinutes: Int
    let episodesCompleted: Int
    let totalEpisodes: Int
    let weeklyMinutes: [WeekMinutes]

    let ratingsCount: Int
    let understoodTopics: [String]
    let revisionTopics: [String]
    let turnedAroundTopics: [String]

    let dropsFeatured: Int
    let featuredEpisodesCompleted: Int
    let featuredEpisodesTotal: Int

    let themes: [String]

    let nextDeadlineTitle: String?
    let nextDeadlineDays: Int?
    let upNextTopics: [String]

    var biggestWeek: WeekMinutes? {
        weeklyMinutes.filter { $0.minutes > 0 }.max { $0.minutes < $1.minutes }
    }
}

@MainActor
enum SeasonRecapBuilder {

    static func build(
        for subject: Subject,
        digests: [WeeklyDigest],
        calendar: Calendar = .current
    ) -> SeasonRecap {
        let topics = subject.topics
        let resources = topics.flatMap(\.resources)
        let entries = topics.flatMap(\.progressEntries)
        let studySessions = entries.filter { $0.minutesSpent > 0 }

        // Study time per week, oldest first.
        var minutesByWeek: [Date: Int] = [:]
        for session in studySessions {
            minutesByWeek[WeeklyDigestService.weekStart(for: session.date, calendar: calendar), default: 0] += session.minutesSpent
        }
        let weekly = minutesByWeek
            .map { SeasonRecap.WeekMinutes(weekStart: $0.key, minutes: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }

        // Weekly drops that featured this subject.
        let topicIDs = Set(topics.map(\.id))
        let featuringDigests = digests.filter { digest in digest.topicIDs.contains { topicIDs.contains($0) } }
        let featuredResourceIDs = Set(featuringDigests.flatMap(\.resourceIDs))
        let featuredResources = resources.filter { featuredResourceIDs.contains($0.id) }

        // Most common tags across what the student actually finished (or
        // everything, if nothing is finished yet).
        let completed = resources.filter(\.isCompleted)
        var tagCounts: [String: Int] = [:]
        for resource in (completed.isEmpty ? resources : completed) {
            for tag in resource.aiTags { tagCounts[tag, default: 0] += 1 }
        }
        let themes = tagCounts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(6)
            .map(\.key)

        let nextDeadline = subject.deadlines
            .filter { !$0.isOverdue }
            .min { $0.dueDate < $1.dueDate }

        let upNext = RecommendationEngine.rank(topics: topics)
            .prefix(3)
            .map(\.topic.title)

        return SeasonRecap(
            subjectName: subject.name,
            colorHex: subject.colorHex,
            iconName: subject.iconName,
            seasonStart: entries.map(\.date).min(),
            totalMinutes: studySessions.reduce(0) { $0 + $1.minutesSpent },
            episodesCompleted: completed.count,
            totalEpisodes: resources.count,
            weeklyMinutes: weekly,
            ratingsCount: entries.filter(\.isRating).count,
            understoodTopics: topics.filter { $0.difficulty == .understood }.map(\.title),
            revisionTopics: topics.filter { $0.difficulty == .needsRevision }.map(\.title),
            turnedAroundTopics: topics.filter { SignalPipeline.wasTurnedAround($0) }.map(\.title),
            dropsFeatured: featuringDigests.count,
            featuredEpisodesCompleted: featuredResources.filter(\.isCompleted).count,
            featuredEpisodesTotal: featuredResources.count,
            themes: themes,
            nextDeadlineTitle: nextDeadline?.title,
            nextDeadlineDays: nextDeadline?.daysRemaining,
            upNextTopics: upNext
        )
    }
}
