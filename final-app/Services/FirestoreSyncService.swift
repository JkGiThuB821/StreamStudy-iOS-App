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

    // Which account the data on this device belongs to. Uploads only go to
    // that account, so one user's data can never be copied into another's.
    private static let localDataOwnerKey = "localDataOwnerUID"

    private var localDataOwner: String? {
        get { UserDefaults.standard.string(forKey: Self.localDataOwnerKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.localDataOwnerKey) }
    }

    // Called when an account signs in: if the device still holds another
    // account's data (e.g. the app closed before sign-out finished), it is
    // removed first. Then the device is marked as belonging to this account.
    func prepareLocalData(for uid: String, modelContext: ModelContext) {
        if let owner = localDataOwner, owner != uid {
            do {
                try clearLocalData(modelContext: modelContext)
                print("Removed another account's data from this device")
            } catch {
                print("Couldn't clear another account's data: \(error)")
            }
        }
        localDataOwner = uid
    }

    // MARK: - Push (local -> Firestore), called on scenePhase .background

    func push(uid: String, modelContext: ModelContext) async {
        // Never upload data that belongs to a different account.
        guard localDataOwner == nil || localDataOwner == uid else {
            print("Skipped upload: the data on this device belongs to another account")
            return
        }
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

    // MARK: - Onboarding flag (Week 11 feedback: onboarding should not be repeated)

    // True when this account has finished onboarding on any device. Accounts
    // created before the flag existed count as onboarded if they have subjects.
    func hasCompletedOnboarding(uid: String) async -> Bool {
        let user = db.collection("users").document(uid)
        do {
            let document = try await user.getDocument(source: .server)
            if document.data()?["onboardingComplete"] as? Bool == true { return true }
            let subjects = try await user.collection("subjects").limit(to: 1).getDocuments(source: .server)
            return !subjects.isEmpty
        } catch {
            return false
        }
    }

    // Not awaited: when offline, Firestore queues the write and sends it later.
    func markOnboardingComplete(uid: String) {
        db.collection("users").document(uid).setData(["onboardingComplete": true], merge: true)
    }

    // MARK: - Pull (Firestore -> local), called on launch / sign-in

    func pull(uid: String, modelContext: ModelContext) async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            let base = db.collection("users").document(uid)

            // `.server` fails when offline instead of quietly returning Firestore's
            // local cache (which may be empty) — so local data is never wiped by mistake.
            async let subjectDocs = base.collection("subjects").getDocuments(source: .server)
            async let topicDocs = base.collection("topics").getDocuments(source: .server)
            async let resourceDocs = base.collection("resources").getDocuments(source: .server)
            async let deadlineDocs = base.collection("deadlines").getDocuments(source: .server)
            async let progressDocs = base.collection("studyProgress").getDocuments(source: .server)

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
                resource.aiTagsRaw = dto.aiTags ?? ""
                resource.relevanceScore = dto.relevanceScore
                resource.tagSourceRaw = dto.tagSource
                resource.notes = dto.notes ?? ""
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
                entry.understandingRaw = dto.understanding
                entry.ratingSourceRaw = dto.ratingSource
                entry.resourceID = dto.resourceId
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

    // MARK: - Account deletion

    // Removes everything this account stored in Firestore: every document in
    // each collection, then the users/{uid} document itself.
    func deleteAllData(uid: String) async throws {
        let base = db.collection("users").document(uid)
        for name in ["subjects", "topics", "resources", "deadlines", "studyProgress"] {
            let documents = try await base.collection(name).getDocuments(source: .server).documents
            // A Firestore batch holds at most 500 writes.
            for start in stride(from: 0, to: documents.count, by: 450) {
                let batch = db.batch()
                for document in documents[start..<min(start + 450, documents.count)] {
                    batch.deleteDocument(document.reference)
                }
                try await batch.commit()
            }
        }
        try await base.delete()
        lastSyncedAt = nil
    }

    // Removes this account's data from the device, including the weekly
    // digests, which are only stored locally.
    func clearLocalData(modelContext: ModelContext) throws {
        try wipeLocalData(modelContext: modelContext)
        try deleteAll(WeeklyDigest.self, in: modelContext)
        try modelContext.save()
        // The next account starts with a fresh sync status too.
        lastSyncedAt = nil
        syncError = nil
        localDataOwner = nil
    }

    // Each object is fetched and deleted one by one. The batch delete,
    // `modelContext.delete(model:)`, works on the store directly, so objects
    // the app already has loaded stayed on screen after signing out.
    private func wipeLocalData(modelContext: ModelContext) throws {
        try deleteAll(StudyProgress.self, in: modelContext)
        try deleteAll(Deadline.self, in: modelContext)
        try deleteAll(LearningResource.self, in: modelContext)
        try deleteAll(Topic.self, in: modelContext)
        try deleteAll(Subject.self, in: modelContext)
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, in modelContext: ModelContext) throws {
        for object in try modelContext.fetch(FetchDescriptor<T>()) {
            modelContext.delete(object)
        }
    }
}
