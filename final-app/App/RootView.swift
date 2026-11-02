//
//  RootView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 17/9/2026.
//
import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var syncService: FirestoreSyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(UserPreferences.onboardedUserIDsKey) private var onboardedUserIDs = ""
    @AppStorage(UserPreferences.replayOnboardingKey) private var replayOnboarding = false
    @ObservedObject private var network = NetworkMonitor.shared
    // Accounts already checked against Firestore this session.
    @State private var checkedOnboardingIDs: Set<String> = []

    var body: some View {
        Group {
            if authManager.isSignedIn, let uid = authManager.uid {
                if replayOnboarding {
                    OnboardingView()
                } else if UserPreferences.hasOnboarded(uid, in: onboardedUserIDs) {
                    MainTabView()
                } else if checkedOnboardingIDs.contains(uid) {
                    OnboardingView()
                } else {
                    // New device or reinstall: check the account before showing onboarding again.
                    ProgressView("Setting things up…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.appBackground)
                        .task(id: uid) { await checkOnboarding(uid: uid) }
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
            // Signed out: remove this account's data and reminders from the device,
            // so the next account to sign in starts empty.
            if !isSignedIn {
                do {
                    try syncService.clearLocalData(modelContext: modelContext)
                    print("Signed out: cleared this device's data")
                } catch {
                    print("Couldn't clear local data on sign-out: \(error)")
                }
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                checkedOnboardingIDs = []
                return
            }
            guard let uid = authManager.uid else { return }
            // Removes any other account's data still on the device before anything syncs.
            syncService.prepareLocalData(for: uid, modelContext: modelContext)
            // Offline: skip the pull. It replaces local data with the cloud copy, and
            // with no connection that copy could be empty. Local data keeps working.
            guard network.isConnected else { return }
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
                // Re-checks the connection in case it changed while the app was closed.
                network.recheck()
            }
            // Offline writes would wait forever; they're pushed when the connection returns.
            guard newPhase == .background, network.isConnected,
                  authManager.isSignedIn, let uid = authManager.uid else { return }
            pushInBackgroundTask(uid: uid)
        }
    }
    
    // Onboarding only shows for genuinely new accounts: skipped if this account
    // finished it on another device (Firestore flag) or already has subjects here.
    private func checkOnboarding(uid: String) async {
        let localSubjects = (try? modelContext.fetchCount(FetchDescriptor<Subject>())) ?? 0
        var done = localSubjects > 0
        if !done, network.isConnected {
            done = await syncService.hasCompletedOnboarding(uid: uid)
        }
        if done {
            onboardedUserIDs = UserPreferences.adding(uid, to: onboardedUserIDs)
        }
        checkedOnboardingIDs.insert(uid)
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
