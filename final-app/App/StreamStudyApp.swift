//
//  StreamStudyApp.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct StreamStudyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
        // FirebaseApp.configure() now runs in AppDelegate so it happens before
        // AuthManager is created by @StateObject.
        Self.configureNavigationBarFont()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(syncService)
                .environmentObject(appDelegate.deepLinkRouter)
                .onOpenURL { appDelegate.deepLinkRouter.handle(url: $0) }
        }
        .modelContainer(sharedModelContainer)
    }

    // Navigation bar titles are drawn by UIKit, so SwiftUI's .font() doesn't reach them.
    private static func configureNavigationBarFont() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.shadowColor = .clear

        if let large = UIFont(name: "SpaceGrotesk-Bold", size: 34) {
            appearance.largeTitleTextAttributes = [.font: large, .foregroundColor: UIColor.white]
        }
        if let inline = UIFont(name: "SpaceGrotesk-SemiBold", size: 17) {
            appearance.titleTextAttributes = [.font: inline, .foregroundColor: UIColor.white]
        }
        if let button = UIFont(name: "SpaceGrotesk-Medium", size: 17) {
            let buttonAppearance = UIBarButtonItemAppearance()
            buttonAppearance.normal.titleTextAttributes = [.font: button]
            appearance.buttonAppearance = buttonAppearance
            appearance.doneButtonAppearance = buttonAppearance
            appearance.backButtonAppearance = buttonAppearance
        }

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
    }
}
