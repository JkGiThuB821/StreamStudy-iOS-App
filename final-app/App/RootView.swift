//
//  RootView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 17/9/2026.
//
import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var syncService: FirestoreSyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some View {
        Group {
            if authManager.isSignedIn {
                MainTabView()
            } else {
                SignInView()
            }
        }
        .font(.sgBody)
        .preferredColorScheme(appearance.colorScheme)
        .animation(.default, value: authManager.isSignedIn)
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            guard isSignedIn, let uid = authManager.uid else { return }
            Task { await syncService.pull(uid: uid, modelContext: modelContext) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Picks up notification permission changes made in the Settings app.
                Task { await NotificationService.shared.refreshStatus() }
            }
            guard newPhase == .background, authManager.isSignedIn, let uid = authManager.uid else { return }
            pushInBackgroundTask(uid: uid)
        }
    }
    
    private func pushInBackgroundTask(uid: String) {
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "FirestorePush") {
            UIApplication.shared.endBackgroundTask(taskID)
        }
        Task {
            await syncService.push(uid: uid, modelContext: modelContext)
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
}
