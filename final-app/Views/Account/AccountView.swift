//
//  AccountView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct AccountView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var syncService: FirestoreSyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @ObservedObject private var notifications = NotificationService.shared
    @ObservedObject private var network = NetworkMonitor.shared

    @State private var tab: Tab = .profile
    @State private var testSent = false
    @State private var nameDraft = ""
    @AppStorage(UserPreferences.onboardedUserIDsKey) private var onboardedUserIDs = ""
    @ScaledMetric(relativeTo: .headline) private var avatarSize: CGFloat = 44

    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(NotificationService.remindersEnabledKey) private var remindersEnabled = true
    @AppStorage(NotificationService.weeklyDigestEnabledKey) private var weeklyDigestEnabled = true
    @AppStorage(NotificationService.reminderLeadDaysKey) private var reminderLeadDays = 1

    enum Tab { case profile, notifications }

    var body: some View {
        ScrollView {
            Picker("Section", selection: $tab) {
                Text("Profile & Settings").tag(Tab.profile)
                Text("Notifications").tag(Tab.notifications)
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if tab == .profile {
                    profileSection
                } else {
                    notificationsSection
                }
            }
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
        .navigationTitle("Account")
        .task {
            await notifications.refreshStatus()
        }
        .onAppear {
            nameDraft = authManager.displayName ?? ""
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle().fill(.red).frame(width: avatarSize, height: avatarSize)
                    .overlay(Text(initial).font(.sgHeadline).foregroundStyle(.white))
                VStack(alignment: .leading) {
                    Text(authManager.displayName ?? authManager.userEmail ?? "Account").font(.sgHeadline)
                    Text(authManager.userEmail ?? "Signed in").font(.sgCaption).foregroundStyle(.secondary)
                }
            }

            connectionRow

            VStack(alignment: .leading, spacing: 8) {
                Text("DISPLAY NAME").font(.sgCaption).foregroundStyle(.secondary)
                HStack {
                    TextField("Display name", text: $nameDraft)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                    Button("Save") {
                        Task { await authManager.updateDisplayName(nameDraft) }
                    }
                    .font(.spaceGrotesk(size: 14, weight: .bold))
                    .disabled(
                        nameDraft.trimmingCharacters(in: .whitespaces).isEmpty
                            || nameDraft == authManager.displayName
                    )
                }
                .padding(12)
                .background(Color.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button("Start Revision Mode") {}
                .buttonStyle(.borderedProminent)
                .tint(.red)

            VStack(alignment: .leading, spacing: 8) {
                Text("APPEARANCE").font(.sgCaption).foregroundStyle(.secondary)
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 12) {
                row(icon: "pencil", label: "Edit Profile")
                row(icon: "key.fill", label: "Change Password")
                row(icon: "link", label: "Linked Accounts")
                row(icon: "square.and.arrow.up", label: "Export Data")
            }

            syncRow

            Button {
                guard let uid = authManager.uid else { return }
                onboardedUserIDs = UserPreferences.removing(uid, from: onboardedUserIDs)
            } label: {
                Label("Show Onboarding Again", systemImage: "sparkles")
            }

            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
            .padding(.top, 20)
        }
        .padding(.horizontal)
    }

    private var connectionRow: some View {
        Label(
            network.isConnected ? "Online" : "Offline: changes are saved on this device and sync when you reconnect",
            systemImage: network.isConnected ? "wifi" : "wifi.slash"
        )
        .font(.spaceGrotesk(size: 13, weight: .semibold))
        .foregroundStyle(network.isConnected ? Color.green : Color.orange)
    }

    private var syncRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            AdaptiveStack(spacing: 8) {
                Text("iCloud / Firestore Sync")
                Spacer(minLength: 0)
                if syncService.isSyncing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Sync Now") {
                        guard let uid = authManager.uid else { return }
                        Task { await syncService.syncNow(uid: uid, modelContext: modelContext) }
                    }
                    .font(.spaceGrotesk(size: 12, weight: .bold))
                    .disabled(!network.isConnected)
                }
            }

            if let lastSyncedAt = syncService.lastSyncedAt {
                Text("Last synced \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not synced yet this session")
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
            }

            if let syncError = syncService.syncError {
                Text(syncError)
                    .font(.sgCaption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            permissionCard

            VStack(alignment: .leading, spacing: 12) {
                Text("NOTIFICATION PREFERENCES").font(.sgCaption).foregroundStyle(.secondary)

                Toggle("Deadline Reminders", isOn: $remindersEnabled)
                    .tint(.red)
                    .disabled(!isAuthorized)

                AdaptiveStack(spacing: 8) {
                    Text("Remind me")
                    Spacer(minLength: 0)
                    Picker("Remind me", selection: $reminderLeadDays) {
                        Text("1 day before").tag(1)
                        Text("2 days before").tag(2)
                        Text("1 week before").tag(7)
                    }
                    .labelsHidden()
                    .tint(.red)
                }
                .disabled(!isAuthorized || !remindersEnabled)
                .opacity(isAuthorized && remindersEnabled ? 1 : 0.5)

                Toggle("Weekly episode drop (Mondays, 9am)", isOn: $weeklyDigestEnabled)
                    .tint(.red)
                    .disabled(!isAuthorized)

                AdaptiveStack(spacing: 10) {
                    Button {
                        Task {
                            await notifications.sendTestNotification()
                            testSent = true
                        }
                    } label: {
                        Label("Test Reminder", systemImage: "bell.badge")
                    }

                    Button {
                        Task {
                            await notifications.sendTestNotification(opensDigest: true)
                            testSent = true
                        }
                    } label: {
                        Label("Test Weekly Drop", systemImage: "sparkles.tv")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!isAuthorized)

                if testSent {
                    Text("A test notification will appear in about 5 seconds. Tap it to open the Calendar (reminder) or this week's digest (weekly drop).")
                        .font(.sgCaption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("UPCOMING REMINDERS").font(.sgCaption).foregroundStyle(.secondary)

                if notifications.pendingReminders.isEmpty {
                    Text(emptyRemindersMessage)
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(notifications.pendingReminders) { reminder in
                        reminderRow(reminder)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    private var permissionCard: some View {
        AdaptiveStack(verticalAlignment: .top, spacing: 12) {
            Image(systemName: isAuthorized ? "bell.fill" : "bell.slash.fill")
                .font(.title3)
                .foregroundStyle(isAuthorized ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(permissionTitle).font(.sgHeadline)
                Text(permissionDetail)
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)

                if notifications.authorizationStatus == .notDetermined {
                    Button("Allow Notifications") {
                        Task { await notifications.requestPermission() }
                    }
                    .font(.spaceGrotesk(size: 14, weight: .bold))
                    .tint(.red)
                    .padding(.top, 4)
                } else if !isAuthorized {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.spaceGrotesk(size: 14, weight: .bold))
                    .tint(.red)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func reminderRow(_ reminder: NotificationService.PendingReminder) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(reminder.title).font(.spaceGrotesk(size: 15, weight: .semibold))
            if let fireDate = reminder.fireDate {
                Text(fireDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.sgCaption)
                    .foregroundStyle(.red)
            }
            Text(reminder.body)
                .font(.sgCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var isAuthorized: Bool {
        notifications.authorizationStatus == .authorized
            || notifications.authorizationStatus == .provisional
    }

    private var permissionTitle: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "Notifications are on"
        case .denied: return "Notifications are off"
        default: return "Notifications not set up"
        }
    }

    private var permissionDetail: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "StreamStudy can remind you about upcoming deadlines."
        case .denied:
            return "Turn notifications on in the Settings app to get deadline reminders."
        default:
            return "Allow notifications to get reminders before your deadlines."
        }
    }

    private var emptyRemindersMessage: String {
        if !isAuthorized { return "Allow notifications to schedule reminders." }
        if !remindersEnabled { return "Deadline reminders are turned off." }
        return "No reminders scheduled. Add a future deadline in the Calendar."
    }

    // MARK: - Helpers

    private var initial: String {
        String((authManager.userEmail ?? "A").prefix(1)).uppercased()
    }

    private func row(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon).frame(minWidth: 24)
            Text(label)
            Spacer()
            Image(systemName: "chevron.right").font(.sgCaption).foregroundStyle(.secondary)
        }
    }
}
