//
//  StreamStudyApp.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct StreamStudyApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var syncService = FirestoreSyncService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Subject.self,
            Topic.self,
            LearningResource.self,
            Deadline.self,
            StudyProgress.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(syncService)
        }
        .modelContainer(sharedModelContainer)
    }
}
