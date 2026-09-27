//
//  StreamStudyApp.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import SwiftUI
import SwiftData

@main
struct StreamStudyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Subject.self,
            Topic.self,
            LearningResource.self,
            Deadline.self,
            StudyProgress.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup{
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
