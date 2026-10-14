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
    @AppStorage(UserPreferences.onboardedUserIDsKey) private var onboardedUserIDs = ""
    @ObservedObject private var network = NetworkMonitor.shared

    var body: some View {
        Group {
            if authManager.isSignedIn, let uid = authManager.uid {
                if UserPreferences.hasOnboarded(uid, in: onboardedUserIDs) {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            } else {
                SignInView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ConnectionBanner()
        }
        .font(.sgBody)
        .tint(.red)
        .preferredColorScheme(appearance.colorScheme)
        .animation(.default, value: authManager.isSignedIn)
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            // Offline: skip the pull. It replaces local data with the cloud copy, and
            // with no connection that copy could be empty. Local data keeps working.
            guard isSignedIn, let uid = authManager.uid, network.isConnected else { return }
            Task { await syncService.pull(uid: uid, modelContext: modelContext) }
        }
        .onChange(of: network.isConnected) { _, isConnected in
            // Back online: upload anything changed while offline.
            guard isConnected, authManager.isSignedIn, let uid = authManager.uid else { return }
            Task { await syncService.push(uid: uid, modelContext: modelContext) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Picks up notification permission changes made in the Settings app.
                Task { await NotificationService.shared.refreshStatus() }
            }
            // Offline writes would wait forever; they're pushed when the connection returns.
            guard newPhase == .background, network.isConnected,
                  authManager.isSignedIn, let uid = authManager.uid else { return }
            pushInBackgroundTask(uid: uid)
        }
    }
    
    private func pushInBackgroundTask(uid: String) {
        let task = BackgroundTaskBox()
        task.id = UIApplication.shared.beginBackgroundTask(withName: "FirestorePush") {
            UIApplication.shared.endBackgroundTask(task.id)
        }
        Task {
            await syncService.push(uid: uid, modelContext: modelContext)
            UIApplication.shared.endBackgroundTask(task.id)
        }
    }
}

private nonisolated final class BackgroundTaskBox: @unchecked Sendable {
    var id: UIBackgroundTaskIdentifier = .invalid
}
