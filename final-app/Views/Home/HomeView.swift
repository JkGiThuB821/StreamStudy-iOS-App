//
//  HomeView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @Query(sort: \WeeklyDigest.weekStart, order: .reverse) private var digests: [WeeklyDigest]
    @State private var showingDigest = false
    @Query(sort: \Deadline.dueDate) private var deadlines: [Deadline]
    @Query private var subjects: [Subject]

    // Card sizes grow with Dynamic Type so larger text still fits.
    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .subheadline) private var cardHeight: CGFloat = 160
    @ScaledMetric(relativeTo: .subheadline) private var quickWinWidth: CGFloat = 140
    @ScaledMetric(relativeTo: .headline) private var avatarSize: CGFloat = 36

    private var allTopics: [Topic] { subjects.flatMap(\.topics) }

    private var ranked: [TopicRecommendation] {
        RecommendationEngine.rank(topics: allTopics)
    }

    private var continueLearning: [TopicRecommendation] {
        ranked.filter { $0.topic.progress > 0 }
    }

    private var recommendedForYou: [TopicRecommendation] {
        ranked.filter { $0.topic.progress == 0 }
    }

    private var quickWins: [LearningResource] {
        allTopics
            .flatMap(\.resources)
            .filter { !$0.isCompleted && $0.lengthCategory == .short }
            .sorted { $0.durationMinutes < $1.durationMinutes }
    }

    private var upcomingDeadlines: [Deadline] {
        deadlines.filter { !$0.isOverdue }
    }

    // The most recent weekly drop and how many of its topics were rated since it dropped.
    private var currentDigest: WeeklyDigest? { digests.first }

    private func ratedCount(in digest: WeeklyDigest) -> Int {
        WeeklyDigestService.topics(in: digest, from: allTopics).filter { topic in
            SignalPipeline.ratings(for: topic).contains { $0.date >= digest.weekStart }
        }
        .count
    }

    private var greeting: String {
        guard let name = authManager.displayName, !name.isEmpty else { return "Welcome back" }
        let firstName = name.split(separator: " ").first.map(String.init) ?? name
        return "Hi, \(firstName)"
    }

    private var initials: String {
        let source = authManager.displayName ?? authManager.userEmail ?? "S"
        let letters = source.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                    .padding(.horizontal)

                if let topPick = ranked.first {
                    nextWatchCard(for: topPick)
                        .padding(.horizontal)
                }

                if let digest = currentDigest {
                    WeeklyDigestCard(
                        digest: digest,
                        featuredCount: digest.topicIDs.count,
                        ratedCount: ratedCount(in: digest)
                    ) {
                        showingDigest = true
                    }
                    .padding(.horizontal)
                }

                if !continueLearning.isEmpty {
                    sectionRow(title: "Continue Learning", badge: "IN PROGRESS", recommendations: continueLearning)
                }

                if !upcomingDeadlines.isEmpty {
                    dueSoonRow
                }

                if !quickWins.isEmpty {
                    quickWinsRow
                }

                if !recommendedForYou.isEmpty {
                    sectionRow(title: "Recommended For You", badge: nil, recommendations: recommendedForYou)
                }

                if ranked.isEmpty && upcomingDeadlines.isEmpty {
                    ContentUnavailableView(
                        "Nothing yet",
                        systemImage: "sparkles.tv",
                        description: Text("Add a subject to start building your home feed.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.vertical)
        }
        .background(Color.appBackground)
        .tabBarClearance()   // keeps the last item clear of the tab bar
        .navigationTitle("Home")
        .toolbar(.hidden, for: .navigationBar)   // custom header instead, as in the mock-up
        .navigationDestination(for: Topic.self) { TopicDetailView(topic: $0) }
        .sheet(isPresented: $showingDigest) {
            if let digest = currentDigest {
                WeeklyDigestView(digest: digest)
            }
        }
        // The Monday "episodes have dropped" notification opens the digest.
        .onAppear { openDigestIfLinked() }
        .onChange(of: deepLinkRouter.destination) { _, _ in openDigestIfLinked() }
    }

    private func openDigestIfLinked() {
        guard deepLinkRouter.destination == .digest else { return }
        showingDigest = true
        deepLinkRouter.clear()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("StreamStudy")
                    .font(.spaceGrotesk(size: 24, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(.red)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(initials)
                    .font(.spaceGrotesk(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: avatarSize, height: avatarSize)
                    .background(Color.red, in: Circle())
                    .accessibilityLabel("Signed in as \(authManager.displayName ?? authManager.userEmail ?? "you")")
            }
            Text(greeting)
                .font(.sgHeadline)
            Text("Here's what to study next.")
                .font(.sgSubheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Hero

    private func nextWatchCard(for recommendation: TopicRecommendation) -> some View {
        let topic = recommendation.topic
        let resource = recommendation.nextResource
        let subjectColor = Color(hex: topic.subject?.colorHex ?? "#E50914")
        let deadline = topic.subject?.nextDeadline

        return VStack(alignment: .leading, spacing: 10) {
            BadgeLabel(text: "Your Next Watch")

            Text(topic.title)
                .font(.spaceGrotesk(size: 24, weight: .bold, relativeTo: .title2))
                .fixedSize(horizontal: false, vertical: true)

            Text(resource.map { "\($0.title) · \($0.durationMinutes) min" } ?? (topic.subject?.name ?? ""))
                .font(.sgSubheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                ProgressView(value: topic.progress)
                    .tint(.red)
                Text("\(Int(topic.progress * 100))%")
                    .font(.spaceGrotesk(size: 12, weight: .bold))
                if let deadline {
                    Text("· \(deadline.shortDueLabel)")
                        .font(.spaceGrotesk(size: 12, weight: .bold))
                        .foregroundStyle(.red)
                }
            }

            AdaptiveStack(spacing: 10) {
                Button {
                    if let urlString = resource?.urlString, let url = URL(string: urlString) {
                        openURL(url)
                    }
                } label: {
                    Label("Continue", systemImage: "play.fill")
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(Color.appBackground)
                }
                .disabled(resource == nil)
                .accessibilityHint("Opens this resource")

                NavigationLink(value: topic) {
                    Text("More Info")
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.4)))
                        .foregroundStyle(Color.primary)
                }
                .accessibilityHint("Shows this episode's details")
            }
            .font(.spaceGrotesk(size: 15, weight: .bold))
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [subjectColor.opacity(0.45), Color.cardFill], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardStroke))
    }

    // MARK: - Rows

    private func rowTitle(_ title: String, badge: String?) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.spaceGrotesk(size: 18, weight: .bold, relativeTo: .headline))
            if let badge {
                BadgeLabel(text: badge)
            }
        }
        .padding(.horizontal)
    }

    private func sectionRow(title: String, badge: String?, recommendations: [TopicRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            rowTitle(title, badge: badge)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recommendations) { recommendation in
                        topicCard(recommendation.topic)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var dueSoonRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            rowTitle("Due Soon", badge: nil)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(upcomingDeadlines.prefix(5)) { deadline in
                        let subject = deadline.subject
                        VStack(alignment: .leading, spacing: 8) {
                            BadgeLabel(text: "Deadline", color: deadline.priority.color == .yellow ? .orange : deadline.priority.color)
                            Spacer(minLength: 0)
                            Image(systemName: subject?.iconName ?? "calendar")
                                .font(.title2)
                                .foregroundStyle(Color(hex: subject?.colorHex ?? "#E50914"))
                            if let subject {
                                ProgressView(value: subject.progress)
                                    .tint(Color(hex: subject.colorHex))
                                Text("\(Int(subject.progress * 100))% complete")
                                    .font(.sgCaption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(deadline.title)
                                .font(.spaceGrotesk(size: 14, weight: .bold))
                                .lineLimit(2)
                            Text(daysLabel(deadline))
                                .font(.sgCaption)
                                .foregroundStyle(.red)
                        }
                        .padding(12)
                        .frame(width: cardWidth, alignment: .leading)
                        .frame(minHeight: cardHeight, alignment: .topLeading)
                        .background(Color(hex: subject?.colorHex ?? "#333333").opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardStroke))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var quickWinsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            rowTitle("Quick Wins", badge: nil)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickWins.prefix(8)) { resource in
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: resource.type.sfSymbol).foregroundStyle(.red)
                            Text(resource.title)
                                .font(.spaceGrotesk(size: 14, weight: .semibold))
                                .lineLimit(2)
                            Text("\(resource.durationMinutes) min")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(width: quickWinWidth, alignment: .leading)
                        .frame(minHeight: 100, alignment: .topLeading)
                        .cardStyle(cornerRadius: 12)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func topicCard(_ topic: Topic) -> some View {
        let color = Color(hex: topic.subject?.colorHex ?? "#333333")

        return NavigationLink(value: topic) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: topic.subject?.iconName ?? "book.closed.fill")
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer(minLength: 0)
                ProgressView(value: topic.progress)
                    .tint(color)
                Text("\(Int(topic.progress * 100))% complete")
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
                Text(topic.title)
                    .font(.spaceGrotesk(size: 14, weight: .bold))
                    .lineLimit(2)
                Text(topic.subject?.name ?? "")
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: cardWidth, alignment: .leading)
            .frame(minHeight: cardHeight, alignment: .topLeading)
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardStroke))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func daysLabel(_ deadline: Deadline) -> String {
        switch deadline.daysRemaining {
        case ...0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "In \(deadline.daysRemaining) days"
        }
    }
}
