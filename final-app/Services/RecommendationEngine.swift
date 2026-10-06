//
//  RecommendationEngine.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 1/10/2026.
//

import Foundation

struct TopicRecommendation: Identifiable {
    var id: UUID { topic.id }
    let topic: Topic
    let score: Double
    let nextResource: LearningResource?
}

enum RecommendationEngine {
    struct Weights {
        var deadlineProximity: Double = 0.5
        var progress: Double = 0.3
        var difficulty: Double = 0.2
    }

    static func rank(topics: [Topic], weights: Weights = Weights()) -> [TopicRecommendation] {
        topics
            .filter { topic in
                !topic.isCompleted && topic.resources.contains { !$0.isCompleted }
            }
            .map { topic in
                TopicRecommendation(
                    topic: topic,
                    score: score(for: topic, weights: weights),
                    // Follow the lesson plan's order when there is one,
                    // otherwise start with the shortest unfinished resource.
                    nextResource: topic.nextPlannedResource ?? topic.resources
                        .filter { !$0.isCompleted }
                        .sorted { $0.durationMinutes < $1.durationMinutes }
                        .first
                )
            }
            .sorted { $0.score > $1.score }
    }

    static func nextWatch(topics: [Topic], weights: Weights = Weights()) -> TopicRecommendation? {
        rank(topics: topics, weights: weights).first
    }

    private static func score(for topic: Topic, weights: Weights) -> Double {
        let deadline = deadlineProximityScore(for: topic)
        // Less complete = more urgent to pick up.
        let progress = 1 - topic.progress
        let difficulty: Double
        switch topic.difficulty {
        case .needsRevision: difficulty = 1.0
        case .notRated: difficulty = 0.5
        case .understood: difficulty = 0.0
        }

        return weights.deadlineProximity * deadline
            + weights.progress * progress
            + weights.difficulty * difficulty
    }

    private static func deadlineProximityScore(for topic: Topic) -> Double {
        guard let subject = topic.subject else { return 0 }

        let gracePeriodStart = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .distantPast
        guard let nearest = subject.deadlines
            .filter({ $0.dueDate >= gracePeriodStart })
            .min(by: { $0.dueDate < $1.dueDate })
        else { return 0 }

        let days = Double(nearest.daysRemaining)
        return max(0, min(1, 1 - days / 30))
    }
}
