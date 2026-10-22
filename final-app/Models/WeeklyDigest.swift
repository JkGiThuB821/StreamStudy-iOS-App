//
//  WeeklyDigest.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 22/10/2026.
//

import Foundation
import SwiftData

// One week's "episode drop". Kept as history so the Season Recap can look
// back over every drop a subject appeared in.
@Model
final class WeeklyDigest {
    var id: UUID
    var weekStart: Date          // Monday 00:00 of the week this drop is for
    var generatedAt: Date
    var headline: String
    var topicIDs: [UUID]         // featured topics, best first
    var resourceIDs: [UUID]      // the featured episode for each topic (same order)
    var minutesLastWeek: Int
    var episodesLastWeek: Int

    init(
        weekStart: Date,
        headline: String,
        topicIDs: [UUID],
        resourceIDs: [UUID],
        minutesLastWeek: Int,
        episodesLastWeek: Int
    ) {
        self.id = UUID()
        self.weekStart = weekStart
        self.generatedAt = .now
        self.headline = headline
        self.topicIDs = topicIDs
        self.resourceIDs = resourceIDs
        self.minutesLastWeek = minutesLastWeek
        self.episodesLastWeek = episodesLastWeek
    }
}
