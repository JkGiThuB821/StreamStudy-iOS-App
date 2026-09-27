//
//  Topic.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import Foundation
import SwiftData

enum DifficultyRating: String, Codable, CaseIterable {
    case understood
    case needsRevision
    case notRated
}


@Model
final class Topic {
    var id: UUID
    var title: String
    var topicDescription: String
    var isCompleted: Bool
    var difficulty: DifficultyRating
    var orderIndex: Int
    var createdAt: Date
    
    var subject: Subject?
    
    @Relationship(deleteRule: .cascade, inverse: \LearningResource.topic)
    var resources: [LearningResource] = []
    
    @Relationship(deleteRule: .cascade, inverse: \StudyProgress.topic)
    var progressEntries: [StudyProgress] = []
    
    init(
        title: String,
        topicDescription: String = "",
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title,
        self.topicDescription = topicDescription,
        self.isCompleted = false,
        self.difficulty = .notRated,
        self.orderIndex = orderIndex,
        self.createdAt = .now
    }
    
    var progress: Double {
        guard !resources.isEmpty else { return 0 }
        let completed = resources.filter { $0.isCompleted }.count
        return Double(completed) / Double(resources.count)
    }
    
    var totalDurationMinutes: Int {
        resources.reduce(0) { $0 + $1.durationMiuntes}
    }
}
