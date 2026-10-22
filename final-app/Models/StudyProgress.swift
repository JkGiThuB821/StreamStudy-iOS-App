//
//  StudyProgress.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import Foundation
import SwiftData

// Where a Swipe-to-Revise rating was made.
nonisolated enum RatingSource: String, Codable {
    case episode   // topic (episode) detail screen
    case digest    // a Weekly Digest card
}

// One entry in the Season Pass signal pipeline. An entry is either study time
// (minutesSpent > 0, logged when a resource is completed) or a Swipe-to-Revise
// rating (minutesSpent == 0, understandingRaw set). Keeping both in one entity
// gives every surface a single history to read.
@Model
final class StudyProgress {
    var id: UUID
    var date: Date
    var minutesSpent: Int

    // Swipe-to-Revise data. Optional with defaults so existing stores migrate automatically.
    var understandingRaw: String? = nil
    var ratingSourceRaw: String? = nil
    var resourceID: UUID? = nil

    var topic: Topic?

    init(date: Date = .now, minutesSpent: Int) {
        self.id = UUID()
        self.date = date
        self.minutesSpent = minutesSpent
    }

    // .understood or .needsRevision when this entry is a rating, otherwise nil.
    var understanding: DifficultyRating? {
        understandingRaw.flatMap { DifficultyRating(rawValue: $0) }
    }

    var ratingSource: RatingSource? {
        ratingSourceRaw.flatMap { RatingSource(rawValue: $0) }
    }

    var isRating: Bool { understanding != nil }
}
