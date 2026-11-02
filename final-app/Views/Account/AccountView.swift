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
    @State private var showingRevisionMode = false
    @State private var passwordResetMessage: String?
    @State private var showingDemoConfirm = false
    @State private var demoMessage: String?
    @State private var nameDraft = ""
    @State private var showingPrivacyPolicy = false
    @State private var showingAbout = false
    @State private var showingDeleteAccount = false
    @State private var deletePassword = ""
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var isSigningOut = false
    @State private var showingUnsyncedSignOut = false
    @AppStorage(UserPreferences.replayOnboardingKey) private var replayOnboarding = false
    @ScaledMetric(relativeTo: .headline) private var avatarSize: CGFloat = 56

    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(NotificationService.remindersEnabledKey) private var remindersEnabled = true
    @AppStorage(NotificationService.weeklyDigestEnabledKey) private var weeklyDigestEnabled = true
    @AppStorage(NotificationService.reminderLeadDaysKey) private var reminderLeadDays = 1

    enum Tab { case profile, notifications }

    var body: some View {
        ScrollView {
            // Red pill switcher, as in the mock-up.
            PillPicker(selection: $tab, options: [(.profile, "Profile & Settings"), (.notifications, "Notifications")])
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
        .tabBarClearance()   // keeps the last item clear of the tab bar
        .navigationTitle("Account")
        .task {
            await notifications.refreshStatus()
        }
        .onAppear {
            nameDraft = authManager.displayName ?? ""
        }
        .confirmationDialog(
            "Load demo data?",
            isPresented: $showingDemoConfirm,
            titleVisibility: .visible
        ) {
            Button("Load Demo Data") { loadDemoData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Adds sample subjects, topics, study history, ratings, deadlines and weekly drops to this account. Best used on a separate demo account.")
        }
        .fullScreenCover(isPresented: $showingRevisionMode) {
            RevisionModeView()
        }
        .alert(
            "Change Password",
            isPresented: Binding(
                get: { passwordResetMessage != nil },
                set: { if !$0 { passwordResetMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(passwordResetMessage ?? "")
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        // Guideline 5.1.1(v): accounts created in the app can be deleted in the app.
        .alert("Delete Account?", isPresented: $showingDeleteAccount) {
            SecureField("Password", text: $deletePassword)
            Button("Delete", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) { deletePassword = "" }
        } message: {
            Text("This permanently deletes your account and all your subjects, topics, progress and deadlines from this device and the cloud. Enter your password to confirm.")
        }
        .alert(
            "Couldn't Delete Account",
            isPresented: Binding(
                get: { deleteAccountError != nil },
                set: { if !$0 { deleteAccountError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteAccountError ?? "")
        }
        .alert("Sign Out Anyway?", isPresented: $showingUnsyncedSignOut) {
            Button("Sign Out", role: .destructive) { authManager.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your latest changes haven't been uploaded yet. Signing out removes this account's data from this device, so those changes will be lost.")
        }
        .overlay {
            if isSigningOut {
                ProgressView("Signing out…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            if isDeletingAccount {
                ProgressView("Deleting your account…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            profileCard

            // Revision Mode, highlighted as in the mock-up.
            Button {
                showingRevisionMode = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "scope")
                        .font(.title2)
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Revision Mode")
                            .font(.spaceGrotesk(size: 16, weight: .bold))
                        Text("Swipe through your topics before an exam")
                            .font(.sgCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                .padding(16)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.4)))
            }
            .buttonStyle(.plain)

            // Appearance
            VStack(alignment: .leading, spacing: 12) {
                Text("APPEARANCE")
                    .font(.spaceGrotesk(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                AdaptiveStack(spacing: 12) {
                    Text("Theme").font(.spaceGrotesk(size: 15, weight: .semibold))
                    Spacer(minLength: 0)
                    PillPicker(selection: $appearance, options: AppAppearance.allCases.map { ($0, $0.displayName) })
                        .frame(maxWidth: 240)
                }
            }
            .padding(16)
            .cardStyle()

            // Display name
            VStack(alignment: .leading, spacing: 10) {
                Text("DISPLAY NAME")
                    .font(.spaceGrotesk(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("Display name", text: $nameDraft)
                        .characterLimit($nameDraft, TextLimits.name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                    Button("Save") {
                        Task { await authManager.updateDisplayName(nameDraft) }
                    }
                    .font(.spaceGrotesk(size: 14, weight: .bold))
                    .disabled(nameDraft.isBlank || nameDraft == authManager.displayName)
                }
                .inputFieldStyle()
            }
            .padding(16)
            .cardStyle()

            // Settings list
            VStack(spacing: 0) {
                settingsRow("Change Password", systemImage: "key.fill", color: .orange) {
                    Task { passwordResetMessage = await authManager.sendPasswordReset() }
                }
                .disabled(!network.isConnected)
                Divider().padding(.leading, 52)
                settingsRow("Load Demo Data", systemImage: "tray.and.arrow.down.fill", color: .blue) {
                    showingDemoConfirm = true
                }
                Divider().padding(.leading, 52)
                settingsRow("Show Onboarding Again", systemImage: "sparkles", color: .purple) {
                    replayOnboarding = true
                }
                Divider().padding(.leading, 52)
                settingsRow("Privacy Policy", systemImage: "hand.raised.fill", color: .gray) {
                    showingPrivacyPolicy = true
                }
                Divider().padding(.leading, 52)
                settingsRow("About StreamStudy", systemImage: "info.circle.fill", color: .red) {
                    showingAbout = true
                }
            }
            .cardStyle()

            if let demoMessage {
                Text(demoMessage)
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
            }

            syncRow
                .padding(16)
                .cardStyle()

            Button("Sign Out", role: .destructive) {
                signOut()
            }
            .font(.spaceGrotesk(size: 16, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .disabled(isSigningOut || isDeletingAccount)

            Button("Delete Account", role: .destructive) {
                deletePassword = ""
                showingDeleteAccount = true
            }
            .font(.spaceGrotesk(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .disabled(!network.isConnected || isDeletingAccount)
            .accessibilityHint("Permanently deletes your account and all of your data")

            if !network.isConnected {
                Text("Connect to the internet to delete your account.")
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    // Uploads this account's latest changes before signing out, because signing
    // out clears the device (see RootView). Offline or a failed upload: warn first.
    private func signOut() {
        guard network.isConnected, let uid = authManager.uid else {
            showingUnsyncedSignOut = true
            return
        }
        isSigningOut = true
        Task {
            defer { isSigningOut = false }
            await syncService.push(uid: uid, modelContext: modelContext)
            if syncService.syncError != nil {
                showingUnsyncedSignOut = true
            } else {
                authManager.signOut()
            }
        }
    }

    // Order matters: check the password, delete the cloud data while still
    // signed in, clear this device, then delete the sign-in account last.
    private func deleteAccount() {
        guard let uid = authManager.uid else { return }
        let password = deletePassword
        deletePassword = ""
        isDeletingAccount = true

        Task {
            defer { isDeletingAccount = false }

            if let error = await authManager.reauthenticate(password: password) {
                deleteAccountError = error
                return
            }
            do {
                try await syncService.deleteAllData(uid: uid)
            } catch {
                deleteAccountError = "Couldn't delete your synced data. Check your connection and try again."
                return
            }
            try? syncService.clearLocalData(modelContext: modelContext)
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

            if let error = await authManager.deleteCurrentUser() {
                deleteAccountError = error
            }
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: avatarSize, height: avatarSize)
                .overlay(Text(initial).font(.spaceGrotesk(size: 20, weight: .bold)).foregroundStyle(.white))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(authManager.displayName ?? authManager.userEmail ?? "Account")
                    .font(.spaceGrotesk(size: 18, weight: .bold))
                Text(authManager.userEmail ?? "Signed in")
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
                connectionRow
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cardStyle()
    }

    private func settingsRow(_ title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.spaceGrotesk(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadDemoData() {
        let added = DemoDataService.load(into: modelContext)
        demoMessage = added == 0
            ? "Demo data is already loaded: \"iOS Development\" and \"Algorithms & Data Structures\" already have topics on this account."
            : "Added \(added) demo subject\(added == 1 ? "" : "s"). Check Home, the Weekly Digest and each subject's Season Recap."

        // Upload straight away, so the next launch's sync doesn't remove it.
        guard added > 0, network.isConnected, let uid = authManager.uid else { return }
        Task { await syncService.push(uid: uid, modelContext: modelContext) }
    }

    private var connectionRow: some View {
        Label(
            network.isConnected
                ? (syncService.lastSyncedAt != nil ? "Online · synced with Firestore" : "Online")
                : "Offline: changes sync when you reconnect",
            systemImage: "circle.fill"
        )
        .labelStyle(DotLabelStyle())
        .font(.spaceGrotesk(size: 12, weight: .semibold))
        .foregroundStyle(network.isConnected ? Color.green : Color.orange)
    }

    private var syncRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            AdaptiveStack(spacing: 8) {
                Text("iCloud / Firestore Sync")
                    .font(.spaceGrotesk(size: 15, weight: .semibold))
                Spacer(minLength: 0)
                if syncService.isSyncing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Sync Now") {
                        guard let uid = authManager.uid else { return }
                        Task { await syncService.syncNow(uid: uid, modelContext: modelContext) }
                    }
                    .font(.spaceGrotesk(size: 13, weight: .bold))
                    .buttonStyle(.bordered)
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
                Text("Notification Preferences").font(.spaceGrotesk(size: 18, weight: .bold, relativeTo: .headline))

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
            .padding(16)
            .cardStyle()

            VStack(alignment: .leading, spacing: 10) {
                Text("Upcoming Reminders").font(.spaceGrotesk(size: 18, weight: .bold, relativeTo: .headline))

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
            if let dueDate = reminder.dueDate {
                Text("Due \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.sgCaption)
                    .foregroundStyle(.red)
            }
            if let fireDate = reminder.fireDate {
                Text("Reminder \(fireDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
            }
            // Reminders scheduled before the due date was stored show the notification text.
            if reminder.dueDate == nil {
                Text(reminder.body)
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardStyle(cornerRadius: 12)
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

}

// A small coloured dot before the text ("● Online").
private struct DotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 6))
            configuration.title
        }
    }
}
