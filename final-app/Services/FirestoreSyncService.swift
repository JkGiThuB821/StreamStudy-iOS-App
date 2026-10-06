//
//  FirestoreSyncService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 5/10/2026.
//

import Foundation
import SwiftData
import FirebaseFirestore
import Combine

enum FirestoreSyncError: LocalizedError {
    case notSignedIn
    var errorDescription: String? {
        "You need to be signed in to sync."
    }
}

@MainActor
final class FirestoreSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncedAt: Date?
    @Published var syncError: String?

    private let db = Firestore.firestore()

    // MARK: - Push (local -> Firestore), called on scenePhase .background

    func push(uid: String, modelContext: ModelContext) async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            let subjects = try modelContext.fetch(FetchDescriptor<Subject>())
            let topics = try modelContext.fetch(FetchDescriptor<Topic>())
            let resources = try modelContext.fetch(FetchDescriptor<LearningResource>())
            let deadlines = try modelContext.fetch(FetchDescriptor<Deadline>())
            let progressEntries = try modelContext.fetch(FetchDescriptor<StudyProgress>())

            let batch = db.batch()
            let base = db.collection("users").document(uid)

            for subject in subjects {
                try batch.setData(from: subject.asDTO, forDocument: base.collection("subjects").document(subject.id.uuidString))
            }
            for topic in topics {
                guard let dto = topic.asDTO() else { continue }
                try batch.setData(from: dto, forDocument: base.collection("topics").document(topic.id.uuidString))
            }
            for resource in resources {
                guard let dto = resource.asDTO() else { continue }
                try batch.setData(from: dto, forDocument: base.collection("resources").document(resource.id.uuidString))
            }
            for deadline in deadlines {
                try batch.setData(from: deadline.asDTO, forDocument: base.collection("deadlines").document(deadline.id.uuidString))
            }
            for entry in progressEntries {
                try batch.setData(from: entry.asDTO, forDocument: base.collection("studyProgress").document(entry.id.uuidString))
            }

            try await batch.commit()
            lastSyncedAt = .now
        } catch {
            syncError = "Push failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Pull (Firestore -> local), called on launch / sign-in

    func pull(uid: String, modelContext: ModelContext) async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            let base = db.collection("users").document(uid)

            async let subjectDocs = base.collection("subjects").getDocuments()
            async let topicDocs = base.collection("topics").getDocuments()
            async let resourceDocs = base.collection("resources").getDocuments()
            async let deadlineDocs = base.collection("deadlines").getDocuments()
            async let progressDocs = base.collection("studyProgress").getDocuments()

            let subjectSnapshots = try await subjectDocs.documents.map { try $0.data(as: SubjectDTO.self) }
            let topicSnapshots = try await topicDocs.documents.map { try $0.data(as: TopicDTO.self) }
            let resourceSnapshots = try await resourceDocs.documents.map { try $0.data(as: ResourceDTO.self) }
            let deadlineSnapshots = try await deadlineDocs.documents.map { try $0.data(as: DeadlineDTO.self) }
            let progressSnapshots = try await progressDocs.documents.map { try $0.data(as: StudyProgressDTO.self) }

            // Wholesale-replace local state so a freshly-pulled account never
            // sees a previous account's leftover local data on this device.
            try wipeLocalData(modelContext: modelContext)

            var subjectsById: [UUID: Subject] = [:]
            for dto in subjectSnapshots {
                let subject = Subject(name: dto.name, subjectDescription: dto.subjectDescription, colorHex: dto.colorHex, iconName: dto.iconName)
                subject.id = dto.id
                modelContext.insert(subject)
                subjectsById[dto.id] = subject
            }

            var topicsById: [UUID: Topic] = [:]
            for dto in topicSnapshots {
                guard let subject = subjectsById[dto.subjectId] else { continue }
                let topic = Topic(title: dto.title, topicDescription: dto.topicDescription, orderIndex: dto.orderIndex, searchTag: dto.searchTag)
                topic.id = dto.id
                topic.isCompleted = dto.isCompleted
                topic.difficulty = DifficultyRating(rawValue: dto.difficulty) ?? .notRated
                topic.hasSearchedForResources = dto.hasSearchedForResources
                topic.lessonPlanData = dto.lessonPlanJSON?.data(using: .utf8)
                topic.subject = subject
                modelContext.insert(topic)
                topicsById[dto.id] = topic
            }

            for dto in resourceSnapshots {
                guard let topic = topicsById[dto.topicId] else { continue }
                let resource = LearningResource(
                    title: dto.title, urlString: dto.urlString, sourceName: dto.sourceName,
                    type: ResourceType(rawValue: dto.type) ?? .article, durationMinutes: dto.durationMinutes,
                    resourceDescription: dto.resourceDescription, thumbnailURLString: dto.thumbnailURLString
                )
                resource.id = dto.id
                resource.isCompleted = dto.isCompleted
                resource.isSaved = dto.isSaved
                resource.topic = topic
                modelContext.insert(resource)
            }

            for dto in deadlineSnapshots {
                let deadline = Deadline(title: dto.title, dueDate: dto.dueDate, priority: DeadlinePriority(rawValue: dto.priority) ?? .medium, notes: dto.notes)
                deadline.id = dto.id
                if let subjectId = dto.subjectId { deadline.subject = subjectsById[subjectId] }
                modelContext.insert(deadline)
            }

            for dto in progressSnapshots {
                let entry = StudyProgress(date: dto.date, minutesSpent: dto.minutesSpent)
                entry.id = dto.id
                if let topicId = dto.topicId { entry.topic = topicsById[topicId] }
                modelContext.insert(entry)
            }

            try modelContext.save()
            lastSyncedAt = .now
        } catch {
            syncError = "Pull failed: \(error.localizedDescription)"
        }
    }

    func syncNow(uid: String, modelContext: ModelContext) async {
        await push(uid: uid, modelContext: modelContext)
        guard syncError == nil else { return }
        await pull(uid: uid, modelContext: modelContext)
    }

    private func wipeLocalData(modelContext: ModelContext) throws {
        try modelContext.delete(model: StudyProgress.self)
        try modelContext.delete(model: Deadline.self)
        try modelContext.delete(model: LearningResource.self)
        try modelContext.delete(model: Topic.self)
        try modelContext.delete(model: Subject.self)
    }
}
