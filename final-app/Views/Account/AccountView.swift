//
//  AccountView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct AccountView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var syncService: FirestoreSyncService
    @Environment(\.modelContext) private var modelContext
    @State private var tab: Tab = .profile
    @State private var appearance: Appearance = .dark

    enum Tab { case profile, notifications }
    enum Appearance: String, CaseIterable { case dark = "Dark", system = "System" }

    var body: some View {
        ScrollView {
            Picker("", selection: $tab) {
                Text("Profile & Settings").tag(Tab.profile)
                Text("Notifications").tag(Tab.notifications)
            }
            .pickerStyle(.segmented)
            .padding()

            if tab == .profile {
                profileSection
            } else {
                notificationsSection
            }
        }
        .background(Color.black)
        .foregroundStyle(.white)
        .navigationTitle("Account")
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle().fill(.red).frame(width: 44, height: 44)
                    .overlay(Text(initial).font(.sgHeadline))
                VStack(alignment: .leading) {
                    Text(authManager.userEmail ?? "Account").font(.sgHeadline)
                    Text("Signed in").font(.sgCaption).foregroundStyle(.secondary)
                }
            }

            Button("Start Revision Mode") {}
                .buttonStyle(.borderedProminent)
                .tint(.red)

            Section {
                Picker("Theme", selection: $appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            } header: {
                Text("APPEARANCE").font(.sgCaption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                row(icon: "pencil", label: "Edit Profile")
                row(icon: "key.fill", label: "Change Password")
                row(icon: "link", label: "Linked Accounts")
                row(icon: "square.and.arrow.up", label: "Export Data")
            }

            syncRow

            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
            .padding(.top, 20)
        }
        .padding(.horizontal)
    }
    
    private var syncRow: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("iCloud / Firestore Sync")
                    Spacer()
                    if syncService.isSyncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Sync Now") {
                            guard let uid = authManager.uid else { return }
                            Task { await syncService.syncNow(uid: uid, modelContext: modelContext) }
                        }
                        .font(.caption.bold())
                    }
                }

                if let lastSyncedAt = syncService.lastSyncedAt {
                    Text("Last synced \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not synced yet this session")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let syncError = syncService.syncError {
                    Text(syncError)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Alerts").font(.sgHeadline)

            Text("Notification Preferences").font(.sgCaption).foregroundStyle(.secondary).padding(.top, 8)
            Toggle("Push Notifications", isOn: .constant(true)).tint(.red)
            Toggle("Deadline Reminders", isOn: .constant(true)).tint(.red)
        }
        .padding(.horizontal)
    }

    private var initial: String {
        String((authManager.userEmail ?? "A").prefix(1)).uppercased()
    }

    private func row(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 24)
            Text(label)
            Spacer()
            Image(systemName: "chevron.right").font(.sgCaption).foregroundStyle(.secondary)
        }
    }
}
