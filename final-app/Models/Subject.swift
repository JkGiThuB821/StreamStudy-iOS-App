//
//  Subject.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import Foundation
import SwiftData

@Model
final class Subject {
    var id: UUID
    var name: String
    var subjectDescription: String
    var colorHex: String
    var iconName: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Topic.subbject)
    var topics: [Topic] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Deadline.subject)
    var deadlines: [Deadline] = []
    
    init(
        name: String,
        subjectDescription: String = "",
        colorHex: String = "#E50914",
        iconName: String = "book.closed.fill"
    ) {
        self.id = UUID()
        self.name = name,
        self.subjectDescription = subjectDescription
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdAt = .now
    }
    
    var progress: Double {
        guard !topics.isEmpty else { return 0 }
        let completed = topic.filter { $0.isCompleted }.count
        return Double(completed) / Double(topic.count)
    }
}
