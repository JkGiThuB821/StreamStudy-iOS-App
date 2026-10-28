//
//  SignalPipeline.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 22/10/2026.
//

import Foundation
import SwiftData

// The Season Pass "signal pipeline": the one shared layer that Swipe-to-Revise
// writes into, and that Home, the Weekly Digest and the Season Recap all read
// from. Ratings, AI relevance tags and progress/deadline data all meet here,
// then feed the existing weighted score in RecommendationEngine.
enum SignalPipeline {

    // Resources the AI (or fallback) judged below this aren't featured, unless
    // nothing better is left for that topic.
    static let relevanceThreshold = 0.35

    // How much each older rating counts compared with the one after it.
    static let ratingDecay = 0.6

    // MARK: - Write

    // Records a Swipe-to-Revise rating. Also updates the topic's current rating
    // so every screen that shows it stays in step.
    static func recordRating(
        _ rating: DifficultyRating,
        for topic: Topic,
        resource: LearningResource? = nil,
        source: RatingSource,
        in context: ModelContext,
        at date: Date = .now
    ) {
        guard rating != .notRated else { return }

        let entry = StudyProgress(date: date, minutesSpent: 0)
        entry.understandingRaw = rating.rawValue
        entry.ratingSourceRaw = source.rawValue
        entry.resourceID = resource?.id
        entry.topic = topic
        context.insert(entry)

        topic.difficulty = rating
    }

    // MARK: - Read

    // All ratings for a topic, newest first.
    static func ratings(for topic: Topic) -> [StudyProgress] {
        topic.progressEntries
            .filter(\.isRating)
            .sorted { $0.date > $1.date }
    }

    // The latest rating given while studying one particular resource.
    static func latestRating(for resource: LearningResource) -> DifficultyRating {
        resource.topic?.progressEntries
            .filter { $0.isRating && $0.resourceID == resource.id }
            .max { $0.date < $1.date }?
            .understanding ?? .notRated
    }

    // 0 (needs revision) ... 1 (understood), weighting recent ratings most.
    // nil when the student hasn't rated the topic yet.
    static func confidence(for topic: Topic) -> Double? {
        let history = ratings(for: topic)
        guard !history.isEmpty else { return nil }

        var weightedSum = 0.0
        var totalWeight = 0.0
        var weight = 1.0
        for entry in history {
            weightedSum += weight * (entry.understanding == .understood ? 1 : 0)
            totalWeight += weight
            weight *= ratingDecay
        }
        return weightedSum / totalWeight
    }

    // The "difficulty" part of the weighted score: 1 = needs the most attention.
    // Uses the rating history when there is one, otherwise the topic's stored rating.
    static func difficultySignal(for topic: Topic) -> Double {
        if let confidence = confidence(for: topic) {
            return 1 - confidence
        }
        switch topic.difficulty {
        case .needsRevision: return 1
        case .notRated: return 0.5
        case .understood: return 0
        }
    }

    // True when a topic's first rating was "needs revision" and its latest is
    // "understood": the student turned it around. Used by the Season Recap.
    static func wasTurnedAround(_ topic: Topic) -> Bool {
        let history = ratings(for: topic)
        guard let latest = history.first, let earliest = history.last, history.count > 1 else { return false }
        return earliest.understanding == .needsRevision && latest.understanding == .understood
    }

    // The best unfinished episode to feature for a topic: the lesson plan's next
    // step first, then the most relevant tagged resource, then the shortest.
    static func bestEpisode(for topic: Topic) -> LearningResource? {
        if let planned = topic.nextPlannedResource {
            return planned
        }

        let unfinished = topic.resources.filter { !$0.isCompleted }
        let relevant = unfinished.filter { ($0.relevanceScore ?? 1) >= relevanceThreshold }
        let pool = relevant.isEmpty ? unfinished : relevant

        return pool.sorted { lhs, rhs in
            let left = lhs.relevanceScore ?? 0.5
            let right = rhs.relevanceScore ?? 0.5
            return left == right ? lhs.durationMinutes < rhs.durationMinutes : left > right
        }
        .first
    }
}
