//
//  WeeklyDigestService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 22/10/2026.
//

import Foundation
import SwiftData

// Weekly Digest engine (Season Pass). Once per week, on app launch, it picks
// the week's featured episodes from the signal pipeline and saves them as a
// WeeklyDigest. There's no server scheduler: the app simply checks whether a
// digest already exists for the current week.
@MainActor
enum WeeklyDigestService {

    static let maxEpisodes = 3

    // Monday 00:00 of the week containing `date`.
    static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        return mondayCalendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    // Returns this week's digest, creating it first if it doesn't exist yet.
    @discardableResult
    static func generateIfNeeded(
        topics: [Topic],
        existing: [WeeklyDigest],
        progress: [StudyProgress],
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WeeklyDigest {
        let start = weekStart(for: now, calendar: calendar)
        if let current = existing.first(where: { calendar.isDate($0.weekStart, inSameDayAs: start) }) {
            // An empty drop (e.g. made before the student's topics synced, or before
            // they added any) is refilled as soon as there's something to feature.
            if current.topicIDs.isEmpty {
                let refreshed = makeDigest(topics: topics, progress: progress, weekStart: start, calendar: calendar)
                if !refreshed.topicIDs.isEmpty {
                    current.topicIDs = refreshed.topicIDs
                    current.resourceIDs = refreshed.resourceIDs
                    current.headline = refreshed.headline
                    current.generatedAt = .now
                }
            }
            return current
        }

        let digest = makeDigest(topics: topics, progress: progress, weekStart: start, calendar: calendar)
        context.insert(digest)
        try? context.save()
        return digest
    }

    static func makeDigest(
        topics: [Topic],
        progress: [StudyProgress],
        weekStart: Date,
        calendar: Calendar = .current
    ) -> WeeklyDigest {
        let featured = featuredTopics(from: topics)
        let episodes = featured.compactMap { SignalPipeline.bestEpisode(for: $0) }

        // Last week's study time (ratings have 0 minutes, so they're skipped).
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let lastWeek = progress.filter { $0.date >= lastWeekStart && $0.date < weekStart && $0.minutesSpent > 0 }

        return WeeklyDigest(
            weekStart: weekStart,
            headline: headline(for: featured, isFirstWeek: progress.isEmpty),
            topicIDs: featured.map(\.id),
            resourceIDs: episodes.map(\.id),
            minutesLastWeek: lastWeek.reduce(0) { $0 + $1.minutesSpent },
            episodesLastWeek: lastWeek.count
        )
    }

    // The weighted score picks the topics. A new student with no resources yet
    // still gets a sensible drop: their soonest-deadline topics.
    static func featuredTopics(from topics: [Topic]) -> [Topic] {
        let ranked = RecommendationEngine.rank(topics: topics).map(\.topic)
        if !ranked.isEmpty {
            return Array(ranked.prefix(maxEpisodes))
        }

        return Array(
            topics
                .filter { !$0.isCompleted }
                .sorted { lhs, rhs in
                    let left = RecommendationEngine.deadlineProximityScore(for: lhs)
                    let right = RecommendationEngine.deadlineProximityScore(for: rhs)
                    return left == right ? lhs.createdAt < rhs.createdAt : left > right
                }
                .prefix(maxEpisodes)
        )
    }

    static func headline(for featured: [Topic], isFirstWeek: Bool) -> String {
        guard let top = featured.first else {
            return "Add a subject and topics to get your first weekly drop."
        }
        if isFirstWeek {
            return "Your first drop: start with \(top.title)."
        }
        if let deadline = nextDeadline(for: top), deadline.daysRemaining <= 7 {
            let when = deadline.daysRemaining <= 0 ? "today" : "in \(deadline.daysRemaining) day\(deadline.daysRemaining == 1 ? "" : "s")"
            return "\(deadline.title) is due \(when). Start with \(top.title)."
        }
        if SignalPipeline.difficultySignal(for: top) >= 0.6 {
            return "Time to revisit \(top.title), it's still marked for revision."
        }
        return "\(featured.count) episode\(featured.count == 1 ? "" : "s") picked for you this week."
    }

    private static func nextDeadline(for topic: Topic) -> Deadline? {
        topic.subject?.deadlines
            .filter { !$0.isOverdue }
            .min { $0.dueDate < $1.dueDate }
    }

    // MARK: - Reading a digest back

    static func topics(in digest: WeeklyDigest, from allTopics: [Topic]) -> [Topic] {
        digest.topicIDs.compactMap { id in allTopics.first { $0.id == id } }
    }

    static func episode(for topic: Topic, in digest: WeeklyDigest) -> LearningResource? {
        topic.resources.first { digest.resourceIDs.contains($0.id) }
    }
}
