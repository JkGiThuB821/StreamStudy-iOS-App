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
                    // Lesson plan order first, then the most relevant (AI-tagged)
                    // episode, then the shortest. See SignalPipeline.bestEpisode.
                    nextResource: SignalPipeline.bestEpisode(for: topic)
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
        // Swipe-to-Revise history when there is one, otherwise the stored rating.
        let difficulty = SignalPipeline.difficultySignal(for: topic)

        return weights.deadlineProximity * deadline
            + weights.progress * progress
            + weights.difficulty * difficulty
    }

    static func deadlineProximityScore(for topic: Topic) -> Double {
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
