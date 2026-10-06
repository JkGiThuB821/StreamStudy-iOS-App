//
//  FirestoreDTOs.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 5/10/2026.
//

import Foundation

struct SubjectDTO: Codable {
    var id: UUID
    var name: String
    var subjectDescription: String
    var colorHex: String
    var iconName: String
    var createdAt: Date
}

struct TopicDTO: Codable {
    var id: UUID
    var subjectId: UUID
    var title: String
    var topicDescription: String
    var isCompleted: Bool
    var difficulty: String // DifficultyRating.rawValue
    var orderIndex: Int
    var createdAt: Date
    var searchTag: String
    var hasSearchedForResources: Bool
    // JSON-encoded LessonPlan. Optional so older Firestore documents still decode.
    var lessonPlanJSON: String?
}

struct ResourceDTO: Codable {
    var id: UUID
    var topicId: UUID
    var title: String
    var resourceDescription: String
    var urlString: String
    var thumbnailURLString: String?
    var sourceName: String
    var type: String // ResourceType.rawValue
    var durationMinutes: Int
    var isCompleted: Bool
    var isSaved: Bool
    var addedAt: Date
}

struct DeadlineDTO: Codable {
    var id: UUID
    var subjectId: UUID?
    var title: String
    var dueDate: Date
    var priority: String // DeadlinePriority.rawValue
    var notes: String
    var createdAt: Date
}

struct StudyProgressDTO: Codable {
    var id: UUID
    var topicId: UUID?
    var date: Date
    var minutesSpent: Int
}

// MARK: - Model <-> DTO conversions

extension Subject {
    var asDTO: SubjectDTO {
        SubjectDTO(id: id, name: name, subjectDescription: subjectDescription, colorHex: colorHex, iconName: iconName, createdAt: createdAt)
    }
}

extension Topic {
    func asDTO() -> TopicDTO? {
        guard let subjectId = subject?.id else { return nil }
        return TopicDTO(
            id: id, subjectId: subjectId, title: title, topicDescription: topicDescription,
            isCompleted: isCompleted, difficulty: difficulty.rawValue, orderIndex: orderIndex,
            createdAt: createdAt, searchTag: searchTag, hasSearchedForResources: hasSearchedForResources,
            lessonPlanJSON: lessonPlanData.flatMap { String(data: $0, encoding: .utf8) }
        )
    }
}

extension LearningResource {
    func asDTO() -> ResourceDTO? {
        guard let topicId = topic?.id else { return nil }
        return ResourceDTO(
            id: id, topicId: topicId, title: title, resourceDescription: resourceDescription,
            urlString: urlString, thumbnailURLString: thumbnailURLString, sourceName: sourceName,
            type: type.rawValue, durationMinutes: durationMinutes, isCompleted: isCompleted,
            isSaved: isSaved, addedAt: addedAt
        )
    }
}

extension Deadline {
    var asDTO: DeadlineDTO {
        DeadlineDTO(id: id, subjectId: subject?.id, title: title, dueDate: dueDate, priority: priority.rawValue, notes: notes, createdAt: createdAt)
    }
}

extension StudyProgress {
    var asDTO: StudyProgressDTO {
        StudyProgressDTO(id: id, topicId: topic?.id, date: date, minutesSpent: minutesSpent)
    }
}
