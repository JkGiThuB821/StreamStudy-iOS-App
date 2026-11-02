//
//  AboutView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 1/11/2026.
//

import SwiftUI

// About page: what the app is, who made it, and credits for every library,
// service, asset and resource used to build it. Opened from Account.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 72

    private struct Credit: Identifiable {
        let name: String
        let detail: String
        let url: String?
        var id: String { name }
    }

    private let libraries: [Credit] = [
        Credit(name: "Firebase iOS SDK (Auth, Firestore)", detail: "Google · Apache License 2.0. Sign-in and cloud sync.", url: "https://github.com/firebase/firebase-ios-sdk"),
    ]

    private let services: [Credit] = [
        Credit(name: "YouTube Data API v3", detail: "Google. Finds study videos for each topic.", url: "https://developers.google.com/youtube/v3"),
        Credit(name: "DEV Community (Forem) API", detail: "Finds articles and tutorials from dev.to.", url: "https://developers.forem.com/api"),
        Credit(name: "Google Gemini API", detail: "Builds lesson plans and tags resources.", url: "https://ai.google.dev/gemini-api/docs"),
    ]

    private let apple: [Credit] = [
        Credit(name: "SwiftUI, SwiftData, Swift Charts", detail: "Interface, on-device storage and progress charts.", url: nil),
        Credit(name: "UserNotifications, Network, Combine, UIKit", detail: "Reminders, connection status and system integration.", url: nil),
        Credit(name: "SF Symbols", detail: "Icons used throughout the app.", url: "https://developer.apple.com/sf-symbols/"),
    ]

    private let assets: [Credit] = [
        Credit(name: "Space Grotesk", detail: "Font by Florian Karsten · SIL Open Font License 1.1.", url: "https://fonts.google.com/specimen/Space+Grotesk"),
    ]

    private let learning: [Credit] = [
        Credit(name: "FIT3178 unit materials", detail: "Monash University lectures, labs and workshops.", url: nil),
        Credit(name: "Apple Developer Documentation", detail: "SwiftUI, SwiftData, Charts and Human Interface Guidelines.", url: "https://developer.apple.com/documentation/"),
        Credit(name: "Hacking with Swift", detail: "Paul Hudson. SwiftUI and SwiftData guides.", url: "https://www.hackingwithswift.com/"),
        Credit(name: "Firebase Documentation", detail: "Setup, Authentication and Firestore guides.", url: "https://firebase.google.com/docs/ios/setup"),
        Credit(name: "Claude (Anthropic)", detail: "Generative AI used to help with parts of the code and documentation, which I reviewed and understand.", url: nil),
    ]

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    section("About the App") {
                        Text("StreamStudy turns your university subjects into a streaming-style study planner. Each subject is a series and each topic an episode, with videos, articles and documentation found for you, AI-built lesson plans, deadline reminders, progress tracking, and the Season Pass revision features: Swipe-to-Revise, the Weekly Digest and the Season Recap.")
                            .font(.sgSubheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    section("Developer") {
                        VStack(spacing: 0) {
                            detailRow("Name", "Joy Jasmine Kaur")
                            Divider()
                            detailRow("Student ID", "33494266")
                            Divider()
                            detailRow("Unit", "FIT3178 iOS App Development")
                            Divider()
                            detailRow("University", "Monash University")
                        }
                        .cardStyle()
                    }

                    creditSection("Third-Party Libraries", libraries)
                    creditSection("Web Services & APIs", services)
                    creditSection("Apple Frameworks", apple)
                    creditSection("Fonts", assets)
                    creditSection("Resources Used to Build StreamStudy", learning)

                    Text("YouTube and dev.to content belongs to its creators. StreamStudy links to it and never downloads or stores it.")
                        .font(.sgCaption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 8) {
            // A simple "S" monogram in the app's own font (Space Grotesk, OFL).
            // Not an SF Symbol: Apple's licence doesn't allow symbols in logos.
            Text("S")
                .font(.spaceGrotesk(size: iconSize * 0.6, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(
                    LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: iconSize * 0.22)
                )
                .accessibilityHidden(true)
            Text("StreamStudy")
                .font(.spaceGrotesk(size: 26, weight: .bold, relativeTo: .title))
                .accessibilityAddTraits(.isHeader)
            Text(version)
                .font(.sgCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.spaceGrotesk(size: 12, weight: .bold))
                .tracking(1)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        AdaptiveStack(spacing: 8) {
            Text(label)
                .font(.spaceGrotesk(size: 15, weight: .semibold))
            Spacer(minLength: 0)
            Text(value)
                .font(.sgSubheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func creditSection(_ title: String, _ credits: [Credit]) -> some View {
        section(title) {
            VStack(spacing: 0) {
                ForEach(credits) { credit in
                    creditRow(credit)
                    if credit.id != credits.last?.id {
                        Divider()
                    }
                }
            }
            .cardStyle()
        }
    }

    @ViewBuilder
    private func creditRow(_ credit: Credit) -> some View {
        let text = VStack(alignment: .leading, spacing: 3) {
            Text(credit.name)
                .font(.spaceGrotesk(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text(credit.detail)
                .font(.sgCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if let urlString = credit.url, let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 10) {
                    text
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the website")
        } else {
            text
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
        }
    }
}
