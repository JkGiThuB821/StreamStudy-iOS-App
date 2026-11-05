//
//  Topic.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import Foundation
import SwiftData

nonisolated enum DifficultyRating: String, Codable, CaseIterable {
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
    var searchTag: String
    var hasSearchedForResources: Bool
    // JSON-encoded LessonPlan. Optional so existing stores migrate automatically.
    var lessonPlanData: Data?

    var subject: Subject?

    @Relationship(deleteRule: .cascade, inverse: \LearningResource.topic)
    var resources: [LearningResource] = []

    @Relationship(deleteRule: .cascade, inverse: \StudyProgress.topic)
    var progressEntries: [StudyProgress] = []

    init(
        title: String,
        topicDescription: String = "",
        orderIndex: Int = 0,
        searchTag: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.topicDescription = topicDescription
        self.isCompleted = false
        self.difficulty = .notRated
        self.orderIndex = orderIndex
        self.createdAt = .now
        self.searchTag = searchTag
        self.hasSearchedForResources = false
    }

    var progress: Double {
        guard !resources.isEmpty else { return 0 }
        let completed = resources.filter { $0.isCompleted }.count
        return Double(completed) / Double(resources.count)
    }

    var totalDurationMinutes: Int {
        resources.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Completion

    func toggleCompletion(of resource: LearningResource, modelContext: ModelContext) {
        resource.isCompleted.toggle()

        if resource.isCompleted {
            let entry = StudyProgress(minutesSpent: resource.durationMinutes)
            entry.topic = self
            modelContext.insert(entry)
        } else if let entry = progressEntries
            .filter({ Calendar.current.isDateInToday($0.date) && $0.minutesSpent == resource.durationMinutes })
            .max(by: { $0.date < $1.date }) {
            FirestoreSyncService.markForRemoteDeletion("studyProgress", id: entry.id)
            modelContext.delete(entry)
        }

        if !resources.isEmpty {
            isCompleted = resources.allSatisfy(\.isCompleted)
        }
    }

    // Ticks off a practice/review step (steps without resources).
    func toggleManualCompletion(of step: LessonStep) {
        guard var plan = lessonPlan,
              let index = plan.steps.firstIndex(where: { $0.id == step.id }) else { return }
        plan.steps[index].isManuallyCompleted.toggle()
        lessonPlan = plan
    }

    // MARK: - Lesson plan

    var lessonPlan: LessonPlan? {
        get {
            guard let lessonPlanData else { return nil }
            return try? JSONDecoder().decode(LessonPlan.self, from: lessonPlanData)
        }
        set {
            lessonPlanData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    func stepResources(for step: LessonStep) -> [LearningResource] {
        step.resourceIDs.compactMap { id in resources.first { $0.id == id } }
    }

    func isStepCompleted(_ step: LessonStep) -> Bool {
        let items = stepResources(for: step)
        return items.isEmpty
            ? step.isManuallyCompleted
            : items.allSatisfy(\.isCompleted)
    }

    // The first unfinished step of the lesson plan, if there is one.
    var nextLessonStep: LessonStep? {
        lessonPlan?.steps.first { !isStepCompleted($0) }
    }

    // Next resource to study: follows the lesson plan order when a plan exists.
    var nextPlannedResource: LearningResource? {
        if let plan = lessonPlan {
            for step in plan.steps {
                if let resource = stepResources(for: step).first(where: { !$0.isCompleted }) {
                    return resource
                }
            }
        }
        return nil
    }
}
