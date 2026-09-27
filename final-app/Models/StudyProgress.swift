//
//  StudyProgress.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import Foundation
import SwiftData

@Model
final class StudyProgress {
    var id: UUID
    var date: Date
    var minutesSpent: Int
    
    var topic: Topic?
    
    init(date: Date = .now, minutesSpent: Int) {
        self.id = UUID()
        self.date = date
        self.minutesSpent = minutesSpent
    }
}
