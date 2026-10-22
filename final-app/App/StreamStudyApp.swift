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
            WeeklyDigest.self,
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
    // Colours use .label so titles are black in Light Mode and white in Dark Mode,
    // and the scroll-edge (large title) state keeps the system's transparent bar.
    private static func configureNavigationBarFont() {
        let largeTitle = UIFont.spaceGrotesk(size: 34, weight: .bold, relativeTo: .largeTitle)
        let inlineTitle = UIFont.spaceGrotesk(size: 17, weight: .semibold, relativeTo: .headline)
        let buttonFont = UIFont.spaceGrotesk(size: 17, weight: .medium, relativeTo: .body)

        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [.font: buttonFont]

        func styled(_ appearance: UINavigationBarAppearance) -> UINavigationBarAppearance {
            appearance.largeTitleTextAttributes = [.font: largeTitle, .foregroundColor: UIColor.label]
            appearance.titleTextAttributes = [.font: inlineTitle, .foregroundColor: UIColor.label]
            appearance.buttonAppearance = buttonAppearance
            appearance.doneButtonAppearance = buttonAppearance
            appearance.backButtonAppearance = buttonAppearance
            return appearance
        }

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = styled(standard)
        navBar.compactAppearance = styled(standard)
        navBar.scrollEdgeAppearance = styled(scrollEdge)
        navBar.compactScrollEdgeAppearance = styled(scrollEdge)
    }
}
