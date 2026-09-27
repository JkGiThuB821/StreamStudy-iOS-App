//
//  Deadline.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import Foundation
import SwiftData

enum DeadlinePriority: String, Codable, CaseIterable {
    case low, medium, high
    
    var displayName: String {
        rawValue.capitalized
    }
}

@Model
final class Deadline {
    var id: UUID
    var title: String
    var dueDate: Date
    var priority: DeadlinePriority
    var notes: String
    var createdAt: Date
    
    var subject: Subject?
    
    init(
        title: String,
        dueDate: Date,
        priority: DeadlinePriority = .medium,
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.dueDate = dueDate
        self.priority = priority
        self.notes = notes
        self.createdAt = .now
    }
    
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: .now, to: dueDate).day ?? 0
    }
    
    var isOverdue: Bool{
        dueDate < .now
    }
}

