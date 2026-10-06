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
    @Query(sort: \Deadline.dueDate) private var deadlines: [Deadline]
    @Query private var subjects: [Subject]

    // Card sizes grow with Dynamic Type so larger text still fits.
    @ScaledMetric(relativeTo: .subheadline) private var topicCardWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .subheadline) private var topicCardHeight: CGFloat = 110
    @ScaledMetric(relativeTo: .subheadline) private var deadlineCardWidth: CGFloat = 140
    @ScaledMetric(relativeTo: .subheadline) private var quickWinWidth: CGFloat = 130
    @ScaledMetric(relativeTo: .subheadline) private var quickWinHeight: CGFloat = 100

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let topPick = ranked.first {
                    nextWatchCard(for: topPick)
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
        .navigationTitle("Home")
        .navigationDestination(for: Topic.self) { TopicDetailView(topic: $0) }
    }

    private func nextWatchCard(for recommendation: TopicRecommendation) -> some View {
        let topic = recommendation.topic
        let resource = recommendation.nextResource

        return VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NEXT WATCH")
                .font(.spaceGrotesk(size: 16, weight: .bold))
                .foregroundStyle(.red)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 6) {
                Text(topic.subject?.name ?? "")
                    .font(.spaceGrotesk(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(resource?.title ?? topic.title)
                    .font(.spaceGrotesk(size: 20, weight: .bold))
                if let resource {
                    Text("\(topic.title) Â· \(resource.durationMinutes) min")
                        .font(.sgSubheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(topic.title)
                        .font(.sgSubheadline)
                        .foregroundStyle(.secondary)
                }

                AdaptiveStack(spacing: 8) {
                    Button {
                        if let urlString = resource?.urlString, let url = URL(string: urlString) {
                            openURL(url)
                        }
                    } label: {
                        Label("Continue", systemImage: "play.fill")
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.primary)
                            .foregroundStyle(Color.appBackground)
                            .clipShape(Capsule())
                    }
                    .disabled(resource == nil)

                    NavigationLink(value: topic) {
                        Label("More Info", systemImage: "info.circle")
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.primary.opacity(0.12))
                            .foregroundStyle(Color.primary)
                            .clipShape(Capsule())
                    }
                }
                .font(.spaceGrotesk(size: 15, weight: .bold))
                .padding(.top, 4)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.red.opacity(0.4), Color.appBackground], startPoint: .top, endPoint: .bottom)
            )
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardStroke))
            .padding(.horizontal)
        }
    }

    private func sectionRow(title: String, badge: String?, recommendations: [TopicRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.sgHeadline)
                if let badge {
                    Text(badge)
                        .font(.spaceGrotesk(size: 11, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)

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
        VStack(alignment: .leading, spacing: 10) {
            Text("Due Soon").font(.sgHeadline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(upcomingDeadlines.prefix(5)) { deadline in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DEADLINE")
                                .font(.spaceGrotesk(size: 11, weight: .bold))
                                .foregroundStyle(.red)
                            Text(deadline.subject?.name ?? deadline.title)
                                .font(.sgSubheadline)
                                .lineLimit(1)
                            Text(deadline.daysRemaining == 1 ? "1 day" : "\(deadline.daysRemaining) days")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(width: deadlineCardWidth, alignment: .leading)
                        .background(Color.cardFill)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var quickWinsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Wins").font(.sgHeadline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickWins.prefix(8)) { resource in
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: resource.type.sfSymbol).foregroundStyle(.red)
                            Text(resource.title)
                                .font(.sgSubheadline)
                                .lineLimit(2)
                            Text("\(resource.durationMinutes) min")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(width: quickWinWidth, alignment: .leading)
                        .frame(minHeight: quickWinHeight, alignment: .topLeading)
                        .background(Color.cardFill)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func topicCard(_ topic: Topic) -> some View {
        NavigationLink(value: topic) {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.subject?.name ?? "")
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
                Text(topic.title)
                    .font(.sgSubheadline)
                    .lineLimit(2)
                ProgressView(value: topic.progress)
                    .tint(.red)
            }
            .padding(10)
            .frame(width: topicCardWidth, alignment: .leading)
            .frame(minHeight: topicCardHeight, alignment: .bottomLeading)
            .background(Color(hex: topic.subject?.colorHex ?? "#333333").opacity(0.5))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
