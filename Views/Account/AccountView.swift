//
//  AccountView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//


import SwiftUI

struct AccountView: View {
    @Binding var isSignedIn: Bool
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
                    .overlay(Text("A").font(.headline))
                VStack(alignment: .leading) {
                    Text("Account").font(.headline)
                    Text("Signed in").font(.caption).foregroundStyle(.secondary)
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
                Text("APPEARANCE").font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                row(icon: "pencil", label: "Edit Profile")
                row(icon: "key.fill", label: "Change Password")
                row(icon: "link", label: "Linked Accounts")
                row(icon: "square.and.arrow.up", label: "Export Data")
            }

            HStack {
                Text("iCloud / Firestore Sync")
                Spacer()
                Button("Sync Now") {}
                    .font(.caption.bold())
            }

            Button("Sign Out", role: .destructive) {
                isSignedIn = false
            }
            .padding(.top, 20)
        }
        .padding(.horizontal)
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Alerts").font(.headline)

            Text("Notification Preferences").font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            Toggle("Push Notifications", isOn: .constant(true)).tint(.red)
            Toggle("Deadline Reminders", isOn: .constant(true)).tint(.red)
        }
        .padding(.horizontal)
    }

    private func row(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 24)
            Text(label)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
    }
}
