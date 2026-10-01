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
    
    init() {
        FirebaseApp.configure()
        
        let appearance = UINavigationBarAppearance()

               appearance.configureWithTransparentBackground()

               appearance.titleTextAttributes = [
                   .font: UIFont(
                       name: "SpaceGrotesk-SemiBold",
                       size: 20
                   ) ?? UIFont.systemFont(
                       ofSize: 20,
                       weight: .semibold
                   ),
                   .foregroundColor: UIColor.white
               ]

               appearance.largeTitleTextAttributes = [
                   .font: UIFont(
                       name: "SpaceGrotesk-Bold",
                       size: 34
                   ) ?? UIFont.systemFont(
                       ofSize: 34,
                       weight: .bold
                   ),
                   .foregroundColor: UIColor.white
               ]

               UINavigationBar.appearance().standardAppearance = appearance
               UINavigationBar.appearance().scrollEdgeAppearance = appearance
               UINavigationBar.appearance().compactAppearance = appearance
           }
    
    var body: some Scene {
        WindowGroup{
            RootView()
                .environmentObject(authManager)
        }
        .modelContainer(sharedModelContainer)
    }
}

