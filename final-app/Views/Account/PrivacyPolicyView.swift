//
//  PrivacyPolicyView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 1/11/2026.
//

import SwiftUI

// App Store Guideline 5.1.1(i): the privacy policy must be easy to find inside
// the app. Shown from the sign-in screen and from Account.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, body: String)] = [
        ("What we collect",
         "Your email address and display name, used to sign you in. Your study data: the subjects, topics, resources, notes, deadlines, ratings and study history you add to the app."),
        ("Where it is stored",
         "Your study data is saved on your device and synced to your private account in Google Firebase (Firestore), so it's backed up and available on your other devices. Only you can access it."),
        ("Services we use",
         "To find and plan resources, StreamStudy sends the topic and subject names you enter to YouTube and dev.to (to search for videos and articles) and to Google Gemini (to tag resources and build lesson plans). Your name, email address and notes are never sent to these services."),
        ("Notifications",
         "Deadline reminders and the weekly episode drop are scheduled on your device. You can turn them off at any time in Account → Notifications or in the Settings app."),
        ("What we don't do",
         "StreamStudy has no ads, doesn't track you across other apps or websites, and never sells or shares your data for marketing."),
        ("Deleting your data",
         "You can delete your account at any time in Account → Delete Account. This permanently removes your account and all of your study data from your device and from Firebase."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Last updated 1 November 2026")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)

                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.spaceGrotesk(size: 17, weight: .bold, relativeTo: .headline))
                                .accessibilityAddTraits(.isHeader)
                            Text(section.body)
                                .font(.sgSubheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
